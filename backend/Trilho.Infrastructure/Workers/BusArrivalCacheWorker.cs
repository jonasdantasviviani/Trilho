using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using Trilho.Infrastructure.DataSources;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

/// <summary>
/// Periodically fetches real-time bus arrival predictions from OlhoVivo and caches
/// them in Redis per metro station so that <c>GET /api/stations/{id}/arrivals</c> can
/// serve a fast, non-blocking response.
///
/// Design
/// ──────
/// • Every <see cref="PollInterval"/> (60 s) the worker iterates over all stations that
///   have GPS coordinates.
/// • For each station it looks up (or discovers) nearby SPTrans bus stops using
///   <c>OlhoVivo /Parada/Buscar</c>, filtering to stops within <see cref="StopRadiusMetres"/>.
///   The discovered stop codes are cached in Redis (<c>bus:stops:{stationId}</c>) for
///   <see cref="StopCacheTtl"/> (1 h) so that the /Parada/Buscar call only happens once
///   per hour, not every cycle.
/// • For each nearby stop it calls <c>OlhoVivo /Previsao/Parada</c> and aggregates the
///   approaching vehicles into a list of <see cref="BusDirectionCache"/> objects, serialised
///   to JSON and stored as <c>bus:arrivals:{stationId}</c> with <see cref="ArrivalCacheTtl"/>
///   (90 s).
/// • <c>GET /api/stations/{id}/arrivals</c> reads from this cache; if absent it falls back to
///   headway-based estimates.
/// </summary>
public class BusArrivalCacheWorker(
    IServiceScopeFactory scopeFactory,
    IConnectionMultiplexer redis,
    ILogger<BusArrivalCacheWorker> logger) : BackgroundService
{
    // How often to refresh arrival predictions.
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(60);

    // Nearby stops are re-discovered at most once per hour (they don't change often).
    private static readonly TimeSpan StopCacheTtl = TimeSpan.FromHours(1);

    // Arrival predictions are kept for 90 s (slightly longer than one poll cycle so
    // that the API always has data even when OlhoVivo is briefly slow).
    private static readonly TimeSpan ArrivalCacheTtl = TimeSpan.FromSeconds(90);

    // Maximum walking distance from a metro station entrance to a bus stop.
    private const double StopRadiusMetres = 350;

    // Throttle between /Parada/Buscar discovery calls to avoid hammering OlhoVivo.
    private static readonly TimeSpan DiscoveryThrottle = TimeSpan.FromMilliseconds(250);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("BusArrivalCacheWorker started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try   { await RunAsync(stoppingToken); }
            catch (OperationCanceledException) { break; }
            catch (Exception ex) { logger.LogError(ex, "BusArrivalCacheWorker error."); }

            await Task.Delay(PollInterval, stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        using var scope  = scopeFactory.CreateScope();
        var db           = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var olhoVivo     = scope.ServiceProvider.GetRequiredService<OlhoVivoClient>();
        var redisDb      = redis.GetDatabase();

        var stations = await db.Stations
            .Where(s => s.Location != null)
            .Include(s => s.Line)
            .AsNoTracking()
            .ToListAsync(ct);

        int updated = 0;

        foreach (var station in stations)
        {
            ct.ThrowIfCancellationRequested();

            // ── 1. Resolve nearby bus stop codes (with Redis cache) ────────────
            var stopCodes = await GetCachedStopCodesAsync(redisDb, station.Id)
                         ?? await DiscoverStopCodesAsync(olhoVivo, redisDb, station, ct);

            if (stopCodes.Count == 0) continue;

            // ── 2. Fetch arrival predictions for each stop ────────────────────
            var directions = new List<BusDirectionCache>();

            foreach (var stopCode in stopCodes)
            {
                var arrival = await olhoVivo.GetArrivalsByStopAsync(stopCode, ct);
                if (arrival?.Stop?.Lines is null) continue;

                foreach (var line in arrival.Stop.Lines)
                {
                    if (line.Vehicles is null || line.Vehicles.Count == 0) continue;

                    var times = line.Vehicles
                        .Select(v => ToMinutesFromNow(v.ArrivalTime))
                        .Where(m => m is >= 0 and <= 90)   // ignore stale or too-far-away
                        .OrderBy(m => m)
                        .Take(3)
                        .Select(m => new BusArrivalCache((int)m, IsEstimated: false))
                        .ToList();

                    if (times.Count == 0) continue;

                    // Deduplicate by line + terminus (keep the one with more arrivals)
                    var key  = $"{line.LineCode}|{line.TerminusTo}";
                    var prev = directions.FirstOrDefault(d => d.Key == key);
                    if (prev is not null)
                    {
                        if (prev.Arrivals.Count >= times.Count) continue;
                        directions.Remove(prev);
                    }

                    directions.Add(new BusDirectionCache(
                        Key:      key,
                        Terminus: line.TerminusTo,
                        LineCode: line.LineCode,
                        Arrivals: times));
                }
            }

            if (directions.Count == 0) continue;

            // ── 3. Store in Redis ─────────────────────────────────────────────
            var json = JsonSerializer.Serialize(directions);
            await redisDb.StringSetAsync(
                $"bus:arrivals:{station.Id}", json, ArrivalCacheTtl);

            updated++;
        }

        logger.LogDebug("BusArrivalCacheWorker: refreshed arrivals for {Updated}/{Total} stations.",
            updated, stations.Count);
    }

    // ── Stop code discovery ───────────────────────────────────────────────────

    private static async Task<List<int>?> GetCachedStopCodesAsync(IDatabase db, int stationId)
    {
        var cached = await db.StringGetAsync($"bus:stops:{stationId}");
        if (!cached.HasValue) return null;
        return JsonSerializer.Deserialize<List<int>>((string)cached!) ?? null;
    }

    private async Task<List<int>> DiscoverStopCodesAsync(
        OlhoVivoClient olhoVivo,
        IDatabase db,
        Trilho.Domain.Entities.Station station,
        CancellationToken ct)
    {
        double stLat = station.Location.Y;
        double stLng = station.Location.X;

        // Use first word of station name for a broader search (e.g. "Tucuruvi" not "Tucuruvi Norte")
        var firstWord = station.Name.Split(' ')[0];
        var stops     = await olhoVivo.SearchStopsByNameAsync(firstWord, ct);

        var nearby = stops
            .Where(s => HaversineMetres(stLat, stLng, s.Lat, s.Lng) <= StopRadiusMetres)
            .Select(s => s.StopCode)
            .Distinct()
            .ToList();

        logger.LogDebug("BusArrivalCacheWorker: station '{Name}' → {Count} stops within {R}m (search: '{Term}').",
            station.Name, nearby.Count, StopRadiusMetres, firstWord);

        // Cache even an empty list so we don't re-discover on every cycle
        await db.StringSetAsync(
            $"bus:stops:{station.Id}",
            JsonSerializer.Serialize(nearby),
            StopCacheTtl);

        await Task.Delay(DiscoveryThrottle, ct);   // gentle throttle
        return nearby;
    }

    // ── Arrival time parsing ──────────────────────────────────────────────────

    /// <summary>
    /// Converts an OlhoVivo wall-clock time string ("HH:MM") to minutes relative to now (BRT).
    /// Returns a negative value if the time is in the past.
    /// Handles midnight roll-over (e.g., 23:58 → 00:02 is 4 min ahead, not -23 h 56 min).
    /// </summary>
    private static double ToMinutesFromNow(string arrivalTime)
    {
        var parts = arrivalTime.Split(':');
        if (parts.Length < 2) return -1;
        if (!int.TryParse(parts[0], out int h) || !int.TryParse(parts[1], out int m))
            return -1;

        var nowBrt = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(-3));
        var nowMinutes = nowBrt.Hour * 60 + nowBrt.Minute;
        var arrMinutes = h * 60 + m;

        double diff = arrMinutes - nowMinutes;

        // Wrap midnight: if the difference is more than ±12 h adjust by ±24 h
        if (diff < -720) diff += 1440;
        if (diff >  720) diff -= 1440;

        return diff;
    }

    private static double HaversineMetres(double lat1, double lon1, double lat2, double lon2)
    {
        const double R = 6_371_000;
        double φ1 = lat1 * Math.PI / 180;
        double φ2 = lat2 * Math.PI / 180;
        double Δφ = (lat2 - lat1) * Math.PI / 180;
        double Δλ = (lon2 - lon1) * Math.PI / 180;
        double a = Math.Sin(Δφ / 2) * Math.Sin(Δφ / 2)
                 + Math.Cos(φ1) * Math.Cos(φ2)
                 * Math.Sin(Δλ / 2) * Math.Sin(Δλ / 2);
        return 2 * R * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }
}

// ── Cache DTOs (stored in Redis, not exposed to API directly) ─────────────────

public record BusArrivalCache(int EstimatedMinutes, bool IsEstimated);

public record BusDirectionCache(
    string Key,          // internal dedup key: "{lineCode}|{terminus}"
    string Terminus,
    string LineCode,
    List<BusArrivalCache> Arrivals);

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.Collections.Concurrent;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;

namespace Trilho.Infrastructure.Workers;

/// <summary>
/// Polls Google Places API for real-time crowd popularity data for all transit stations.
///
/// Lifecycle:
///   1. On first tick, resolves a Google Place ID for each station (text search + GPS bias).
///      Place IDs are cached in memory — a restart rediscovers them (cheap, ~100 calls once).
///   2. Every <see cref="PollInterval"/>, fetches <c>currentPopularityPercent</c> for each
///      station and writes a <see cref="CrowdSnapshot"/> with <c>Source = Google</c>.
///   3. Silently skips if <c>Google:PlacesApiKey</c> is not configured.
/// </summary>
public class GoogleCrowdWorker(
    IServiceScopeFactory scopeFactory,
    IGooglePlacesService places,
    DataSourceHealthRegistry health,
    ILogger<GoogleCrowdWorker> logger) : BackgroundService
{
    private const string SourceName = "Google";

    /// How often to refresh crowd data from Google (30 min balances freshness vs API cost).
    private static readonly TimeSpan PollInterval = TimeSpan.FromMinutes(30);

    /// Delay between Place ID discovery requests to avoid quota bursts.
    private static readonly TimeSpan DiscoveryThrottle = TimeSpan.FromMilliseconds(200);

    /// StationId → Google Place ID, discovered once per run.
    private readonly ConcurrentDictionary<int, string> _placeIds = new();

    // ── BackgroundService ─────────────────────────────────────────────────────

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!places.IsEnabled)
        {
            logger.LogInformation("GoogleCrowdWorker disabled — Google:PlacesApiKey not set.");
            return;
        }

        logger.LogInformation("GoogleCrowdWorker started (poll interval: {Interval})", PollInterval);

        // Stagger startup to let other workers settle first
        await Task.Delay(TimeSpan.FromSeconds(45), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await DiscoverMissingPlaceIdsAsync(stoppingToken);
                await UpdateCrowdSnapshotsAsync(stoppingToken);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                health.ReportFailure(SourceName, ex.Message);
                logger.LogError(ex, "GoogleCrowdWorker encountered an error");
            }

            await Task.Delay(PollInterval, stoppingToken);
        }
    }

    // ── Place ID discovery ────────────────────────────────────────────────────

    private async Task DiscoverMissingPlaceIdsAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var stations = await db.Stations
            .Where(s => s.Location != null)
            .ToListAsync(ct);

        var missing = stations.Where(s => !_placeIds.ContainsKey(s.Id)).ToList();
        if (missing.Count == 0) return;

        logger.LogInformation("Discovering Google Place IDs for {Count} station(s)…", missing.Count);
        int found = 0;

        foreach (var station in missing)
        {
            ct.ThrowIfCancellationRequested();

            // Location is GEOGRAPHY(POINT): X = longitude, Y = latitude
            double lat = station.Location.Y;
            double lng = station.Location.X;

            var placeId = await places.SearchPlaceIdAsync(station.Name, lat, lng, ct);

            if (placeId is not null)
            {
                _placeIds[station.Id] = placeId;
                found++;
            }
            else
            {
                logger.LogDebug("No Place ID found for station '{Name}' ({Id})", station.Name, station.Id);
            }

            // Throttle to ~5 req/s — well within Google's quota
            await Task.Delay(DiscoveryThrottle, ct);
        }

        logger.LogInformation(
            "Place ID discovery complete: {Found}/{Total} resolved.",
            found, missing.Count);
    }

    // ── Popularity polling ────────────────────────────────────────────────────

    private async Task UpdateCrowdSnapshotsAsync(CancellationToken ct)
    {
        if (_placeIds.IsEmpty) return;

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var stations = await db.Stations
            .Where(s => _placeIds.Keys.Contains(s.Id))
            .ToListAsync(ct);

        var snapshots = new List<CrowdSnapshot>();
        int polled = 0;

        foreach (var station in stations)
        {
            if (!_placeIds.TryGetValue(station.Id, out var placeId)) continue;

            ct.ThrowIfCancellationRequested();

            var popularity = await places.GetCurrentPopularityAsync(placeId, ct);

            if (popularity is null)
            {
                logger.LogDebug("No popularity data for station '{Name}' (placeId={PlaceId})", station.Name, placeId);
                continue;
            }

            // currentPopularityPercent: 0–100, where 100 = busiest this place ever gets.
            // Map directly to InferredDensity (0.0–1.0).
            var density = Math.Clamp(popularity.Value / 100m, 0m, 1m);
            var level   = CrowdInferenceEngine.Infer(
                (int)(density * station.Capacity),
                station.Capacity,
                OperationalStatus.Normal).Level;

            snapshots.Add(new CrowdSnapshot
            {
                StationId       = station.Id,
                UserCount       = 0,
                InferredDensity = density,
                DensityLevel    = level,
                Source          = CrowdSource.Google,
                CapturedAt      = DateTimeOffset.UtcNow
            });

            polled++;
            await Task.Delay(DiscoveryThrottle, ct); // light throttle between requests
        }

        if (snapshots.Count == 0) return;

        db.CrowdSnapshots.AddRange(snapshots);
        await db.SaveChangesAsync(ct);

        health.ReportSuccess(SourceName);
        logger.LogInformation(
            "Google crowd update: {Polled} stations polled, {Written} snapshots written.",
            polled, snapshots.Count);
    }
}

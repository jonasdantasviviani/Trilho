using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

/// <summary>
/// Rebuilds <see cref="HistoricalDemand"/> from real GTFS <c>stop_times</c> frequencies
/// whenever new GTFS data is available.
///
/// Logic:
///   For each of our <see cref="Station"/> records, find the nearest <see cref="GtfsStop"/>
///   within 300 m (GPS proximity).  Count how many scheduled trips depart from that stop in
///   each (DayType, Hour) bucket, then scale the trip count to an average passenger estimate
///   using the station's capacity and the line's peak frequency.
///
/// Runs once at startup (after a 3-minute delay so GtfsImportWorker runs first),
/// then weekly in sync with the GTFS refresh cycle.
/// Falls back gracefully when no GTFS data exists yet.
/// </summary>
public class GtfsHistoricalDemandWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<GtfsHistoricalDemandWorker> logger) : BackgroundService
{
    private static readonly TimeSpan StartupDelay  = TimeSpan.FromMinutes(3);
    private static readonly TimeSpan RefreshPeriod = TimeSpan.FromDays(7);

    // Maximum search radius for GTFS stop → Station matching (metres)
    private const double MatchRadiusMetres = 300;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("GtfsHistoricalDemandWorker started");
        await Task.Delay(StartupDelay, stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try   { await RebuildAsync(stoppingToken); }
            catch (OperationCanceledException) { break; }
            catch (Exception ex) { logger.LogError(ex, "GtfsHistoricalDemandWorker error"); }

            await Task.Delay(RefreshPeriod, stoppingToken);
        }
    }

    private async Task RebuildAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // Nothing to do if GTFS hasn't been imported yet
        if (!await db.GtfsStopTimes.AnyAsync(ct))
        {
            logger.LogDebug("GtfsHistoricalDemandWorker: no GTFS stop_times yet, skipping rebuild.");
            return;
        }

        logger.LogInformation("GtfsHistoricalDemandWorker: rebuilding historical demand from GTFS…");

        var stations  = await db.Stations
            .Where(s => s.Location != null)
            .ToListAsync(ct);

        var gtfsStops = await db.GtfsStops
            .Where(s => s.Location != null)
            .ToListAsync(ct);

        // Build calendar lookup: serviceId → (weekday flags)
        var calendars = await db.GtfsCalendars.ToListAsync(ct);
        var calByServiceId = calendars.ToDictionary(c => c.ServiceId);

        // Build trip → routeId → serviceId lookup
        var trips = await db.GtfsTrips.ToListAsync(ct);
        var tripInfo = trips.ToDictionary(t => t.TripId,
            t => (RouteId: t.RouteId, ServiceId: t.ServiceId));

        int updated = 0;

        foreach (var station in stations)
        {
            // Find the nearest GTFS stop within the match radius
            var nearestStop = FindNearestStop(station, gtfsStops, MatchRadiusMetres);
            if (nearestStop is null)
            {
                logger.LogDebug("No GTFS stop found within {R}m of station '{Name}'", MatchRadiusMetres, station.Name);
                continue;
            }

            // Load all departures from this stop
            var stopTimes = await db.GtfsStopTimes
                .Where(st => st.StopId == nearestStop.StopId)
                .ToListAsync(ct);

            if (stopTimes.Count == 0) continue;

            // Count departures per (DayType, Hour)
            var counts = CountDeparturesPerHour(stopTimes, tripInfo, calByServiceId);
            if (counts.Count == 0) continue;

            // Determine the peak count to use for normalisation
            int peakCount = counts.Values.Max();
            if (peakCount == 0) continue;

            // Upsert HistoricalDemand for all (DayType, Hour) combinations
            foreach (DayType dayType in Enum.GetValues<DayType>())
            {
                for (short hour = 0; hour <= 23; hour++)
                {
                    int trips_count = counts.GetValueOrDefault((dayType, hour), 0);

                    // Scale: peak trip count → 90% of station capacity (trains are rarely 100% full
                    // at peak *from a stop perspective*, vs a full train end-to-end).
                    double loadFactor = peakCount > 0 ? (double)trips_count / peakCount : 0;
                    int avgPassengers = (int)(station.Capacity * loadFactor * 0.90);
                    avgPassengers = Math.Clamp(avgPassengers, 0, station.Capacity);

                    var existing = await db.HistoricalDemands
                        .FirstOrDefaultAsync(h => h.StationId == station.Id
                            && h.DayType == dayType && h.Hour == hour, ct);

                    if (existing is not null)
                    {
                        existing.AvgPassengers = avgPassengers;
                    }
                    else
                    {
                        db.HistoricalDemands.Add(new HistoricalDemand
                        {
                            StationId     = station.Id,
                            DayType       = dayType,
                            Hour          = hour,
                            AvgPassengers = avgPassengers
                        });
                    }
                }
            }

            updated++;
        }

        await db.SaveChangesAsync(ct);
        logger.LogInformation(
            "GtfsHistoricalDemandWorker: updated historical demand for {Count}/{Total} stations.",
            updated, stations.Count);
    }

    // ── Nearest GTFS stop matching ─────────────────────────────────────────────

    private static GtfsStop? FindNearestStop(
        Station station,
        IEnumerable<GtfsStop> stops,
        double maxRadiusMetres)
    {
        // station.Location: GEOGRAPHY(POINT,4326) — X=lng, Y=lat
        double stLat = station.Location.Y;
        double stLng = station.Location.X;

        GtfsStop? best = null;
        double bestDist = double.MaxValue;

        foreach (var stop in stops)
        {
            double dist = HaversineMetres(stLat, stLng, stop.StopLat, stop.StopLon);
            if (dist < bestDist)
            {
                bestDist = dist;
                best     = stop;
            }
        }

        return bestDist <= maxRadiusMetres ? best : null;
    }

    private static double HaversineMetres(double lat1, double lon1, double lat2, double lon2)
    {
        const double R = 6_371_000; // Earth radius in metres
        double φ1 = lat1 * Math.PI / 180;
        double φ2 = lat2 * Math.PI / 180;
        double Δφ = (lat2 - lat1) * Math.PI / 180;
        double Δλ = (lon2 - lon1) * Math.PI / 180;

        double a = Math.Sin(Δφ / 2) * Math.Sin(Δφ / 2)
                 + Math.Cos(φ1) * Math.Cos(φ2)
                 * Math.Sin(Δλ / 2) * Math.Sin(Δλ / 2);

        return 2 * R * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    // ── Trip frequency counting ────────────────────────────────────────────────

    /// <summary>
    /// Counts how many trip departures occur in each (DayType, Hour) bucket for a given stop.
    /// </summary>
    private static Dictionary<(DayType, short), int> CountDeparturesPerHour(
        IEnumerable<GtfsStopTime> stopTimes,
        IReadOnlyDictionary<string, (string RouteId, string ServiceId)> tripInfo,
        IReadOnlyDictionary<string, GtfsCalendar> calByServiceId)
    {
        var counts = new Dictionary<(DayType, short), int>();

        foreach (var st in stopTimes)
        {
            var timeStr = st.DepartureTime ?? st.ArrivalTime;
            if (timeStr is null) continue;

            var hour = ParseHour(timeStr);
            if (hour is null) continue;

            if (!tripInfo.TryGetValue(st.TripId, out var info)) continue;
            if (!calByServiceId.TryGetValue(info.ServiceId, out var cal)) continue;

            short h = (short)(hour.Value % 24); // clamp overnight trips to hour 0–23

            // Weekday
            if (cal.Monday || cal.Tuesday || cal.Wednesday || cal.Thursday || cal.Friday)
                Increment(counts, (DayType.Weekday, h));

            // Saturday
            if (cal.Saturday)
                Increment(counts, (DayType.Saturday, h));

            // Sunday
            if (cal.Sunday)
                Increment(counts, (DayType.Sunday, h));
        }

        return counts;
    }

    private static short? ParseHour(string gtfsTime)
    {
        var parts = gtfsTime.Split(':');
        if (parts.Length < 1) return null;
        return short.TryParse(parts[0], out var h) ? h : null;
    }

    private static void Increment<TKey>(Dictionary<TKey, int> dict, TKey key) where TKey : notnull
    {
        dict.TryGetValue(key, out int current);
        dict[key] = current + 1;
    }
}

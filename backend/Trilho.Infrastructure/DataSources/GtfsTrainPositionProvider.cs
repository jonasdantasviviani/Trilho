using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Text.RegularExpressions;
using Trilho.Domain.Entities;
using Trilho.Domain.Interfaces;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.DataSources;

/// <summary>
/// Computes real-time train positions by interpolating between scheduled GTFS stops.
/// Matches GTFS routes against the internal <see cref="Line"/> table by route_short_name.
/// Returns an empty list when no train GTFS data is present (e.g. before the first import).
/// </summary>
public class GtfsTrainPositionProvider(
    AppDbContext db,
    ILogger<GtfsTrainPositionProvider> logger) : ITrainPositionProvider
{
    // São Paulo: UTC-3 (no DST since 2019)
    private static readonly TimeZoneInfo BrtZone = TimeZoneInfo.FindSystemTimeZoneById(
        OperatingSystem.IsWindows() ? "E. South America Standard Time" : "America/Sao_Paulo");

    private static readonly Regex LeadingDigitsRe =
        new(@"^\d+", RegexOptions.Compiled);

    // ── Public interface ──────────────────────────────────────────────────────

    public async Task<IEnumerable<TrainPosition>> GetPositionsAsync(CancellationToken ct = default)
    {
        var now        = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, BrtZone);
        var nowSeconds = (int)now.TimeOfDay.TotalSeconds;
        var today      = DateOnly.FromDateTime(now);

        // 1. Active service IDs for today
        var activeServiceIds = await GetActiveServiceIdsAsync(today, now.DayOfWeek, ct);
        if (activeServiceIds.Count == 0)
        {
            logger.LogDebug("GTFS: No active calendar services for {Date} ({Day})", today, now.DayOfWeek);
            return [];
        }

        // 2. Map our internal Lines to GTFS routes by short name
        var lines = await db.Lines.ToListAsync(ct);
        if (lines.Count == 0) return [];

        var gtfsRoutes   = await db.GtfsRoutes.ToListAsync(ct);
        var matchedRoutes = new Dictionary<string, (int LineId, string LineCode)>(); // gtfsRouteId → line

        foreach (var route in gtfsRoutes)
        {
            if (TryMatchLine(route.RouteShortName, lines, out var line))
                matchedRoutes[route.RouteId] = (line.Id, line.Code);
        }

        if (matchedRoutes.Count == 0)
        {
            // The imported GTFS is SPTrans bus data (routes like "1012-10"), which does
            // not match Metro/CPTM lines ("1-AZUL").  Train positions will be empty until
            // Metro/CPTM GTFS is imported.  The UI falls back to crowd-based estimation.
            logger.LogInformation(
                "GTFS: No routes matched our Lines table — imported GTFS appears to be bus-only " +
                "({RouteCount} routes like '{Sample}'). Import Metro/CPTM GTFS to enable train positions.",
                gtfsRoutes.Count,
                gtfsRoutes.FirstOrDefault()?.RouteShortName ?? "?");
            return [];
        }

        // 3. Active trips for matched routes today
        var routeIds   = matchedRoutes.Keys.ToHashSet();
        var activeTrips = await db.GtfsTrips
            .Where(t => routeIds.Contains(t.RouteId) && activeServiceIds.Contains(t.ServiceId))
            .ToListAsync(ct);

        if (activeTrips.Count == 0)
        {
            logger.LogDebug("GTFS: No active trips for train routes at {Time}", now.ToString("HH:mm"));
            return [];
        }

        var tripIds      = activeTrips.Select(t => t.TripId).ToHashSet();
        var tripRouteMap = activeTrips.ToDictionary(t => t.TripId, t => t.RouteId);

        // 4. Load stop_times for active train trips
        var stopTimes = await db.GtfsStopTimes
            .Where(st => tripIds.Contains(st.TripId))
            .OrderBy(st => st.TripId)
            .ThenBy(st => st.StopSequence)
            .ToListAsync(ct);

        // 5. Load GPS coordinates for the involved stops
        var stopIds    = stopTimes.Select(st => st.StopId).Distinct().ToHashSet();
        var stopCoords = await db.GtfsStops
            .Where(s => stopIds.Contains(s.StopId))
            .ToDictionaryAsync(s => s.StopId, s => (s.StopLat, s.StopLon), ct);

        // 6. Interpolate position per trip
        var positions = new List<TrainPosition>();

        foreach (var tripGroup in stopTimes.GroupBy(st => st.TripId))
        {
            var tripId = tripGroup.Key;
            if (!tripRouteMap.TryGetValue(tripId, out var routeId))   continue;
            if (!matchedRoutes.TryGetValue(routeId, out var lineInfo)) continue;

            var pos = ComputeInterpolatedPosition(
                tripGroup.OrderBy(st => st.StopSequence).ToList(),
                stopCoords,
                nowSeconds);

            if (pos is null) continue;

            positions.Add(new TrainPosition(
                lineInfo.LineId,
                lineInfo.LineCode,
                pos.Value.Lat,
                pos.Value.Lng,
                DateTimeOffset.UtcNow));
        }

        // Deduplicate: one representative position per line (first active trip found)
        var result = positions
            .GroupBy(p => p.LineCode)
            .Select(g => g.First())
            .ToList();

        logger.LogInformation(
            "GTFS: Computed {Count} train positions from {TripCount} active trips",
            result.Count, activeTrips.Count);

        return result;
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private async Task<HashSet<string>> GetActiveServiceIdsAsync(
        DateOnly today, DayOfWeek dayOfWeek, CancellationToken ct)
    {
        // Npgsql requires DateTimeKind.Utc for 'timestamp with time zone' columns
        var todayDt = DateTime.SpecifyKind(today.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc);
        var calendars = await db.GtfsCalendars
            .Where(c => c.StartDate <= todayDt && c.EndDate >= todayDt)
            .ToListAsync(ct);

        return calendars
            .Where(c => dayOfWeek switch
            {
                DayOfWeek.Monday    => c.Monday,
                DayOfWeek.Tuesday   => c.Tuesday,
                DayOfWeek.Wednesday => c.Wednesday,
                DayOfWeek.Thursday  => c.Thursday,
                DayOfWeek.Friday    => c.Friday,
                DayOfWeek.Saturday  => c.Saturday,
                DayOfWeek.Sunday    => c.Sunday,
                _                   => false
            })
            .Select(c => c.ServiceId)
            .ToHashSet();
    }

    /// <summary>
    /// Tries to match a GTFS <paramref name="routeShortName"/> against our internal lines.
    /// Matching strategy (in order):
    ///   1. Strip hyphens/spaces, case-insensitive full match  ("1-Azul" == "1-AZUL")
    ///   2. Leading-number prefix match  ("1" matches "1-AZUL", "7" matches "7-RUBI")
    /// </summary>
    private static bool TryMatchLine(
        string routeShortName,
        IEnumerable<Line> lines,
        out Line matched)
    {
        var normRoute = Normalize(routeShortName);
        var routeNum  = LeadingDigitsRe.Match(routeShortName).Value;

        foreach (var line in lines)
        {
            // Full normalised match
            if (Normalize(line.Code) == normRoute)
            {
                matched = line;
                return true;
            }

            // Numeric prefix match ("7" ↔ "7-RUBI")
            if (routeNum.Length > 0)
            {
                var lineNum = LeadingDigitsRe.Match(line.Code).Value;
                if (lineNum == routeNum)
                {
                    matched = line;
                    return true;
                }
            }
        }

        matched = null!;
        return false;
    }

    private static string Normalize(string s) =>
        s.Replace("-", "").Replace(" ", "").ToUpperInvariant();

    /// <summary>
    /// Finds the segment where <paramref name="nowSeconds"/> falls between consecutive
    /// stop departure/arrival times and returns the linearly interpolated GPS position.
    /// Returns <c>null</c> if the trip is not currently running.
    /// </summary>
    private static (double Lat, double Lng)? ComputeInterpolatedPosition(
        List<GtfsStopTime> times,
        IReadOnlyDictionary<string, (double Lat, double Lon)> stopCoords,
        int nowSeconds)
    {
        if (times.Count < 2) return null;

        for (int i = 0; i < times.Count - 1; i++)
        {
            var from = times[i];
            var to   = times[i + 1];

            var dep = ParseGtfsTime(from.DepartureTime ?? from.ArrivalTime);
            var arr = ParseGtfsTime(to.ArrivalTime    ?? to.DepartureTime);

            if (dep is null || arr is null || arr <= dep) continue;
            if (nowSeconds < dep.Value || nowSeconds > arr.Value) continue;

            if (!stopCoords.TryGetValue(from.StopId, out var posA)) continue;
            if (!stopCoords.TryGetValue(to.StopId,   out var posB)) continue;

            var t = Math.Clamp(
                (double)(nowSeconds - dep.Value) / (arr.Value - dep.Value),
                0.0, 1.0);

            return (Lerp(posA.Lat, posB.Lat, t), Lerp(posA.Lon, posB.Lon, t));
        }

        return null;
    }

    /// <summary>Parses a GTFS time string "HH:MM:SS" (hours may exceed 23) to seconds.</summary>
    private static int? ParseGtfsTime(string? time)
    {
        if (string.IsNullOrEmpty(time)) return null;
        var parts = time.Split(':');
        if (parts.Length != 3) return null;
        return int.TryParse(parts[0], out var h) &&
               int.TryParse(parts[1], out var m) &&
               int.TryParse(parts[2], out var s)
            ? h * 3600 + m * 60 + s
            : null;
    }

    private static double Lerp(double a, double b, double t) => a + (b - a) * t;
}

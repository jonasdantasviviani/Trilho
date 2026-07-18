using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;
using Trilho.API.DTOs;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Workers;

namespace Trilho.API.Endpoints;

public static class StationEndpoints
{
    public static IEndpointRouteBuilder MapStationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/stations",                    GetStationsListAsync).WithName("GetStationsList");
        app.MapGet("/api/stations/{id:int}/crowd",     GetCrowdAsync)       .WithName("GetStationCrowd")   .RequireAuthorization();
        app.MapGet("/api/stations/{id:int}/forecast",  GetForecastAsync)    .WithName("GetStationForecast").RequireAuthorization();
        app.MapGet("/api/stations/{id:int}/arrivals",  GetArrivalsAsync)    .WithName("GetStationArrivals").RequireAuthorization();
        return app;
    }

    private static async Task<IResult> GetStationsListAsync(
        AppDbContext db, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow.AddMinutes(-5);
        var stations = await db.Stations
            .Include(s => s.Line)
            .Include(s => s.CrowdSnapshots
                .Where(c => c.CapturedAt >= now)
                .OrderByDescending(c => c.CapturedAt)
                .Take(1))
            .ToListAsync(ct);

        var result = stations.Select(s => {
            var latest = s.CrowdSnapshots.FirstOrDefault();
            return new StationListDto(
                s.Id,
                s.Name,
                s.Line.Code,
                s.Line.ColorHex,
                Lat: s.Location?.Y ?? 0,   // PostGIS Point: Y = latitude
                Lng: s.Location?.X ?? 0,   // PostGIS Point: X = longitude
                DensityLevel: latest?.DensityLevel.ToString() ?? "Low",
                Density: latest?.InferredDensity ?? 0m);
        });

        return Results.Ok(result);
    }

    private static async Task<IResult> GetCrowdAsync(int id, AppDbContext db, CancellationToken ct)
    {
        var station = await db.Stations.FindAsync([id], ct);
        if (station is null) return Results.NotFound();

        var history = await db.CrowdSnapshots
            .Where(s => s.StationId == id && s.CapturedAt >= DateTimeOffset.UtcNow.AddHours(-3))
            .OrderByDescending(s => s.CapturedAt)
            .Take(30)
            .ToListAsync(ct);

        // If no crowd data exists yet, return a zeroed-out placeholder so the
        // Flutter client can render the screen instead of showing an error.
        if (history.Count == 0)
        {
            return Results.Ok(new CrowdDto(
                id, station.Name, 0m, "Unknown", "None",
                DateTimeOffset.UtcNow, []));
        }

        var latest = history.First();
        var dto = new CrowdDto(
            id,
            station.Name,
            latest.InferredDensity,
            latest.DensityLevel.ToString(),
            latest.Source.ToString(),
            latest.CapturedAt,
            history.Skip(1).Select(h => new CrowdHistoryPoint(
                h.InferredDensity, h.DensityLevel.ToString(), h.CapturedAt))
        );

        return Results.Ok(dto);
    }

    private static async Task<IResult> GetForecastAsync(int id, AppDbContext db, CancellationToken ct)
    {
        var station = await db.Stations.FindAsync([id], ct);
        if (station is null) return Results.NotFound();

        var now = DateTimeOffset.UtcNow;
        var dayType = now.DayOfWeek switch
        {
            DayOfWeek.Saturday => DayType.Saturday,
            DayOfWeek.Sunday   => DayType.Sunday,
            _                  => DayType.Weekday
        };

        var forecast = await db.HistoricalDemands
            .Where(h => h.StationId == id && h.DayType == dayType
                        && h.Hour >= now.Hour && h.Hour <= now.Hour + 2)
            .OrderBy(h => h.Hour)
            .ToListAsync(ct);

        var result = forecast.Select(h => {
            double ratio = (double)h.AvgPassengers / station.Capacity;
            string level = ratio switch { < 0.3 => "Low", < 0.6 => "Medium", < 0.85 => "High", _ => "Packed" };
            return new ForecastDto(h.Hour, h.AvgPassengers, level);
        });

        return Results.Ok(result);
    }

    /// <summary>
    /// Returns bus arrival predictions for a station.
    ///
    /// Primary source: <c>bus:arrivals:{id}</c> Redis cache populated every 60 s by
    /// <see cref="BusArrivalCacheWorker"/> using OlhoVivo real-time data.
    /// Fallback: headway-based estimates derived from the metro/CPTM line schedule.
    /// </summary>
    private static async Task<IResult> GetArrivalsAsync(
        int id, AppDbContext db, IConnectionMultiplexer redis, CancellationToken ct)
    {
        var station = await db.Stations
            .Include(s => s.Line)
            .FirstOrDefaultAsync(s => s.Id == id, ct);

        if (station is null) return Results.NotFound();

        // ── 1. Try real-time OlhoVivo cache ────────────────────────────────
        var cached = await redis.GetDatabase().StringGetAsync($"bus:arrivals:{id}");
        if (cached.HasValue)
        {
            try
            {
                var cachedDirs = JsonSerializer.Deserialize<List<BusDirectionCache>>((string)cached!);
                if (cachedDirs is { Count: > 0 })
                {
                    var realDirs = cachedDirs.Select(d => new DirectionArrivalsDto(
                        Terminus: d.Terminus,
                        LineCode: d.LineCode,
                        Arrivals: d.Arrivals.Select(a => new ArrivalTimeDto(a.EstimatedMinutes, a.IsEstimated))));
                    return Results.Ok(new StationArrivalsDto(id, realDirs));
                }
            }
            catch
            {
                // Corrupted cache entry — fall through to headway fallback
            }
        }

        // ── 2. Fallback: headway-based estimates ───────────────────────────
        return Results.Ok(HeadwayFallback(id, station.Line, db));
    }

    /// <summary>
    /// Generates deterministic headway-based arrival estimates when OlhoVivo data is
    /// unavailable (token not set, worker not yet run, or no bus stops found nearby).
    /// </summary>
    private static StationArrivalsDto HeadwayFallback(
        int stationId,
        Trilho.Domain.Entities.Line line,
        AppDbContext db)
    {
        var now = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(-3)); // BRT

        bool isPeak = now.DayOfWeek is not (DayOfWeek.Saturday or DayOfWeek.Sunday)
                      && ((now.Hour >= 6 && now.Hour < 9) || (now.Hour >= 17 && now.Hour < 20));
        int headwaySec = isPeak ? line.HeadwayPeakSec : line.HeadwayOffPeakSec;
        int headwayMin = Math.Max(1, headwaySec / 60);

        // Ordered termini from DB (synchronous query is fine in a fallback path
        // because we already have the DbContext open and the table is small).
        var lineStations = db.Stations
            .Where(s => s.LineId == line.Id)
            .OrderBy(s => s.Sequence)
            .Select(s => s.Name)
            .ToList();

        if (lineStations.Count == 0)
            return new StationArrivalsDto(stationId, []);

        var terminus1 = lineStations.First();
        var terminus2 = lineStations.Last();

        int bucket = (int)(now.ToUnixTimeSeconds() / headwaySec);
        int offset = ((stationId * 31 + bucket) % headwayMin) + 1;

        ArrivalTimeDto[] MakeArrivals(int first) =>
        [
            new(first,                IsEstimated: true),
            new(first + headwayMin,   IsEstimated: true),
            new(first + headwayMin*2, IsEstimated: true),
        ];

        DirectionArrivalsDto[] dirs =
        [
            new(terminus2, line.Code, MakeArrivals(offset)),
            new(terminus1, line.Code, MakeArrivals(offset + headwayMin / 2 + 1)),
        ];

        return new StationArrivalsDto(stationId, dirs);
    }
}

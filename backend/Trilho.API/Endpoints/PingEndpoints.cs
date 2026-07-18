using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using Trilho.API.DTOs;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

public static class PingEndpoints
{
    private const double StationGeofenceRadiusMeters = 200;

    // Anti-fraud thresholds
    private const double MaxSpeedKmh        = 30.0;  // above this → not inside a station
    private const double MinPingIntervalSec = 120.0; // reject duplicate pings in < 2 min

    public static IEndpointRouteBuilder MapPingEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/users/pings",      RecordPingAsync)       .WithName("RecordPing")    .RequireAuthorization();
        app.MapGet ("/api/stations/nearby", GetNearbyStationsAsync).WithName("GetNearbyStations").RequireAuthorization();
        return app;
    }

    private static async Task<IResult> RecordPingAsync(
        PingRequestDto dto,
        ClaimsPrincipal principal,
        AppDbContext db,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var now   = DateTimeOffset.UtcNow;
        var point = CreatePoint(dto.Lat, dto.Lng);

        // ── Anti-fraud: deduplication ────────────────────────────────────────
        // Reject if the same user already pinged within the last 2 min.
        var lastPing = await db.UserPings
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .FirstOrDefaultAsync(ct);

        if (lastPing is not null)
        {
            var secondsSinceLast = (now - lastPing.CreatedAt).TotalSeconds;
            if (secondsSinceLast < MinPingIntervalSec)
                return Results.Ok(new PingResponseDto(0, string.Empty, false, Rejected: true));

            // ── Anti-fraud: velocity check ────────────────────────────────────
            // If the user moved too fast since the last ping they are probably not on foot.
            var lastPoint      = CreatePoint(lastPing.Lat, lastPing.Lng);
            var distanceMeters = lastPoint.Distance(point) * 111_000; // rough deg→m conversion
            var speedKmh       = (distanceMeters / 1000.0) / (secondsSinceLast / 3600.0);

            if (speedKmh > MaxSpeedKmh)
                return Results.Ok(new PingResponseDto(0, string.Empty, false, Rejected: true));
        }

        var station = await FindNearestStationAsync(db, point, ct);

        if (station is not null)
        {
            var ping = new Trilho.Domain.Entities.UserPing
            {
                UserId    = userId,
                StationId = station.Id,
                Lat       = dto.Lat,
                Lng       = dto.Lng,
                CreatedAt = dto.Timestamp
            };
            db.UserPings.Add(ping);
            await db.SaveChangesAsync(ct);

            return Results.Ok(new PingResponseDto(station.Id, station.Name, true));
        }

        return Results.Ok(new PingResponseDto(0, string.Empty, false));
    }

    private static async Task<IResult> GetNearbyStationsAsync(
        double lat, double lng,
        double radiusMeters,
        AppDbContext db,
        CancellationToken ct)
    {
        var point = CreatePoint(lat, lng);
        var maxDistance = Math.Max(radiusMeters, 1000); // min 1km

        var nearby = await db.Stations
            .Include(s => s.Line)
            .Where(s => s.Location.IsWithinDistance(point, maxDistance))
            .Select(s => new NearbyStationsDto(
                s.Id,
                s.Name,
                s.Line.Code,
                s.Location.Distance(point)))
            .OrderBy(s => s.DistanceMeters)
            .Take(10)
            .ToListAsync(ct);

        return Results.Ok(nearby);
    }

    private static async Task<Trilho.Domain.Entities.Station?> FindNearestStationAsync(
        AppDbContext db, Point point, CancellationToken ct)
    {
        return await db.Stations
            .Where(s => s.Location.IsWithinDistance(point, StationGeofenceRadiusMeters))
            .OrderBy(s => s.Location.Distance(point))
            .FirstOrDefaultAsync(ct);
    }

    private static Point CreatePoint(double lat, double lng) =>
        new Point(lng, lat) { SRID = 4326 };

    private static Guid GetUserId(ClaimsPrincipal p)
    {
        var id = p.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(id, out var g) ? g : Guid.Empty;
    }
}

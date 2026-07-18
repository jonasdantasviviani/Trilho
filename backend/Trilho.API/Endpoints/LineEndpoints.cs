using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;
using Trilho.API.DTOs;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

public static class LineEndpoints
{
    public static IEndpointRouteBuilder MapLineEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/lines",                GetAllLinesAsync)    .WithName("GetLines");
        app.MapGet("/api/lines/{code}/status",  GetLineStatusAsync)  .WithName("GetLineStatus");
        app.MapGet("/api/lines/{code}/vehicles",GetLineVehiclesAsync).WithName("GetLineVehicles").RequireAuthorization();
        return app;
    }

    private static async Task<IResult> GetAllLinesAsync(AppDbContext db, CancellationToken ct)
    {
        var lines = await db.Lines.ToListAsync(ct);

        var latestStatuses = await db.LineStatuses
            .GroupBy(s => s.LineId)
            .Select(g => g.OrderByDescending(s => s.CapturedAt).First())
            .ToDictionaryAsync(s => s.LineId, ct);

        var dtos = lines.Select(l => {
            latestStatuses.TryGetValue(l.Id, out var status);
            return new LineDto(l.Id, l.Code, l.Name, l.Type.ToString(), l.ColorHex,
                status?.Status.ToString() ?? "Normal", status?.Message, status?.CapturedAt);
        });

        return Results.Ok(dtos);
    }

    private static async Task<IResult> GetLineStatusAsync(string code, AppDbContext db, CancellationToken ct)
    {
        var line = await db.Lines.FirstOrDefaultAsync(l => l.Code == code, ct);
        if (line is null) return Results.NotFound();

        var status = await db.LineStatuses
            .Where(s => s.LineId == line.Id)
            .OrderByDescending(s => s.CapturedAt)
            .FirstOrDefaultAsync(ct);

        var stations = await db.Stations
            .Where(s => s.LineId == line.Id)
            .OrderBy(s => s.Sequence)
            .ToListAsync(ct);

        var stationIds = stations.Select(s => s.Id).ToList();
        var latestCrowd = await db.CrowdSnapshots
            .Where(c => stationIds.Contains(c.StationId))
            .GroupBy(c => c.StationId)
            .Select(g => g.OrderByDescending(c => c.CapturedAt).First())
            .ToDictionaryAsync(c => c.StationId, ct);

        var stationDtos = stations.Select(s => {
            latestCrowd.TryGetValue(s.Id, out var crowd);
            return new StationCrowdDto(s.Id, s.Name,
                crowd?.DensityLevel.ToString() ?? "Low",
                crowd?.InferredDensity ?? 0);
        });

        var dto = new LineStatusDto(
            line.Code,
            status?.Status.ToString() ?? "Normal",
            status?.Message,
            status?.CapturedAt ?? DateTimeOffset.UtcNow,
            stationDtos);

        return Results.Ok(dto);
    }

    private static async Task<IResult> GetLineVehiclesAsync(
        string code, IConnectionMultiplexer redis, CancellationToken ct)
    {
        var db     = redis.GetDatabase();
        var server = redis.GetServer(redis.GetEndPoints().First());
        var keys   = server.Keys(pattern: "bus:pos:*").ToArray();

        var vehicles = new List<VehiclePositionDto>();
        foreach (var key in keys)
        {
            var val = await db.StringGetAsync(key);
            if (!val.HasValue) continue;

            var parts = val.ToString().Split(',');
            if (parts.Length < 4) continue;
            if (!parts[2].Equals(code, StringComparison.OrdinalIgnoreCase)) continue;

            if (double.TryParse(parts[0], System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture, out var lat) &&
                double.TryParse(parts[1], System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture, out var lng))
            {
                var vid = int.TryParse(key.ToString().Split(':').Last(), out var v) ? v : 0;
                vehicles.Add(new VehiclePositionDto(vid, lat, lng, parts[2],
                    DateTimeOffset.TryParse(parts[3], out var dt) ? dt : DateTimeOffset.UtcNow));
            }
        }

        return Results.Ok(vehicles);
    }
}

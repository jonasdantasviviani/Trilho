using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

public class CrowdInferenceWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<CrowdInferenceWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("CrowdInferenceWorker started.");
        while (!stoppingToken.IsCancellationRequested)
        {
            await RunAsync(stoppingToken);
            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var now = DateTimeOffset.UtcNow;
        var dayType = now.DayOfWeek switch
        {
            DayOfWeek.Saturday => DayType.Saturday,
            DayOfWeek.Sunday   => DayType.Sunday,
            _                  => DayType.Weekday
        };
        short hour = (short)now.Hour;

        var stations = await db.Stations.ToListAsync(ct);

        var latestStatusByLine = await db.LineStatuses
            .GroupBy(s => s.LineId)
            .Select(g => g.OrderByDescending(s => s.CapturedAt).First())
            .ToDictionaryAsync(s => s.LineId, ct);

        var historicalByStation = await db.HistoricalDemands
            .Where(h => h.DayType == dayType && h.Hour == hour)
            .ToDictionaryAsync(h => h.StationId, ct);

        var snapshots = new List<CrowdSnapshot>();

        foreach (var station in stations)
        {
            if (!historicalByStation.TryGetValue(station.Id, out var hist)) continue;

            var opStatus = latestStatusByLine.TryGetValue(station.LineId, out var ls)
                ? ls.Status
                : OperationalStatus.Normal;

            var result = CrowdInferenceEngine.Infer(hist.AvgPassengers, station.Capacity, opStatus);

            snapshots.Add(new CrowdSnapshot
            {
                StationId       = station.Id,
                UserCount       = 0,
                InferredDensity = result.Score,
                DensityLevel    = result.Level,
                Source          = CrowdSource.Historical,
                CapturedAt      = now
            });
        }

        db.CrowdSnapshots.AddRange(snapshots);
        await db.SaveChangesAsync(ct);
        logger.LogDebug("CrowdInferenceWorker: {Count} snapshots written.", snapshots.Count);
    }
}

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;

namespace Trilho.Infrastructure.Workers;

public class CrowdDensityWorker(
    IServiceScopeFactory scopeFactory,
    DataSourceHealthRegistry health,
    ILogger<CrowdDensityWorker> logger) : BackgroundService
{
    private const string SourceName = "CrowdDensity";
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(2);
    private static readonly double MaxPingBoost = 0.15;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("CrowdDensityWorker started");
        while (!stoppingToken.IsCancellationRequested)
        {
            try { await ProcessPingDensitiesAsync(stoppingToken); }
            catch { /* health + log already handled inside ProcessPingDensitiesAsync */ }

            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task ProcessPingDensitiesAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        try
        {
            var now = DateTimeOffset.UtcNow;
            var windowStart = now.AddMinutes(-15);

            var pingCounts = await db.UserPings
                .Where(p => p.CreatedAt >= windowStart)
                .GroupBy(p => p.StationId)
                .Select(g => new { StationId = g.Key, Count = g.Count() })
                .ToListAsync(ct);

            if (pingCounts.Count == 0)
            {
                health.ReportFailure(SourceName, "No user pings in the last 15 minutes — crowdsourcing may be inactive.");
                logger.LogDebug("No user pings to process for density update");
                return;
            }

            int updatedCount = 0;
            foreach (var stationPings in pingCounts)
            {
                var station = await db.Stations
                    .Include(s => s.Line)
                    .FirstOrDefaultAsync(s => s.Id == stationPings.StationId, ct);

                if (station is null) continue;

                var latestSnapshot = await db.CrowdSnapshots
                    .Where(s => s.StationId == stationPings.StationId)
                    .OrderByDescending(s => s.CapturedAt)
                    .FirstOrDefaultAsync(ct);

                if (latestSnapshot is null) continue;

                decimal baseDensity = latestSnapshot.InferredDensity;
                double pingBoost = CalculatePingBoost(stationPings.Count);
                decimal adjustedDensity = Math.Min(baseDensity + (decimal)pingBoost, 1.0m);

                var densityLevel = CrowdInferenceEngine.Infer(
                    (int)(adjustedDensity * station.Capacity),
                    station.Capacity,
                    OperationalStatus.Normal).Level;

                var newSnapshot = new CrowdSnapshot
                {
                    StationId = stationPings.StationId,
                    InferredDensity = adjustedDensity,
                    DensityLevel = densityLevel,
                    Source = CrowdSource.UserPing,
                    CapturedAt = now
                };

                db.CrowdSnapshots.Add(newSnapshot);
                updatedCount++;

                logger.LogDebug(
                    "Station {StationId} ({StationName}): {Count} pings, boost {Boost:P1}, density {Density:P1}",
                    stationPings.StationId, station.Name, stationPings.Count, pingBoost, adjustedDensity);
            }

            await db.SaveChangesAsync(ct);

            health.ReportSuccess(SourceName);
            logger.LogInformation("Crowd density updated for {Count} stations", updatedCount);
        }
        catch (Exception ex)
        {
            health.ReportFailure(SourceName, ex.Message);
            logger.LogError(ex, "Error processing ping densities");
            throw;
        }
    }

    private static double CalculatePingBoost(int pingCount)
    {
        if (pingCount < 5) return 0;
        double normalizedPings = pingCount / 10.0;
        double densityBoost = normalizedPings * 0.05;
        return Math.Min(densityBoost, MaxPingBoost);
    }
}

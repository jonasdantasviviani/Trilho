using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using Trilho.Infrastructure.DataSources;
using Trilho.Infrastructure.Services;

namespace Trilho.Infrastructure.Workers;

public class BusPositionWorker(
    OlhoVivoClient olhoVivo,
    IConnectionMultiplexer redis,
    DataSourceHealthRegistry health,
    ILogger<BusPositionWorker> logger) : BackgroundService
{
    private const string SourceName = "OlhoVivo";

    // Defensive throttle: OlhoVivo rate limits are undocumented.
    // Keep at least 25 s between polls even if the interval timer fires sooner.
    private static readonly TimeSpan Interval    = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan MinInterval = TimeSpan.FromSeconds(25);
    private DateTimeOffset _lastRun = DateTimeOffset.MinValue;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("BusPositionWorker started.");
        while (!stoppingToken.IsCancellationRequested)
        {
            var elapsed = DateTimeOffset.UtcNow - _lastRun;
            if (elapsed < MinInterval)
                await Task.Delay(MinInterval - elapsed, stoppingToken);

            _lastRun = DateTimeOffset.UtcNow;
            await RunAsync(stoppingToken);
            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        try
        {
            var positions = await olhoVivo.GetAllVehiclePositionsAsync(ct);
            var db = redis.GetDatabase();

            var batch = db.CreateBatch();
            var tasks = positions.Select(pos =>
            {
                var key   = $"bus:pos:{pos.VehicleId}";
                // Include capturedAt so consumers can detect stale data.
                var value = $"{pos.Lat},{pos.Lng},{pos.LineCode},{pos.UpdatedAt:O},{DateTimeOffset.UtcNow:O}";
                return batch.StringSetAsync(key, value, TimeSpan.FromMinutes(2));
            }).ToList();

            batch.Execute();
            await Task.WhenAll(tasks);

            if (positions.Count == 0)
            {
                health.ReportFailure(SourceName, "No vehicle positions returned — OlhoVivo token may be missing or API is unreachable.");
                logger.LogDebug("BusPositionWorker: no vehicle positions returned.");
                return;
            }

            health.ReportSuccess(SourceName);
            logger.LogDebug("BusPositionWorker: cached {Count} vehicle positions.", positions.Count);
        }
        catch (Exception ex)
        {
            health.ReportFailure(SourceName, ex.Message);
            logger.LogError(ex, "BusPositionWorker error.");
        }
    }
}

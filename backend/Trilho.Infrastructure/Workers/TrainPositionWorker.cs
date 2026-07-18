using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using System.Text.Json;
using Trilho.Domain.Interfaces;
using Trilho.Infrastructure.Services;

namespace Trilho.Infrastructure.Workers;

public class TrainPositionWorker(
    IServiceScopeFactory scopeFactory,
    DataSourceHealthRegistry health,
    ILogger<TrainPositionWorker> logger) : BackgroundService
{
    private const string SourceName = "GTFS";
    private static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);
    private static readonly string RedisKey = "train:positions";

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("TrainPositionWorker started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try { await UpdateTrainPositionsAsync(stoppingToken); }
            catch { /* health + log already handled inside UpdateTrainPositionsAsync */ }

            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task UpdateTrainPositionsAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var trainProvider = scope.ServiceProvider.GetRequiredService<ITrainPositionProvider>();
        var redis = scope.ServiceProvider.GetRequiredService<IConnectionMultiplexer>();

        try
        {
            var positions = await trainProvider.GetPositionsAsync(ct);
            var positionList = positions.ToList();

            if (positionList.Count == 0)
            {
                health.ReportFailure(SourceName, "No train positions returned — provider may be mocked or unreachable.");
                logger.LogDebug("No train positions available");
                return;
            }

            var json = JsonSerializer.Serialize(positionList);
            var db = redis.GetDatabase();
            await db.StringSetAsync(RedisKey, json, TimeSpan.FromMinutes(2));

            health.ReportSuccess(SourceName);
            logger.LogInformation("Updated {Count} train positions in Redis cache", positionList.Count);
        }
        catch (Exception ex)
        {
            health.ReportFailure(SourceName, ex.Message);
            logger.LogError(ex, "Error updating train positions");
            throw; // re-throw so the outer catch in ExecuteAsync logs it
        }
    }

    public static async Task<IEnumerable<TrainPosition>> GetCachedPositionsAsync(
        IConnectionMultiplexer redis,
        CancellationToken ct = default)
    {
        var db = redis.GetDatabase();
        var json = await db.StringGetAsync(RedisKey);

        if (json.IsNullOrEmpty)
        {
            return Enumerable.Empty<TrainPosition>();
        }

        return JsonSerializer.Deserialize<List<TrainPosition>>(json!) ?? [];
    }
}

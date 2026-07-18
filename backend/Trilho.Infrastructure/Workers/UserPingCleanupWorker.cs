using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

public class UserPingCleanupWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<UserPingCleanupWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan PingTtl  = TimeSpan.FromMinutes(10);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var cutoff = DateTimeOffset.UtcNow - PingTtl;
            var deleted = await db.UserPings
                .Where(p => p.CreatedAt < cutoff)
                .ExecuteDeleteAsync(stoppingToken);
            if (deleted > 0)
                logger.LogInformation("UserPingCleanupWorker: deleted {Count} old pings.", deleted);
            await Task.Delay(Interval, stoppingToken);
        }
    }
}

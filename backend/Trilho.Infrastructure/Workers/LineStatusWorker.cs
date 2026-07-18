using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Interfaces;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;

namespace Trilho.Infrastructure.Workers;

public class LineStatusWorker(
    IServiceScopeFactory scopeFactory,
    DataSourceHealthRegistry health,
    ILogger<LineStatusWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(2);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("LineStatusWorker started.");
        while (!stoppingToken.IsCancellationRequested)
        {
            await RunAsync(stoppingToken);
            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db       = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var scrapers = scope.ServiceProvider.GetServices<ILineStatusScraper>();
        var lines    = await db.Lines.ToDictionaryAsync(l => l.Code, ct);

        foreach (var scraper in scrapers)
        {
            var sourceName = scraper.GetType().Name;
            try
            {
                var statuses = await scraper.ScrapeAsync(ct);
                var list = statuses.ToList();

                if (list.Count == 0)
                {
                    // Scraper returned nothing — treat as degraded (site may have changed layout).
                    health.ReportFailure(sourceName, "Scraper returned 0 results — HTML layout may have changed.");
                    logger.LogWarning("{Scraper} returned 0 results — possible layout change.", sourceName);
                    continue;
                }

                foreach (var s in list)
                {
                    if (!lines.TryGetValue(s.LineCode, out var line)) continue;
                    db.LineStatuses.Add(new LineStatusEntry
                    {
                        LineId     = line.Id,
                        Status     = s.Status,
                        Message    = s.Message,
                        CapturedAt = DateTimeOffset.UtcNow
                    });
                }
                health.ReportSuccess(sourceName);
            }
            catch (Exception ex)
            {
                health.ReportFailure(sourceName, ex.Message);
                logger.LogError(ex, "Error in scraper {Scraper}", sourceName);
            }
        }

        await db.SaveChangesAsync(ct);
        logger.LogDebug("LineStatusWorker: statuses updated at {Time}", DateTimeOffset.UtcNow);
    }
}

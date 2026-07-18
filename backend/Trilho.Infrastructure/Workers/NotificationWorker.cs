using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;

namespace Trilho.Infrastructure.Workers;

public class NotificationWorker : BackgroundService
{
    private readonly IServiceProvider _sp;
    private readonly ILogger<NotificationWorker> _logger;
    private readonly IFcmService _fcm;
    private readonly TimeSpan _interval = TimeSpan.FromMinutes(1);

    public NotificationWorker(
        IServiceProvider sp,
        ILogger<NotificationWorker> logger,
        IFcmService fcm)
    {
        _sp = sp;
        _logger = logger;
        _fcm = fcm;
    }

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        _logger.LogInformation("NotificationWorker started");
        var lastChecked = DateTime.UtcNow.AddMinutes(-5);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                await CheckAndNotifyAsync(lastChecked, ct);
                lastChecked = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in NotificationWorker");
            }

            await Task.Delay(_interval, ct);
        }
    }

    private async Task CheckAndNotifyAsync(DateTime since, CancellationToken ct)
    {
        using var scope = _sp.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var changedStatuses = await db.LineStatuses
            .Include(s => s.Line)
            .Where(s => s.CapturedAt > since)
            .OrderByDescending(s => s.CapturedAt)
            .ToListAsync(ct);

        var grouped = changedStatuses
            .GroupBy(s => s.LineId)
            .ToList();

        foreach (var group in grouped)
        {
            var line = group.First().Line;
            var latest = group.First();

            if (latest.Status == OperationalStatus.Normal ||
                latest.Status == OperationalStatus.ReducedSpeed ||
                latest.Status == OperationalStatus.Suspended)
            {
                await NotifyLineStatusChangeAsync(line, latest, ct);
            }
        }
    }

    private async Task NotifyLineStatusChangeAsync(
        Line line,
        LineStatusEntry status,
        CancellationToken ct)
    {
        var (title, body) = status.Status switch
        {
            OperationalStatus.Normal => (
                $"✅ {line.Name}",
                "Linha operando normalmente"
            ),
            OperationalStatus.ReducedSpeed => (
                $"⚠️ {line.Name}",
                "Linha com velocidade reduzida"
            ),
            OperationalStatus.Suspended => (
                $"🚨 {line.Name}",
                "Operação SUSPENSA"
            ),
            _ => (
                $"📢 {line.Name}",
                $"Status alterado para {status.Status}"
            )
        };

        var topic = $"line_{line.Code.ToLowerInvariant()}";
        await _fcm.SendToTopicAsync(topic, title, body, new Dictionary<string, string>
        {
            ["lineCode"] = line.Code,
            ["lineName"] = line.Name,
            ["status"] = status.Status.ToString(),
            ["type"] = "line_status"
        });

        _logger.LogInformation(
            "Sent notification for line {Line}: {Status}",
            line.Code,
            status.Status
        );
    }
}

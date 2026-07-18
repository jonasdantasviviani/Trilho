using System.Collections.Concurrent;

namespace Trilho.Infrastructure.Services;

/// <summary>
/// Thread-safe singleton that tracks the last-known health of each data source.
/// Workers call ReportSuccess / ReportFailure after each polling cycle.
/// Exposed via GET /api/admin/health/sources.
/// </summary>
public class DataSourceHealthRegistry
{
    private readonly ConcurrentDictionary<string, SourceHealth> _sources = new();

    public void ReportSuccess(string source)
    {
        _sources[source] = new SourceHealth(source, DataSourceStatus.Healthy, DateTimeOffset.UtcNow, null);
    }

    public void ReportFailure(string source, string errorMessage)
    {
        _sources.AddOrUpdate(
            source,
            _ => new SourceHealth(source, DataSourceStatus.Down, DateTimeOffset.UtcNow, errorMessage),
            (_, existing) => existing with
            {
                Status       = DataSourceStatus.Down,
                LastCheckedAt = DateTimeOffset.UtcNow,
                LastError    = errorMessage
            });
    }

    public IReadOnlyCollection<SourceHealth> GetAll() => _sources.Values.ToList();

    public SourceHealth? Get(string source) =>
        _sources.TryGetValue(source, out var h) ? h : null;
}

public enum DataSourceStatus
{
    /// <summary>Updated successfully within the last expected interval.</summary>
    Healthy,
    /// <summary>Partial data — some scrapers succeeded, others failed.</summary>
    Degraded,
    /// <summary>Data is older than 2× the expected interval but source is not actively erroring.</summary>
    Stale,
    /// <summary>Last attempt failed with an exception.</summary>
    Down,
}

public record SourceHealth(
    string Source,
    DataSourceStatus Status,
    DateTimeOffset LastCheckedAt,
    string? LastError)
{
    /// <summary>Age of the last successful check in seconds.</summary>
    public double AgeSeconds => (DateTimeOffset.UtcNow - LastCheckedAt).TotalSeconds;

    /// <summary>Human-readable staleness: "23s ago", "4 min ago", etc.</summary>
    public string AgeLabel => AgeSeconds switch
    {
        < 60    => $"{(int)AgeSeconds}s atrás",
        < 3600  => $"{(int)(AgeSeconds / 60)} min atrás",
        _       => $"{(int)(AgeSeconds / 3600)}h atrás",
    };
}

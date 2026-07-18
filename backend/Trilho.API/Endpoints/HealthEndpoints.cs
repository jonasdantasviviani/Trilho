using Trilho.Infrastructure.Services;

namespace Trilho.API.Endpoints;

/// <summary>
/// Public (unauthenticated) health endpoint consumed by the login screen
/// to show a real-time status panel for all external data sources.
/// </summary>
public static class HealthEndpoints
{
    /// <summary>
    /// Data sources that are always expected to appear in the panel,
    /// even before their first worker cycle completes.
    /// </summary>
    private static readonly string[] KnownSources = ["OlhoVivo", "LinhasMetroApiScraper", "CrowdDensity"];

    public static IEndpointRouteBuilder MapHealthEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/health/services", GetServicesHealthAsync)
            .WithName("GetServicesHealth")
            .AllowAnonymous();

        return app;
    }

    private static IResult GetServicesHealthAsync(
        DataSourceHealthRegistry registry,
        IConfiguration config)
    {
        var reported = registry.GetAll().ToDictionary(h => h.Source, StringComparer.OrdinalIgnoreCase);
        var sources = new List<object>();

        // ── Known background-worker sources ────────────────────────────────
        foreach (var name in KnownSources)
        {
            if (reported.TryGetValue(name, out var h))
            {
                sources.Add(HealthEntry(h.Source, h.Status.ToString(), h.AgeLabel, h.AgeSeconds, h.LastError));
            }
            else
            {
                sources.Add(HealthEntry(name, "Unknown", "nunca", -1, null));
            }
        }

        // ── Any additional sources reported (e.g. per-line scrapers) ───────
        foreach (var h in reported.Values.Where(h => !KnownSources.Contains(h.Source, StringComparer.OrdinalIgnoreCase)))
        {
            sources.Add(HealthEntry(h.Source, h.Status.ToString(), h.AgeLabel, h.AgeSeconds, h.LastError));
        }

        // ── AbacatePay: synthetic entry based on config, not a worker ──────
        var apiKey = config["AbacatePay:ApiKey"];
        var payConfigured = !string.IsNullOrWhiteSpace(apiKey);
        sources.Add(HealthEntry(
            "AbacatePay",
            payConfigured ? "Healthy" : "Down",
            "N/A",
            -1,
            payConfigured ? null : "API key não configurada"));

        return Results.Ok(new
        {
            api       = "ok",
            checkedAt = DateTimeOffset.UtcNow,
            sources
        });
    }

    private static object HealthEntry(
        string source, string status, string ageLabel, double ageSeconds, string? lastError) =>
        new { source, status, ageLabel, ageSeconds, lastError };
}

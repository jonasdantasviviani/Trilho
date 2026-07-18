using Trilho.Domain.Enums;

namespace Trilho.Domain.Interfaces;

public record ScrapedLineStatus(string LineCode, OperationalStatus Status, string? Message);

public interface ILineStatusScraper
{
    Task<IEnumerable<ScrapedLineStatus>> ScrapeAsync(CancellationToken ct = default);
}

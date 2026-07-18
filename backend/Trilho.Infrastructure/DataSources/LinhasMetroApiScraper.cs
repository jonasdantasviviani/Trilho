using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Enums;
using Trilho.Domain.Interfaces;

namespace Trilho.Infrastructure.DataSources;

/// <summary>
/// Unified scraper for all Metro SP / CPTM / Via Mobilidade / Via Quatro lines.
/// Uses the CPTM AppMobileService JSON API which covers lines 1–15 via a single call.
/// Replaces the broken MetroSpScraper (404) and CptmScraper (JS-rendered, 0 results).
/// </summary>
public class LinhasMetroApiScraper(HttpClient http, ILogger<LinhasMetroApiScraper> logger) : ILineStatusScraper
{
    private const string ApiUrl =
        "http://apps.cptm.sp.gov.br:8080/AppMobileService/api/LinhasMetropolitanas";

    /// <summary>Maps LinhaId from the API to the internal line codes used in our DB.</summary>
    private static readonly Dictionary<int, string> LinhaIdToCode = new()
    {
        [1]  = "1-AZUL",
        [2]  = "2-VERDE",
        [3]  = "3-VERMELHA",
        [4]  = "4-AMARELA",
        [5]  = "5-LILAS",
        [7]  = "7-RUBI",
        [8]  = "8-DIAMANTE",
        [9]  = "9-ESMERALDA",
        [10] = "10-TURQUESA",
        [11] = "11-CORAL",
        [12] = "12-SAFIRA",
        [13] = "13-JADE",
        [15] = "15-PRATA",
    };

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    public async Task<IEnumerable<ScrapedLineStatus>> ScrapeAsync(CancellationToken ct = default)
    {
        var json  = await http.GetStringAsync(ApiUrl, ct);
        var items = JsonSerializer.Deserialize<List<LinhasMetroItem>>(json, JsonOpts);

        if (items is null || items.Count == 0)
        {
            logger.LogWarning("LinhasMetroApi returned no data.");
            return [];
        }

        var results = new List<ScrapedLineStatus>();
        foreach (var item in items)
        {
            if (!LinhaIdToCode.TryGetValue(item.LinhaId, out var code))
            {
                logger.LogDebug("LinhasMetroApi: unknown LinhaId {Id} ({Nome}) — skipped.", item.LinhaId, item.Nome);
                continue;
            }

            var status  = MapStatus(item.Status);
            var message = string.IsNullOrWhiteSpace(item.Descricao) ? null : item.Descricao.Trim();
            results.Add(new ScrapedLineStatus(code, status, message));
        }

        logger.LogInformation("LinhasMetroApi: {Count} line statuses updated.", results.Count);
        return results;
    }

    private static OperationalStatus MapStatus(string? status) => status?.Trim() switch
    {
        "Operação Normal"     => OperationalStatus.Normal,
        "Velocidade Reduzida" => OperationalStatus.ReducedSpeed,
        "Operação Parcial"    => OperationalStatus.Partial,
        "Paralisada"          => OperationalStatus.Suspended,
        "Suspensa"            => OperationalStatus.Suspended,
        "Encerrada"           => OperationalStatus.Suspended,
        _                     => OperationalStatus.Normal,
    };
}

// ── Response model ─────────────────────────────────────────────────────────────

internal record LinhasMetroItem(
    [property: JsonPropertyName("LinhaId")]     int    LinhaId,
    [property: JsonPropertyName("Nome")]        string Nome,
    [property: JsonPropertyName("Status")]      string Status,
    [property: JsonPropertyName("Descricao")]   string Descricao,
    [property: JsonPropertyName("Tipo")]        string Tipo,
    [property: JsonPropertyName("DataGeracao")] string DataGeracao);

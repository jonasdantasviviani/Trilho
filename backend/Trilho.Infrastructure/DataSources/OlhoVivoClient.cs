using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Trilho.Infrastructure.DataSources;

public class OlhoVivoOptions
{
    public string Token { get; set; } = string.Empty;
    public string BaseUrl { get; set; } = "https://api.olhovivo.sptrans.com.br/v2.1";
}

public class OlhoVivoClient(
    HttpClient http,
    IOptions<OlhoVivoOptions> opts,
    ILogger<OlhoVivoClient> logger)
{
    private bool _authenticated = false;

    // ── Vehicle positions ─────────────────────────────────────────────────────

    public async Task<List<BusVehiclePosition>> GetAllVehiclePositionsAsync(CancellationToken ct = default)
    {
        if (!await EnsureConfiguredAsync()) return [];
        if (!await EnsureAuthenticatedAsync(ct)) return [];

        var response = await http.GetAsync("Posicao", ct);

        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            _authenticated = false;
            if (!await EnsureAuthenticatedAsync(ct)) return [];
            response = await http.GetAsync("Posicao", ct);
        }

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync(ct);
        return ParsePositions(json);
    }

    // ── Stop search (/Parada/Buscar) ──────────────────────────────────────────

    /// <summary>
    /// Searches for bus stops whose name contains <paramref name="searchTerm"/>.
    /// Returns an empty list when the token is not configured or the request fails.
    /// </summary>
    public async Task<List<OlhoVivoBusStop>> SearchStopsByNameAsync(
        string searchTerm, CancellationToken ct = default)
    {
        if (!await EnsureConfiguredAsync()) return [];
        if (!await EnsureAuthenticatedAsync(ct)) return [];

        var encoded  = Uri.EscapeDataString(searchTerm);
        var response = await http.GetAsync($"Parada/Buscar?termosBusca={encoded}", ct);

        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            _authenticated = false;
            if (!await EnsureAuthenticatedAsync(ct)) return [];
            response = await http.GetAsync($"Parada/Buscar?termosBusca={encoded}", ct);
        }

        if (!response.IsSuccessStatusCode)
        {
            logger.LogWarning("OlhoVivo Parada/Buscar returned {Status}", response.StatusCode);
            return [];
        }

        var json = await response.Content.ReadAsStringAsync(ct);
        return JsonSerializer.Deserialize<List<OlhoVivoBusStop>>(json) ?? [];
    }

    // ── Arrival predictions (/Previsao/Parada) ────────────────────────────────

    /// <summary>
    /// Returns real-time arrival predictions for the given bus <paramref name="stopCode"/>.
    /// Returns <c>null</c> when the stop has no data or the request fails.
    /// </summary>
    public async Task<OlhoVivoArrivalResponse?> GetArrivalsByStopAsync(
        int stopCode, CancellationToken ct = default)
    {
        if (!await EnsureConfiguredAsync()) return null;
        if (!await EnsureAuthenticatedAsync(ct)) return null;

        var response = await http.GetAsync($"Previsao/Parada?codigoParada={stopCode}", ct);

        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            _authenticated = false;
            if (!await EnsureAuthenticatedAsync(ct)) return null;
            response = await http.GetAsync($"Previsao/Parada?codigoParada={stopCode}", ct);
        }

        if (!response.IsSuccessStatusCode)
        {
            logger.LogWarning("OlhoVivo Previsao/Parada returned {Status} for stop {StopCode}",
                response.StatusCode, stopCode);
            return null;
        }

        var json = await response.Content.ReadAsStringAsync(ct);
        return JsonSerializer.Deserialize<OlhoVivoArrivalResponse>(json);
    }

    // ── Auth helpers ──────────────────────────────────────────────────────────

    private Task<bool> EnsureConfiguredAsync()
    {
        if (string.IsNullOrWhiteSpace(opts.Value.Token))
        {
            logger.LogDebug("OlhoVivo token not configured — skipping request.");
            return Task.FromResult(false);
        }
        return Task.FromResult(true);
    }

    private async Task<bool> EnsureAuthenticatedAsync(CancellationToken ct)
    {
        if (_authenticated) return true;
        try
        {
            await AuthenticateAsync(ct);
            return true;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OlhoVivo authentication failed.");
            return false;
        }
    }

    private async Task AuthenticateAsync(CancellationToken ct)
    {
        var url  = $"Login/Autenticar?token={opts.Value.Token}";
        var resp = await http.PostAsync(url, null, ct);
        resp.EnsureSuccessStatusCode();
        _authenticated = true;
        logger.LogInformation("OlhoVivo authenticated successfully.");
    }

    // ── Static parsers ────────────────────────────────────────────────────────

    public static List<BusVehiclePosition> ParsePositions(string json)
    {
        var root = JsonSerializer.Deserialize<OlhoVivoPositionResponse>(json);
        if (root?.Lines is null) return [];

        return root.Lines
            .SelectMany(line => line.Vehicles.Select(v => new BusVehiclePosition(
                line.LineCode,
                v.VehicleId,
                v.Lat,
                v.Lng,
                DateTimeOffset.TryParse(v.UpdatedAt, out var dt) ? dt : DateTimeOffset.UtcNow
            )))
            .ToList();
    }
}

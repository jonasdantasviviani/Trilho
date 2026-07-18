using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Net.Http.Json;
using System.Text.Json;

namespace Trilho.Infrastructure.Services;

public interface IAbacatePayService
{
    /// <summary>
    /// Creates a PIX charge via AbacatePay Transparent Checkout (v2).
    /// Returns the QR code data (brCode + brCodeBase64) so the client can
    /// show the PIX QR code in-app without redirecting the user.
    /// </summary>
    Task<AbacatePayTransparentResponse> CreatePixChargeAsync(
        string userId,
        string email,
        string name,
        string? taxId,
        long amountInCents,
        string? description = null,
        CancellationToken ct = default);

    /// <summary>
    /// Checks the payment status of a PIX transparent charge by ID.
    /// </summary>
    Task<AbacatePayPixCheckResponse?> CheckPixPaymentAsync(string pixId, CancellationToken ct = default);
}

public class AbacatePayService : IAbacatePayService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<AbacatePayService> _logger;
    private readonly string _apiKey;
    private readonly string _baseUrl;
    private readonly bool _isEnabled;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true
    };

    public AbacatePayService(
        HttpClient httpClient,
        IConfiguration config,
        ILogger<AbacatePayService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _apiKey = config["AbacatePay:ApiKey"] ?? "";
        _baseUrl = (config["AbacatePay:BaseUrl"] ?? "https://api.abacatepay.com/v2").TrimEnd('/');
        _isEnabled = !string.IsNullOrWhiteSpace(_apiKey);

        if (_isEnabled)
        {
            _httpClient.DefaultRequestHeaders.Clear();
            _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {_apiKey}");
            _httpClient.DefaultRequestHeaders.Add("Accept", "application/json");
        }
        else
        {
            _logger.LogWarning("AbacatePay API key not configured. Payment endpoints will return 503.");
        }
    }

    public async Task<AbacatePayTransparentResponse> CreatePixChargeAsync(
        string userId,
        string email,
        string name,
        string? taxId,
        long amountInCents,
        string? description = null,
        CancellationToken ct = default)
    {
        if (!_isEnabled)
            throw new InvalidOperationException("Serviço de pagamento não configurado. Configure AbacatePay:ApiKey.");

        var payload = new AbacatePayTransparentRequest
        {
            Data = new AbacatePayTransparentRequestData
            {
                Amount = amountInCents,
                Description = description ?? "Trilho Premium",
                ExpiresIn = 3600, // 1 hour
                Customer = new AbacatePayTransparentCustomer
                {
                    Name  = name,
                    Email = email,
                    TaxId = string.IsNullOrWhiteSpace(taxId) ? null : taxId
                }
            }
        };

        var response = await _httpClient.PostAsJsonAsync($"{_baseUrl}/transparents/create", payload, JsonOptions, ct);

        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync(ct);
            _logger.LogError("AbacatePay transparent create failed: {StatusCode} - {Error}", response.StatusCode, error);
            throw new HttpRequestException($"AbacatePay API error: {response.StatusCode} — {error}");
        }

        var result = await response.Content.ReadFromJsonAsync<AbacatePayTransparentResponse>(JsonOptions, ct)
            ?? throw new InvalidOperationException("AbacatePay returned an empty transparent response.");

        _logger.LogInformation("Created PIX charge {PixId} for user {UserId} ({Amount} centavos)",
            result.Data?.Id, userId, amountInCents);

        return result;
    }

    public async Task<AbacatePayPixCheckResponse?> CheckPixPaymentAsync(string pixId, CancellationToken ct = default)
    {
        if (!_isEnabled) return null;

        var response = await _httpClient.GetAsync($"{_baseUrl}/transparents/check?id={pixId}", ct);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("AbacatePay check payment failed for {PixId}: {StatusCode}", pixId, response.StatusCode);
            return null;
        }

        return await response.Content.ReadFromJsonAsync<AbacatePayPixCheckResponse>(JsonOptions, ct);
    }
}

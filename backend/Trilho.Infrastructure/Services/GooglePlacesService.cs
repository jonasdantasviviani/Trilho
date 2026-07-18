using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Trilho.Infrastructure.Services;

// ── Interface ─────────────────────────────────────────────────────────────────

public interface IGooglePlacesService
{
    bool IsEnabled { get; }

    /// <summary>
    /// Searches for the Google Place ID of a transit station by name and GPS coordinates.
    /// Uses the Places API (New) Text Search with a 400 m location bias.
    /// </summary>
    Task<string?> SearchPlaceIdAsync(string stationName, double lat, double lng, CancellationToken ct = default);

    /// <summary>
    /// Returns the current popularity percentage (0–100) for a Place ID.
    /// Maps directly to <c>currentPopularityPercent</c> in the Places API (New).
    /// Returns null if the field is unavailable for this place.
    /// </summary>
    Task<int?> GetCurrentPopularityAsync(string placeId, CancellationToken ct = default);
}

// ── Implementation ────────────────────────────────────────────────────────────

public class GooglePlacesService : IGooglePlacesService
{
    private readonly HttpClient _http;
    private readonly ILogger<GooglePlacesService> _logger;
    private readonly string _apiKey;

    private const string BaseUrl = "https://places.googleapis.com/v1";

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy        = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition      = JsonIgnoreCondition.WhenWritingNull
    };

    public bool IsEnabled => !string.IsNullOrWhiteSpace(_apiKey);

    public GooglePlacesService(
        HttpClient http,
        IConfiguration config,
        ILogger<GooglePlacesService> logger)
    {
        _http   = http;
        _logger = logger;
        _apiKey = config["Google:PlacesApiKey"] ?? "";

        if (!IsEnabled)
            _logger.LogWarning("Google Places API key not configured. GoogleCrowdWorker will be skipped.");
    }

    // ── Text Search → Place ID ──────────────────────────────────────────────

    public async Task<string?> SearchPlaceIdAsync(
        string stationName, double lat, double lng, CancellationToken ct = default)
    {
        if (!IsEnabled) return null;

        var query = $"Estação {stationName} metrô São Paulo";

        var body = new
        {
            textQuery    = query,
            languageCode = "pt-BR",
            locationBias = new
            {
                circle = new
                {
                    center = new { latitude = lat, longitude = lng },
                    radius = 400.0
                }
            }
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrl}/places:searchText")
        {
            Content = new StringContent(JsonSerializer.Serialize(body, JsonOpts), Encoding.UTF8, "application/json")
        };

        request.Headers.Add("X-Goog-Api-Key", _apiKey);
        request.Headers.Add("X-Goog-FieldMask", "places.id,places.displayName");

        try
        {
            var response = await _http.SendAsync(request, ct);

            if (!response.IsSuccessStatusCode)
            {
                var err = await response.Content.ReadAsStringAsync(ct);
                _logger.LogWarning("Places text search failed for '{Query}': {Status} — {Error}", query, response.StatusCode, err);
                return null;
            }

            var result = await response.Content.ReadFromJsonAsync<TextSearchResponse>(JsonOpts, ct);
            var placeId = result?.Places?.FirstOrDefault()?.Id;

            if (placeId is not null)
                _logger.LogDebug("Resolved Place ID for '{Station}': {PlaceId}", stationName, placeId);

            return placeId;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching Place ID for station '{Station}'", stationName);
            return null;
        }
    }

    // ── Get Details → currentPopularityPercent ──────────────────────────────

    public async Task<int?> GetCurrentPopularityAsync(string placeId, CancellationToken ct = default)
    {
        if (!IsEnabled) return null;

        using var request = new HttpRequestMessage(HttpMethod.Get, $"{BaseUrl}/places/{placeId}");
        request.Headers.Add("X-Goog-Api-Key", _apiKey);
        request.Headers.Add("X-Goog-FieldMask", "currentPopularityPercent");

        try
        {
            var response = await _http.SendAsync(request, ct);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogDebug("Get popularity failed for {PlaceId}: {Status}", placeId, response.StatusCode);
                return null;
            }

            var result = await response.Content.ReadFromJsonAsync<PlaceDetailsResponse>(JsonOpts, ct);
            return result?.CurrentPopularityPercent;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting popularity for Place ID {PlaceId}", placeId);
            return null;
        }
    }
}

// ── API response models ───────────────────────────────────────────────────────

internal class TextSearchResponse
{
    public List<PlaceResult>? Places { get; set; }
}

internal class PlaceResult
{
    public string? Id          { get; set; }
    public DisplayName? DisplayName { get; set; }
}

internal class DisplayName
{
    public string? Text { get; set; }
}

internal class PlaceDetailsResponse
{
    public int? CurrentPopularityPercent { get; set; }
}

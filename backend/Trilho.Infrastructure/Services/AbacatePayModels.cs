using System.Text.Json.Serialization;

namespace Trilho.Infrastructure.Services;

// ── v2 Transparent PIX (POST /transparents/create) ────────────────────────────

public class AbacatePayTransparentRequest
{
    [JsonPropertyName("data")]
    public AbacatePayTransparentRequestData Data { get; set; } = new();
}

public class AbacatePayTransparentRequestData
{
    /// <summary>Amount in cents (e.g. 990 = R$9,90).</summary>
    [JsonPropertyName("amount")]
    public long Amount { get; set; }

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    /// <summary>PIX expiry in seconds from now (e.g. 3600 = 1 hour).</summary>
    [JsonPropertyName("expiresIn")]
    public int? ExpiresIn { get; set; }

    [JsonPropertyName("customer")]
    public AbacatePayTransparentCustomer? Customer { get; set; }
}

public class AbacatePayTransparentCustomer
{
    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [JsonPropertyName("email")]
    public string? Email { get; set; }

    [JsonPropertyName("taxId")]
    public string? TaxId { get; set; }

    [JsonPropertyName("cellphone")]
    public string? Cellphone { get; set; }
}

// ── v2 Transparent PIX response ───────────────────────────────────────────────

public class AbacatePayTransparentResponse
{
    [JsonPropertyName("data")]
    public AbacatePayTransparentData? Data { get; set; }

    [JsonPropertyName("error")]
    public object? Error { get; set; }

    [JsonPropertyName("success")]
    public bool Success { get; set; }
}

public class AbacatePayTransparentData
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    /// <summary>PIX copia-e-cola string.</summary>
    [JsonPropertyName("brCode")]
    public string BrCode { get; set; } = string.Empty;

    /// <summary>QR Code image as base64-encoded PNG.</summary>
    [JsonPropertyName("brCodeBase64")]
    public string BrCodeBase64 { get; set; } = string.Empty;

    [JsonPropertyName("amount")]
    public long Amount { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "PENDING";

    [JsonPropertyName("expiresAt")]
    public string? ExpiresAt { get; set; }

    [JsonPropertyName("devMode")]
    public bool DevMode { get; set; }
}

// ── v2 Transparent PIX check (GET /transparents/check?id=) ───────────────────

public class AbacatePayPixCheckResponse
{
    [JsonPropertyName("data")]
    public AbacatePayPixCheckData? Data { get; set; }

    [JsonPropertyName("success")]
    public bool Success { get; set; }
}

public class AbacatePayPixCheckData
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = string.Empty;

    [JsonPropertyName("amount")]
    public long Amount { get; set; }

    [JsonPropertyName("devMode")]
    public bool DevMode { get; set; }
}

// ── v2 Webhook payload ────────────────────────────────────────────────────────

/// <summary>
/// AbacatePay v2 webhook. The <see cref="Event"/> field follows the format
/// "{resource}.{action}" — e.g. "transparent.completed", "checkout.completed".
/// </summary>
public class AbacatePayWebhookPayload
{
    [JsonPropertyName("event")]
    public string Event { get; set; } = string.Empty;

    /// <summary>ID of the affected resource (PIX transparent ID, checkout ID, etc.).</summary>
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = string.Empty;

    [JsonPropertyName("metadata")]
    public Dictionary<string, object>? Metadata { get; set; }

    [JsonPropertyName("timestamp")]
    public long Timestamp { get; set; }
}

// ── Endpoint request DTO ──────────────────────────────────────────────────────

public class CreateBillingRequest
{
    public string Email { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? TaxId { get; set; }
    public long PriceInCents { get; set; }
    public string? Description { get; set; }
}

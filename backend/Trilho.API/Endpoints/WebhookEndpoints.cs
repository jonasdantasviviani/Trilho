using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

/// <summary>
/// Server-to-server webhooks from external payment providers.
/// These endpoints are intentionally unauthenticated (no JWT) — they use
/// their own shared-secret or signature scheme instead.
/// </summary>
public static class WebhookEndpoints
{
    public static IEndpointRouteBuilder MapWebhookEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/webhooks/revenuecat", HandleRevenueCatAsync)
            .WithName("RevenueCatWebhook")
            .AllowAnonymous();

        return app;
    }

    // ── RevenueCat ─────────────────────────────────────────────────────────────

    private static async Task<IResult> HandleRevenueCatAsync(
        HttpRequest request,
        AppDbContext db,
        IConfiguration config,
        CancellationToken ct)
    {
        // ── 1. Verify shared secret ─────────────────────────────────────────────
        // RevenueCat sends the secret as the raw Authorization header value
        // (no "Bearer " prefix).  If the key is not yet configured, we skip
        // verification so local dev still works, but log a warning.
        var expectedSecret = config["RevenueCat:WebhookSecret"];
        if (!string.IsNullOrEmpty(expectedSecret))
        {
            var authHeader = request.Headers["Authorization"].ToString();
            if (authHeader != expectedSecret)
                return Results.Json(new { error = "Unauthorized" }, statusCode: 401);
        }

        // ── 2. Parse body ───────────────────────────────────────────────────────
        var body    = await new StreamReader(request.Body).ReadToEndAsync(ct);
        var payload = JsonSerializer.Deserialize<RcWebhookPayload>(body, JsonOpts);

        if (payload?.Event is null)
            return Results.BadRequest(new { error = "Invalid payload" });

        var ev = payload.Event;

        // Ignore non-premium entitlements (e.g. future add-on purchases)
        var targetsPremium = ev.EntitlementIds is null   // null → assume premium (field is optional)
                          || ev.EntitlementIds.Contains("premium");
        if (!targetsPremium)
            return Results.Ok(new { received = true, skipped = "not premium entitlement" });

        // ── 3. Resolve user ─────────────────────────────────────────────────────
        // The mobile calls Purchases.logIn(userId.toString()) so app_user_id
        // should already be our Guid.  As fallback, check aliases list.
        if (!Guid.TryParse(ev.AppUserId, out var userId))
        {
            var alias = ev.Aliases?.FirstOrDefault(a => Guid.TryParse(a, out _));
            if (alias is null || !Guid.TryParse(alias, out userId))
                return Results.Ok(new { received = true, note = "app_user_id is not a Guid — user not linked" });
        }

        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
        if (user is null)
            return Results.Ok(new { received = true, note = "user not found in DB" });

        // ── 4. Apply event ──────────────────────────────────────────────────────
        var expiresUtc = ev.ExpirationAtMs.HasValue
            ? DateTimeOffset.FromUnixTimeMilliseconds(ev.ExpirationAtMs.Value).UtcDateTime
            : (DateTime?)null;

        switch (ev.Type)
        {
            // Active subscription events
            case "INITIAL_PURCHASE":
            case "RENEWAL":
            case "UNCANCELLATION":
            case "NON_RENEWING_PURCHASE":
                user.IsPremium      = true;
                user.IsPremiumUntil = expiresUtc ?? DateTime.UtcNow.AddMonths(1);
                break;

            // Cancelled but still paid until expiration
            case "CANCELLATION":
                // Keep IsPremium=true until the paid period ends.
                // When it expires, RevenueCat fires an EXPIRATION event.
                if (expiresUtc.HasValue)
                    user.IsPremiumUntil = expiresUtc;
                break;

            // Subscription ended
            case "EXPIRATION":
            case "BILLING_ISSUE":
                user.IsPremium      = false;
                user.IsPremiumUntil = null;
                break;

            // Informational / not actionable
            default:
                return Results.Ok(new { received = true, type = ev.Type, action = "no-op" });
        }

        await db.SaveChangesAsync(ct);
        return Results.Ok(new { received = true, type = ev.Type, userId, isPremium = user.IsPremium });
    }

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
    };
}

// ── Payload models (file-scoped — not exposed outside this file) ──────────────

file record RcWebhookPayload(
    [property: JsonPropertyName("api_version")] string?       ApiVersion,
    [property: JsonPropertyName("event")]       RcEvent?      Event);

file record RcEvent(
    [property: JsonPropertyName("app_user_id")]     string?       AppUserId,
    [property: JsonPropertyName("aliases")]          List<string>? Aliases,
    [property: JsonPropertyName("type")]             string?       Type,
    [property: JsonPropertyName("entitlement_ids")]  List<string>? EntitlementIds,
    [property: JsonPropertyName("expiration_at_ms")] long?         ExpirationAtMs,
    [property: JsonPropertyName("purchased_at_ms")]  long?         PurchasedAtMs,
    [property: JsonPropertyName("product_id")]       string?       ProductId,
    [property: JsonPropertyName("environment")]      string?       Environment);

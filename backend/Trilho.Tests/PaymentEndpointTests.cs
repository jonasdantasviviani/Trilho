using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Trilho.API.DTOs;
using Trilho.API.Endpoints;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;
using Xunit;

public class PaymentEndpointTests(TrilhoTestFactory factory)
    : IClassFixture<TrilhoTestFactory>
{
    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private async Task<(Guid UserId, string Token)> RegisterUserAsync()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsync("/api/auth/register", null);
        res.EnsureSuccessStatusCode();
        var dto = await res.Content.ReadFromJsonAsync<RegisterResponseDto>();
        return (dto!.UserId, dto.Token);
    }

    private async Task<HttpClient> CreateAuthenticatedClientAsync()
    {
        var (_, token) = await RegisterUserAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    /// <summary>Seeds a user so that it has IsPremium=true, allowing subscription operations.</summary>
    private async Task SetUserPremiumAsync(Guid userId, bool isPremium = true)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.FindAsync(userId);
        user!.IsPremium = isPremium;
        user.IsPremiumUntil = isPremium ? DateTime.UtcNow.AddMonths(1) : null;
        await db.SaveChangesAsync();
    }

    /// <summary>
    /// Returns an authenticated client backed by a derived factory that replaces
    /// IAbacatePayService with FakeAbacatePayService (always returns success).
    /// Used by change-plan tests that need a 200 from the payment service.
    /// </summary>
    private async Task<HttpClient> CreateAuthenticatedClientWithFakePaymentAsync()
    {
        var derivedFactory = factory.WithWebHostBuilder(b =>
            b.ConfigureServices(services =>
            {
                services.RemoveAll<IAbacatePayService>();
                services.AddSingleton<IAbacatePayService, FakeAbacatePayService>();
            }));

        var regClient = derivedFactory.CreateClient();
        var regRes = await regClient.PostAsync("/api/auth/register", null);
        regRes.EnsureSuccessStatusCode();
        var dto = await regRes.Content.ReadFromJsonAsync<RegisterResponseDto>();

        var client = derivedFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", dto!.Token);
        return client;
    }

    /// <summary>Sets ActiveBillingId on a user directly in the DB.</summary>
    private async Task SetActiveBillingIdAsync(Guid userId, string billingId)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.FindAsync(userId);
        user!.ActiveBillingId = billingId;
        await db.SaveChangesAsync();
    }

    // -------------------------------------------------------------------------
    // POST /api/payments/create-billing
    // -------------------------------------------------------------------------

    [Fact]
    public async Task CreateBilling_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/payments/create-billing", new
        {
            email = "test@example.com",
            name = "Test User",
            productName = "Trilho Premium",
            productDescription = "Acesso premium mensal",
            priceInCents = 990,
            isSubscription = true
        });
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task CreateBilling_WithAuth_Returns503WhenApiKeyNotConfigured()
    {
        // In test env, AbacatePay:ApiKey is not set → service throws → endpoint returns 503.
        var (_, token) = await RegisterUserAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var res = await client.PostAsJsonAsync("/api/payments/create-billing", new
        {
            email = "test@example.com",
            name = "Test User",
            productName = "Trilho Premium",
            productDescription = "Acesso premium mensal",
            priceInCents = 990,
            isSubscription = true
        });

        Assert.Equal(HttpStatusCode.ServiceUnavailable, res.StatusCode);
    }

    [Fact]
    public async Task CreateBilling_WhenUnconfigured_DoesNotSetActiveBillingId()
    {
        // When service is not configured, 503 is returned and user state is unchanged.
        var (userId, token) = await RegisterUserAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var res = await client.PostAsJsonAsync("/api/payments/create-billing", new
        {
            email = "test@example.com",
            name = "Test User",
            productName = "Trilho Premium",
            productDescription = "Desc",
            priceInCents = 990,
            isSubscription = true
        });

        Assert.Equal(HttpStatusCode.ServiceUnavailable, res.StatusCode);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.FindAsync(userId);
        Assert.Null(user!.ActiveBillingId);
    }

    // -------------------------------------------------------------------------
    // POST /api/payments/webhook
    // -------------------------------------------------------------------------

    [Fact]
    public async Task Webhook_BillingSuccess_SetsUserPremium()
    {
        var (userId, _) = await RegisterUserAsync();

        const string billingId = "bill_test_success_001";
        await SetActiveBillingIdAsync(userId, billingId);

        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/payments/webhook", new
        {
            @event = "billing.success",
            billingId
        });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var updated = await db.Users.FindAsync(userId);
        Assert.True(updated!.IsPremium);
        Assert.NotNull(updated.IsPremiumUntil);
        Assert.True(updated.IsPremiumUntil > DateTime.UtcNow);
        Assert.Null(updated.ActiveBillingId);
    }

    [Fact]
    public async Task Webhook_BillingSuccess_IsPremiumUntilIsApproximatelyOneMonthOut()
    {
        var (userId, _) = await RegisterUserAsync();
        const string billingId = "bill_premium_until_check";
        await SetActiveBillingIdAsync(userId, billingId);

        var before = DateTime.UtcNow;
        var client = factory.CreateClient();
        await client.PostAsJsonAsync("/api/payments/webhook", new
        {
            @event = "billing.success",
            billingId
        });

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var updated = await db.Users.FindAsync(userId);

        var expectedMin = before.AddDays(28);
        var expectedMax = before.AddDays(33);
        Assert.NotNull(updated!.IsPremiumUntil);
        Assert.InRange(updated.IsPremiumUntil!.Value, expectedMin, expectedMax);
    }

    [Fact]
    public async Task Webhook_BillingSuccess_ForUnknownBillingId_ReturnsOkWithoutCrashing()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/payments/webhook", new
        {
            @event = "billing.success",
            billingId = "bill_does_not_exist"
        });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<WebhookAckDto>();
        Assert.True(body!.Received);
    }

    [Fact]
    public async Task Webhook_BillingCanceled_ClearsActiveBillingId()
    {
        var (userId, _) = await RegisterUserAsync();

        const string billingId = "bill_test_cancel_001";
        await SetActiveBillingIdAsync(userId, billingId);

        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/payments/webhook", new
        {
            @event = "billing.canceled",
            billingId
        });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var updated = await db.Users.FindAsync(userId);
        Assert.Null(updated!.ActiveBillingId);
        Assert.False(updated.IsPremium); // canceled must NOT promote to premium
    }

    [Fact]
    public async Task Webhook_BillingCanceled_ForUnknownBillingId_ReturnsOk()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/payments/webhook", new
        {
            @event = "billing.canceled",
            billingId = "bill_unknown_cancel"
        });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var body = await res.Content.ReadFromJsonAsync<WebhookAckDto>();
        Assert.True(body!.Received);
    }

    [Fact]
    public async Task Webhook_UnknownEvent_ReturnsOkReceived()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/payments/webhook", new
        {
            @event = "billing.refunded",
            billingId = "bill_some_id"
        });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var body = await res.Content.ReadFromJsonAsync<WebhookAckDto>();
        Assert.True(body!.Received);
    }

    [Fact]
    public async Task Webhook_EmptyBody_Returns400()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsync(
            "/api/payments/webhook",
            new StringContent("", Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Webhook_MalformedJson_Returns400()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsync(
            "/api/payments/webhook",
            new StringContent("not-json-at-all", Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    // -------------------------------------------------------------------------
    // GET /api/payments/billing/{id}
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetBilling_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.GetAsync("/api/payments/billing/some-billing-id");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task GetBilling_WithAuth_Returns404WhenApiKeyNotConfigured()
    {
        // In test env, AbacatePay:ApiKey is not set → GetBillingAsync returns null → 404.
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.GetAsync("/api/payments/billing/any-billing-id");

        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }

    // -------------------------------------------------------------------------
    // GET /api/subscription/status
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetSubscriptionStatus_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.GetAsync("/api/subscription/status");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task GetSubscriptionStatus_WithAuth_Returns200WithStatusFields()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.GetAsync("/api/subscription/status");

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<SubscriptionStatusDto>();
        Assert.NotNull(body);
        Assert.False(body.IsActive); // new user is not premium
        Assert.NotEmpty(body.PlanName);
        Assert.True(body.PriceInCents > 0);
        Assert.Equal("BRL", body.Currency);
    }

    [Fact]
    public async Task GetSubscriptionStatus_AfterPremiumSet_ReflectsIsPremiumTrue()
    {
        var (userId, token) = await RegisterUserAsync();
        await SetUserPremiumAsync(userId, isPremium: true);

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var res = await client.GetAsync("/api/subscription/status");

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<SubscriptionStatusDto>();
        Assert.NotNull(body);
        Assert.True(body.IsActive);
        Assert.NotNull(body.IsPremiumUntil);
    }

    // -------------------------------------------------------------------------
    // POST /api/subscription/cancel
    // -------------------------------------------------------------------------

    [Fact]
    public async Task CancelSubscription_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsync("/api/subscription/cancel", null);
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task CancelSubscription_WhenNotPremium_Returns400()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.PostAsync("/api/subscription/cancel", null);

        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);

        var body = await res.Content.ReadAsStringAsync();
        Assert.Contains("Usu", body); // "Usuário não possui assinatura ativa"
    }

    [Fact]
    public async Task CancelSubscription_WhenPremium_Returns200WithCancelDetails()
    {
        var (userId, token) = await RegisterUserAsync();
        await SetUserPremiumAsync(userId, isPremium: true);

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var res = await client.PostAsync("/api/subscription/cancel", null);

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.True(body.TryGetProperty("accessUntil", out _));
        Assert.True(body.TryGetProperty("effectiveCancelDate", out _));
    }

    [Fact]
    public async Task CancelSubscription_WhenPremium_SetsSubscriptionCancelledByUser()
    {
        var (userId, token) = await RegisterUserAsync();
        await SetUserPremiumAsync(userId, isPremium: true);

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var res = await client.PostAsync("/api/subscription/cancel", null);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.FindAsync(userId);
        Assert.True(user!.SubscriptionCancelledByUser);
        Assert.NotNull(user.SubscriptionCancelledAt);
    }

    // -------------------------------------------------------------------------
    // POST /api/subscription/reactivate
    // -------------------------------------------------------------------------

    [Fact]
    public async Task ReactivateSubscription_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsync("/api/subscription/reactivate", null);
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task ReactivateSubscription_WhenNotPreviouslyCancelled_Returns400()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.PostAsync("/api/subscription/reactivate", null);

        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);

        var body = await res.Content.ReadAsStringAsync();
        Assert.Contains("cancelada", body); // "Assinatura não foi cancelada anteriormente"
    }

    [Fact]
    public async Task ReactivateSubscription_AfterCancel_Returns200AndClearsFlags()
    {
        var (userId, token) = await RegisterUserAsync();
        await SetUserPremiumAsync(userId, isPremium: true);

        // Seed cancelled state directly so test is self-contained
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var user = await db.Users.FindAsync(userId);
            user!.SubscriptionCancelledByUser = true;
            user.SubscriptionCancelledAt = DateTime.UtcNow.AddDays(-1);
            await db.SaveChangesAsync();
        }

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var res = await client.PostAsync("/api/subscription/reactivate", null);

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());

        using var scope2 = factory.Services.CreateScope();
        var db2 = scope2.ServiceProvider.GetRequiredService<AppDbContext>();
        var updated = await db2.Users.FindAsync(userId);
        Assert.False(updated!.SubscriptionCancelledByUser);
        Assert.Null(updated.SubscriptionCancelledAt);
    }

    // -------------------------------------------------------------------------
    // Cancel → Reactivate full lifecycle
    // -------------------------------------------------------------------------

    [Fact]
    public async Task CancelThenReactivate_FullLifecycle_WorksEndToEnd()
    {
        var (userId, token) = await RegisterUserAsync();
        await SetUserPremiumAsync(userId, isPremium: true);

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Cancel
        var cancelRes = await client.PostAsync("/api/subscription/cancel", null);
        Assert.Equal(HttpStatusCode.OK, cancelRes.StatusCode);

        // Verify cancelled flag
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var u = await db.Users.FindAsync(userId);
            Assert.True(u!.SubscriptionCancelledByUser);
        }

        // Reactivate
        var reactivateRes = await client.PostAsync("/api/subscription/reactivate", null);
        Assert.Equal(HttpStatusCode.OK, reactivateRes.StatusCode);

        // Verify reactivated
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var u = await db.Users.FindAsync(userId);
            Assert.False(u!.SubscriptionCancelledByUser);
            Assert.Null(u.SubscriptionCancelledAt);
        }
    }

    // -------------------------------------------------------------------------
    // POST /api/subscription/change-plan
    // -------------------------------------------------------------------------

    [Fact]
    public async Task ChangePlan_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/subscription/change-plan",
            new { planType = "annual" });
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task ChangePlan_Monthly_Returns200WithMonthlyPrice()
    {
        // Uses FakeAbacatePayService so the endpoint can return 200 with plan details.
        var client = await CreateAuthenticatedClientWithFakePaymentAsync();

        var res = await client.PostAsJsonAsync("/api/subscription/change-plan",
            new { planType = "monthly" });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.Equal(990, body.GetProperty("price").GetInt64());
        Assert.Contains("Mensal", body.GetProperty("planName").GetString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ChangePlan_Annual_Returns200WithAnnualPrice()
    {
        var client = await CreateAuthenticatedClientWithFakePaymentAsync();

        var res = await client.PostAsJsonAsync("/api/subscription/change-plan",
            new { planType = "annual" });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.Equal(9900, body.GetProperty("price").GetInt64());
        Assert.Contains("Anual", body.GetProperty("planName").GetString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ChangePlan_Quarterly_Returns200WithQuarterlyPrice()
    {
        var client = await CreateAuthenticatedClientWithFakePaymentAsync();

        var res = await client.PostAsJsonAsync("/api/subscription/change-plan",
            new { planType = "quarterly" });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.Equal(2490, body.GetProperty("price").GetInt64());
        Assert.Contains("Trimestral", body.GetProperty("planName").GetString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ChangePlan_UnknownPlanType_DefaultsToMonthly()
    {
        var client = await CreateAuthenticatedClientWithFakePaymentAsync();

        var res = await client.PostAsJsonAsync("/api/subscription/change-plan",
            new { planType = "unknown_type" });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        // Default falls through to "monthly"
        Assert.Equal(990, body.GetProperty("price").GetInt64());
    }

    // -------------------------------------------------------------------------
    // GET /api/subscription/history
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetSubscriptionHistory_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.GetAsync("/api/subscription/history");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task GetSubscriptionHistory_WithAuth_Returns200WithSubscriptionsAndTotal()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.GetAsync("/api/subscription/history");

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.TryGetProperty("subscriptions", out var subs));
        Assert.Equal(JsonValueKind.Array, subs.ValueKind);
        Assert.True(body.TryGetProperty("total", out var total));
        Assert.True(total.GetInt32() >= 0);
    }

    [Fact]
    public async Task GetSubscriptionHistory_ReturnedEntries_HaveExpectedShape()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.GetAsync("/api/subscription/history");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        var subs = body.GetProperty("subscriptions");

        // History is populated via webhooks; may be empty in test env. Verify shape if present.
        if (subs.GetArrayLength() > 0)
        {
            var first = subs[0];
            Assert.True(first.TryGetProperty("id", out _));
            Assert.True(first.TryGetProperty("amount", out _));
            Assert.True(first.TryGetProperty("status", out _));
            Assert.True(first.TryGetProperty("description", out _));
        }
    }

    // -------------------------------------------------------------------------
    // Local response DTOs
    // -------------------------------------------------------------------------

    private record BillingResponseDto(
        string BillingId,
        string Url,
        long Amount,
        string Status,
        bool DevMode);

    private record WebhookAckDto(bool Received);
}

/// <summary>
/// Stub IAbacatePayService for endpoint-level tests that need a successful payment response.
/// Always returns a fake billing with DevMode=true so no DB side-effects are applied
/// (the endpoint skips saving ActiveBillingId when DevMode=true).
/// </summary>
public class FakeAbacatePayService : IAbacatePayService
{
    public Task<AbacatePayTransparentResponse> CreatePixChargeAsync(
        string userId, string email, string name, string? taxId,
        long amountInCents, string? description = null, CancellationToken ct = default)
    {
        return Task.FromResult(new AbacatePayTransparentResponse
        {
            Success = true,
            Data = new AbacatePayTransparentData
            {
                Id           = "fake-pix-" + Guid.NewGuid().ToString("N")[..8],
                BrCode       = "fake-brcode",
                BrCodeBase64 = "ZmFrZS1xcg==",
                Amount       = amountInCents,
                Status       = "PENDING",
                DevMode      = true   // causes endpoint to activate premium immediately
            }
        });
    }

    public Task<AbacatePayPixCheckResponse?> CheckPixPaymentAsync(
        string pixId, CancellationToken ct = default)
    {
        return Task.FromResult<AbacatePayPixCheckResponse?>(new AbacatePayPixCheckResponse
        {
            Success = true,
            Data = new AbacatePayPixCheckData
            {
                Id      = pixId,
                Status  = "PAID",
                Amount  = 990,
                DevMode = true
            }
        });
    }
}

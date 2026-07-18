using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;

namespace Trilho.API.Endpoints;

public static class PaymentEndpoints
{
    public static IEndpointRouteBuilder MapPaymentEndpoints(this IEndpointRouteBuilder app)
    {
        // ── PIX charge ─────────────────────────────────────────────────────────
        app.MapPost("/api/payments/create-billing", CreatePixChargeAsync)
            .WithName("CreateBilling")
            .RequireAuthorization();

        app.MapGet("/api/payments/billing/{pixId}", GetPixStatusAsync)
            .WithName("GetBilling")
            .RequireAuthorization();

        // ── Webhook (public — no auth, AbacatePay calls this) ──────────────────
        app.MapPost("/api/payments/webhook", HandleWebhookAsync)
            .WithName("PaymentWebhook")
            .DisableAntiforgery();

        // ── Subscription management ────────────────────────────────────────────
        app.MapGet("/api/subscription/status",           GetSubscriptionStatusAsync)   .WithName("GetSubscriptionStatus")   .RequireAuthorization();
        app.MapPost("/api/subscription/cancel",          CancelSubscriptionAsync)      .WithName("CancelSubscription")      .RequireAuthorization();
        app.MapPost("/api/subscription/reactivate",      ReactivateSubscriptionAsync)  .WithName("ReactivateSubscription")  .RequireAuthorization();
        app.MapPost("/api/subscription/change-plan",     ChangePlanAsync)              .WithName("ChangePlan")              .RequireAuthorization();
        app.MapGet("/api/subscription/history",          GetSubscriptionHistoryAsync)  .WithName("GetSubscriptionHistory")  .RequireAuthorization();

        return app;
    }

    // ── Create PIX charge ──────────────────────────────────────────────────────

    private static async Task<IResult> CreatePixChargeAsync(
        ClaimsPrincipal principal,
        AppDbContext db,
        IAbacatePayService abacatePay,
        CreateBillingRequest request,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound("User not found");

        var taxId = request.TaxId ?? user.TaxId ?? "";

        try
        {
            var result = await abacatePay.CreatePixChargeAsync(
                userId.ToString(),
                request.Email,
                request.Name,
                taxId,
                request.PriceInCents,
                request.Description,
                ct);

            if (result.Data is null)
                return Results.BadRequest(new { error = "Failed to create PIX charge" });

            // Dev mode: activate premium immediately without a real payment
            if (result.Data.DevMode)
            {
                user.IsPremium       = true;
                user.IsPremiumUntil  = DateTime.UtcNow.AddMonths(1);
                await db.SaveChangesAsync(ct);
            }
            else if (!string.IsNullOrEmpty(result.Data.Id))
            {
                // Store pending PIX ID so the webhook can match it to the user
                user.ActiveBillingId = result.Data.Id;
                await db.SaveChangesAsync(ct);
            }

            return Results.Ok(new
            {
                pixId          = result.Data.Id,
                brCode         = result.Data.BrCode,
                brCodeBase64   = result.Data.BrCodeBase64,
                amount         = result.Data.Amount,
                status         = result.Data.Status,
                expiresAt      = result.Data.ExpiresAt,
                devMode        = result.Data.DevMode
            });
        }
        catch (InvalidOperationException ex)
        {
            return Results.Problem(ex.Message, statusCode: 503, title: "Serviço de pagamento indisponível");
        }
        catch (HttpRequestException ex)
        {
            return Results.Problem(ex.Message, statusCode: 502, title: "Erro ao comunicar com o gateway de pagamento");
        }
    }

    // ── Get PIX payment status ─────────────────────────────────────────────────

    private static async Task<IResult> GetPixStatusAsync(
        ClaimsPrincipal principal,
        IAbacatePayService abacatePay,
        string pixId,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var result = await abacatePay.CheckPixPaymentAsync(pixId, ct);

        if (result?.Data is null)
            return Results.NotFound("PIX charge not found");

        return Results.Ok(new
        {
            pixId   = result.Data.Id,
            status  = result.Data.Status,
            amount  = result.Data.Amount,
            devMode = result.Data.DevMode
        });
    }

    // ── Webhook ────────────────────────────────────────────────────────────────

    private static async Task<IResult> HandleWebhookAsync(
        HttpRequest request,
        AppDbContext db,
        CancellationToken ct)
    {
        var payload = await ReadJsonBodyAsync<AbacatePayWebhookPayload>(request, ct);
        if (payload is null)
            return Results.BadRequest(new { error = "Invalid payload" });

        switch (payload.Event)
        {
            // PIX Transparent paid
            case "transparent.completed":
                await HandlePaymentSuccessAsync(db, payload.Id, ct);
                break;

            // PIX Transparent refunded
            case "transparent.refunded":
                await HandlePaymentCancelledAsync(db, payload.Id, ct);
                break;

            // Checkout paid (e.g. if Checkout flow is used in the future)
            case "checkout.completed":
                await HandlePaymentSuccessAsync(db, payload.Id, ct);
                break;

            case "checkout.refunded":
                await HandlePaymentCancelledAsync(db, payload.Id, ct);
                break;
        }

        return Results.Ok(new { received = true });
    }

    private static async Task HandlePaymentSuccessAsync(
        AppDbContext db, string resourceId, CancellationToken ct)
    {
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.ActiveBillingId == resourceId, ct);

        if (user is not null)
        {
            user.IsPremium       = true;
            user.IsPremiumUntil  = DateTime.UtcNow.AddMonths(1);
            user.ActiveBillingId = null;
            await db.SaveChangesAsync(ct);
        }
    }

    private static async Task HandlePaymentCancelledAsync(
        AppDbContext db, string resourceId, CancellationToken ct)
    {
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.ActiveBillingId == resourceId, ct);

        if (user is not null)
        {
            user.ActiveBillingId = null;
            await db.SaveChangesAsync(ct);
        }
    }

    // ── Subscription management ────────────────────────────────────────────────

    private static async Task<IResult> GetSubscriptionStatusAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound("User not found");

        return Results.Ok(new SubscriptionStatusDto
        {
            IsActive        = user.IsPremium,
            IsPremiumUntil  = user.IsPremiumUntil,
            PlanName        = "Trilho Premium Mensal",
            PriceInCents    = 990,
            Currency        = "BRL",
            PaymentMethod   = "PIX",
            AutoRenew       = true,
            CanCancel       = true,
            CanChangePlan   = true,
            NextBillingDate = user.IsPremiumUntil
        });
    }

    private static async Task<IResult> CancelSubscriptionAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound("User not found");

        if (!user.IsPremium)
            return Results.BadRequest(new { error = "Usuário não possui assinatura ativa" });

        user.SubscriptionCancelledAt         = DateTime.UtcNow;
        user.SubscriptionCancelledByUser     = true;
        await db.SaveChangesAsync(ct);

        return Results.Ok(new
        {
            success            = true,
            message            = "Assinatura cancelada. Você ainda tem acesso até " + user.IsPremiumUntil?.ToString("dd/MM/yyyy"),
            accessUntil        = user.IsPremiumUntil,
            effectiveCancelDate = user.IsPremiumUntil
        });
    }

    private static async Task<IResult> ReactivateSubscriptionAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound("User not found");

        if (!user.SubscriptionCancelledByUser)
            return Results.BadRequest(new { error = "Assinatura não foi cancelada anteriormente" });

        user.SubscriptionCancelledAt     = null;
        user.SubscriptionCancelledByUser = false;
        await db.SaveChangesAsync(ct);

        return Results.Ok(new
        {
            success   = true,
            message   = "Assinatura reativada com sucesso!",
            isPremium = user.IsPremium
        });
    }

    private static async Task<IResult> ChangePlanAsync(
        ClaimsPrincipal principal,
        AppDbContext db,
        IAbacatePayService abacatePay,
        ChangePlanRequest request,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound("User not found");

        var newPlan = request.PlanType switch
        {
            "annual"    => (Name: "Trilho Premium Anual",      Price: 9900L,  Months: 12),
            "quarterly" => (Name: "Trilho Premium Trimestral", Price: 2490L,  Months: 3),
            _           => (Name: "Trilho Premium Mensal",     Price: 990L,   Months: 1)
        };

        try
        {
            var result = await abacatePay.CreatePixChargeAsync(
                userId.ToString(),
                user.VipEmail ?? "",
                user.TaxId ?? "",
                user.TaxId,
                newPlan.Price,
                $"Assinatura {newPlan.Name}",
                ct);

            if (result.Data is null)
                return Results.BadRequest(new { error = "Falha ao criar cobrança para troca de plano" });

            return Results.Ok(new
            {
                success      = true,
                planName     = newPlan.Name,
                price        = newPlan.Price,
                pixId        = result.Data.Id,
                brCode       = result.Data.BrCode,
                brCodeBase64 = result.Data.BrCodeBase64,
                devMode      = result.Data.DevMode
            });
        }
        catch (InvalidOperationException ex)
        {
            return Results.Problem(ex.Message, statusCode: 503, title: "Serviço de pagamento indisponível");
        }
        catch (HttpRequestException ex)
        {
            return Results.Problem(ex.Message, statusCode: 502, title: "Erro ao comunicar com o gateway de pagamento");
        }
    }

    private static async Task<IResult> GetSubscriptionHistoryAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        await Task.CompletedTask;
        return Results.Ok(new { subscriptions = Array.Empty<object>(), total = 0 });
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private static Guid GetUserId(ClaimsPrincipal principal)
    {
        var idStr = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(idStr, out var id) ? id : Guid.Empty;
    }

    private static async Task<T?> ReadJsonBodyAsync<T>(HttpRequest request, CancellationToken ct) where T : class
    {
        request.EnableBuffering();
        using var reader = new StreamReader(request.Body, leaveOpen: true);
        var body = await reader.ReadToEndAsync(ct);
        request.Body.Position = 0;
        if (string.IsNullOrEmpty(body)) return null;

        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<T>(body);
        }
        catch
        {
            return null;
        }
    }
}

public class SubscriptionStatusDto
{
    public bool IsActive { get; set; }
    public DateTime? IsPremiumUntil { get; set; }
    public string PlanName { get; set; } = string.Empty;
    public long PriceInCents { get; set; }
    public string Currency { get; set; } = "BRL";
    public string PaymentMethod { get; set; } = string.Empty;
    public bool AutoRenew { get; set; }
    public bool CanCancel { get; set; }
    public bool CanChangePlan { get; set; }
    public DateTime? NextBillingDate { get; set; }
}

public class ChangePlanRequest
{
    public string PlanType { get; set; } = "monthly";
    public string? CouponCode { get; set; }
}

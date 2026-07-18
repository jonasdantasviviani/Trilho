using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

public static class NotificationEndpoints
{
    public static IEndpointRouteBuilder MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/notifications/register-token", RegisterTokenAsync)
            .WithName("RegisterFcmToken")
            .RequireAuthorization();

        app.MapDelete("/api/notifications/token/{token}", UnregisterTokenAsync)
            .WithName("UnregisterFcmToken")
            .RequireAuthorization();

        app.MapGet("/api/notifications/subscriptions", GetSubscriptionsAsync)
            .WithName("GetNotificationSubscriptions")
            .RequireAuthorization();

        app.MapPost("/api/notifications/subscribe/{lineCode}", SubscribeLineAsync)
            .WithName("SubscribeLineNotifications")
            .RequireAuthorization();

        app.MapDelete("/api/notifications/subscribe/{lineCode}", UnsubscribeLineAsync)
            .WithName("UnsubscribeLineNotifications")
            .RequireAuthorization();

        return app;
    }

    private static async Task<IResult> RegisterTokenAsync(
        ClaimsPrincipal principal,
        AppDbContext db,
        RegisterTokenRequest request,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var existing = await db.UserDeviceTokens
            .FirstOrDefaultAsync(t => t.Token == request.Token, ct);

        if (existing != null)
        {
            if (existing.UserId != userId)
            {
                existing.UserId = userId;
                await db.SaveChangesAsync(ct);
            }
            return Results.Ok(new { success = true, message = "Token atualizado" });
        }

        var deviceToken = new Domain.Entities.UserDeviceToken
        {
            UserId = userId,
            Token = request.Token,
            Platform = request.Platform ?? "android",
            CreatedAt = DateTimeOffset.UtcNow,
        };

        db.UserDeviceTokens.Add(deviceToken);
        await db.SaveChangesAsync(ct);

        return Results.Ok(new { success = true, message = "Token registrado" });
    }

    private static async Task<IResult> UnregisterTokenAsync(
        ClaimsPrincipal principal,
        AppDbContext db,
        string token,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var deviceToken = await db.UserDeviceTokens
            .FirstOrDefaultAsync(t => t.Token == token && t.UserId == userId, ct);

        if (deviceToken != null)
        {
            db.UserDeviceTokens.Remove(deviceToken);
            await db.SaveChangesAsync(ct);
        }

        return Results.Ok(new { success = true });
    }

    private static async Task<IResult> GetSubscriptionsAsync(
        ClaimsPrincipal principal,
        AppDbContext db,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var tokens = await db.UserDeviceTokens
            .Where(t => t.UserId == userId)
            .Select(t => new { t.Token, t.Platform, t.CreatedAt })
            .ToListAsync(ct);

        return Results.Ok(new
        {
            devices = tokens,
            total = tokens.Count
        });
    }

    private static async Task<IResult> SubscribeLineAsync(
        ClaimsPrincipal principal,
        AppDbContext db,
        string lineCode,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var topic = $"line_{lineCode.ToLowerInvariant()}";

        return Results.Ok(new
        {
            success = true,
            topic,
            message = $"Inscrito em notificações da linha {lineCode}"
        });
    }

    private static async Task<IResult> UnsubscribeLineAsync(
        ClaimsPrincipal principal,
        AppDbContext db,
        string lineCode,
        CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        return Results.Ok(new
        {
            success = true,
            message = $"Inscrição da linha {lineCode} cancelada"
        });
    }

    private static Guid GetUserId(ClaimsPrincipal principal)
    {
        var idStr = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(idStr, out var id) ? id : Guid.Empty;
    }
}

public class RegisterTokenRequest
{
    public string Token { get; set; } = string.Empty;
    public string? Platform { get; set; }
}

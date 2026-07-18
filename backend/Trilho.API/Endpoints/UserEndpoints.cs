using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Trilho.API.DTOs;
using Trilho.Domain.Entities;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;

namespace Trilho.API.Endpoints;

public static class UserEndpoints
{
    public static IEndpointRouteBuilder MapUserEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost  ("/api/auth/register",         RegisterAsync)      .WithName("Register");
        app.MapPost  ("/api/auth/firebase",         FirebaseAuthAsync)  .WithName("FirebaseAuth");
        app.MapPost  ("/api/auth/social",            MarkSocialAuthAsync).WithName("SocialAuth")    .RequireAuthorization();
        app.MapGet   ("/api/users/me/usage",         GetUsageAsync)      .WithName("GetUsage")      .RequireAuthorization();
        // Premium status is now updated server-side via POST /api/webhooks/revenuecat
        // LGPD Art. 18 — right to erasure
        app.MapDelete("/api/users/me",               DeleteMeAsync)      .WithName("DeleteMe")      .RequireAuthorization();
        return app;
    }

    private static async Task<IResult> RegisterAsync(
        AppDbContext db, IConfiguration config, CancellationToken ct)
    {
        var user = new User();
        db.Users.Add(user);
        await db.SaveChangesAsync(ct);

        var token = GenerateJwt(user.Id, config);
        return Results.Ok(new RegisterResponseDto(user.Id, token));
    }

    private static async Task<IResult> GetUsageAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound();

        if (!user.IsPremium)
            ResetDailyCountIfNeeded(user);

        await db.SaveChangesAsync(ct);

        // Anonymous: 10/day (resets daily). Registered: unlimited basic access + ads.
        int limit = user.IsPremium ? int.MaxValue : user.IsAnonymous ? 10 : int.MaxValue;
        return Results.Ok(new UsageDto(user.DailyQueriesUsed, limit, user.IsPremium, user.IsAnonymous));
    }

    private static async Task<IResult> MarkSocialAuthAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        // Legacy endpoint — superseded by POST /api/auth/firebase which validates the
        // Firebase ID token directly and returns a fresh JWT in one round-trip.
        // Kept for backwards compatibility: marks an existing anonymous user as
        // non-anonymous so they receive freemium daily limits.
        var userId = GetUserId(principal);
        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound();

        user.IsAnonymous = false;
        user.DailyQueriesUsed = 0; // reset counter when upgrading from anonymous
        user.QueriesResetAt = DateOnly.FromDateTime(DateTime.UtcNow);
        await db.SaveChangesAsync(ct);
        return Results.Ok();
    }

    /// <summary>
    /// LGPD Art. 18 — Right to erasure.
    /// Deletes all personal data associated with the authenticated user:
    /// account record, device tokens, user pings, and subscription data.
    /// </summary>
    private static async Task<IResult> DeleteMeAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users
            .Include(u => u.DeviceTokens)
            .FirstOrDefaultAsync(u => u.Id == userId, ct);

        if (user is null) return Results.NotFound();

        // Delete GPS pings (sensitive location data)
        var pings = db.UserPings.Where(p => p.UserId == userId);
        db.UserPings.RemoveRange(pings);

        // Delete push notification tokens
        db.UserDeviceTokens.RemoveRange(user.DeviceTokens);

        // Delete the user account itself (cascades subscription fields)
        db.Users.Remove(user);

        await db.SaveChangesAsync(ct);
        return Results.NoContent();
    }

    private static void ResetDailyCountIfNeeded(User user)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (user.QueriesResetAt < today)
        {
            user.DailyQueriesUsed = 0;
            user.QueriesResetAt   = today;
        }
    }

    private static string GenerateJwt(Guid userId, IConfiguration config)
    {
        var secret = config["Jwt:Secret"]
            ?? throw new InvalidOperationException("Jwt:Secret not configured.");
        var key   = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: "trilho",
            audience: "trilho",
            claims: [new Claim(ClaimTypes.NameIdentifier, userId.ToString())],
            expires: DateTime.UtcNow.AddYears(1),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static async Task<IResult> FirebaseAuthAsync(
        FirebaseAuthRequestDto dto,
        IFirebaseTokenValidator validator,
        AppDbContext db,
        IConfiguration config,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(dto.IdToken))
            return Results.BadRequest(new { error = "idToken is required" });

        var firebaseToken = await validator.ValidateAsync(dto.IdToken, ct);
        if (firebaseToken is null)
            return Results.Unauthorized();

        var email = firebaseToken.Claims.TryGetValue("email", out var e) ? e?.ToString() : null;

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.VipEmail == email, ct);

        if (user is null)
        {
            user = new User { IsAnonymous = false, VipEmail = email };
            db.Users.Add(user);
            await db.SaveChangesAsync(ct);
        }

        var token = GenerateJwtWithClaims(user.Id, user.IsPremium, user.IsVip, email, config);
        return Results.Ok(new FirebaseAuthResponseDto(
            token,
            new FirebaseUserDto(user.Id, email, user.IsPremium, user.IsVip)));
    }

    private static string GenerateJwtWithClaims(
        Guid userId, bool isPremium, bool isVip, string? email, IConfiguration config)
    {
        var secret = config["Jwt:Secret"]
            ?? throw new InvalidOperationException("Jwt:Secret not configured.");
        var key   = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new("isPremium", isPremium.ToString().ToLower()),
            new("isVip",     isVip.ToString().ToLower()),
        };
        if (email is not null) claims.Add(new Claim(ClaimTypes.Email, email));
        var token = new JwtSecurityToken(
            issuer: "trilho", audience: "trilho",
            claims: claims,
            expires: DateTime.UtcNow.AddDays(30),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static Guid GetUserId(ClaimsPrincipal p)
    {
        var id = p.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(id, out var g) ? g : Guid.Empty;
    }
}

using Microsoft.EntityFrameworkCore;
using Trilho.API.DTOs;
using Trilho.Domain.Entities;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;
using Trilho.Infrastructure.Workers;

namespace Trilho.API.Endpoints;

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        // Public admin auth route (no API key required)
        app.MapPost("/api/admin/auth", AdminLoginAsync).WithName("AdminLogin");

        var admin = app.MapGroup("/api/admin").AddEndpointFilter<AdminKeyFilter>();
        admin.MapGet("/users",                  GetUsersAsync)          .WithName("AdminGetUsers");
        admin.MapPatch("/users/{id:guid}/vip",  PatchVipAsync)          .WithName("AdminPatchVip");
        admin.MapGet("/stats/financial",        GetFinancialAsync)      .WithName("AdminGetFinancial");
        admin.MapGet("/stats/operational",      GetOperationalAsync)    .WithName("AdminGetOperational");
        admin.MapGet("/health/sources",         GetSourceHealthAsync)   .WithName("AdminGetSourceHealth");
        admin.MapGet("/gtfs/status",            GetGtfsStatusAsync)     .WithName("AdminGetGtfsStatus");
        admin.MapPost("/gtfs/force-import",     ForceGtfsImportAsync)   .WithName("AdminForceGtfsImport");

        return app;
    }

    private static async Task<IResult> AdminLoginAsync(
        AdminLoginDto dto, AppDbContext db, IConfiguration config, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Password))
            return Results.BadRequest(new { error = "Email and password are required" });

        var admin = await db.AdminUsers
            .FirstOrDefaultAsync(a => a.Email == dto.Email, ct);

        if (admin is null || !BCrypt.Net.BCrypt.Verify(dto.Password, admin.PasswordHash))
            return Results.Unauthorized();

        return Results.Ok(new { email = admin.Email });
    }

    private static async Task<IResult> GetUsersAsync(
        AppDbContext db,
        int page = 1, int size = 20, string? search = null, string? filter = null,
        CancellationToken ct = default)
    {
        var query = db.Users.AsQueryable();

        if (!string.IsNullOrEmpty(search))
            query = query.Where(u => u.VipEmail != null && u.VipEmail.Contains(search));

        if (filter == "premium") query = query.Where(u => u.IsPremium);
        if (filter == "vip")     query = query.Where(u => u.IsVip);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * size).Take(size)
            .Select(u => new AdminUserDto(u.Id, u.IsPremium, u.IsVip, u.VipEmail,
                u.DailyQueriesUsed, u.CreatedAt))
            .ToListAsync(ct);

        return Results.Ok(new AdminUsersPageDto(items, total, page, size));
    }

    private static async Task<IResult> PatchVipAsync(
        Guid id, PatchVipDto dto, AppDbContext db, CancellationToken ct)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == id, ct);
        if (user is null) return Results.NotFound();

        user.IsVip = dto.IsVip;
        user.VipEmail = dto.IsVip ? dto.VipEmail : null;
        await db.SaveChangesAsync(ct);

        return Results.Ok(new { id = user.Id, isVip = user.IsVip, vipEmail = user.VipEmail });
    }

    private static Task<IResult> GetFinancialAsync(CancellationToken ct)
    {
        var stats = new AdminStatsFinancialDto(0m, 0, 0, DateTime.UtcNow.ToString("yyyy-MM"));
        return Task.FromResult(Results.Ok(stats));
    }

    private static async Task<IResult> GetOperationalAsync(
        AppDbContext db, CancellationToken ct)
    {
        var lineStatuses = await db.Lines
            .Include(l => l.StatusHistory.OrderByDescending(s => s.CapturedAt).Take(1))
            .Select(l => new LineDto(
                l.Id, l.Code, l.Name, l.Type.ToString(), l.ColorHex,
                l.StatusHistory.OrderByDescending(s => s.CapturedAt)
                    .Select(s => s.Status.ToString()).FirstOrDefault() ?? "Unknown",
                l.StatusHistory.OrderByDescending(s => s.CapturedAt)
                    .Select(s => s.Message).FirstOrDefault(),
                null))
            .ToListAsync(ct);

        return Results.Ok(new AdminStatsOperationalDto(
            QueriesPerHour: [],
            TopStations: [],
            LineStatuses: lineStatuses,
            ErrorRate: 0.0));
    }

    private static async Task<IResult> GetGtfsStatusAsync(
        GtfsImportWorker gtfsWorker, AppDbContext db, CancellationToken ct)
    {
        var syncFilePath = gtfsWorker.SyncFilePath;
        var sync         = syncFilePath is not null
            ? await GtfsImportWorker.ReadSyncFileAsync(syncFilePath)
            : null;

        // Live counts from DB (in case sync file is missing or was deleted)
        var dbCounts = new
        {
            stops     = await db.GtfsStops.CountAsync(ct),
            routes    = await db.GtfsRoutes.CountAsync(ct),
            trips     = await db.GtfsTrips.CountAsync(ct),
            stopTimes = await db.GtfsStopTimes.CountAsync(ct),
        };

        return Results.Ok(new
        {
            syncedAt        = sync?.SyncedAt,
            source          = sync?.Source,
            fileModifiedAt  = sync?.FileModifiedAt,
            isCurrent       = sync is not null,
            importedCounts  = sync?.Counts,
            dbCounts,
            syncFilePath,
        });
    }

    private static IResult ForceGtfsImportAsync(GtfsImportWorker gtfsWorker)
    {
        // Delete the .sync.json so the next worker cycle re-imports unconditionally.
        var path = gtfsWorker.SyncFilePath;
        if (path is not null && File.Exists(path))
            File.Delete(path);

        return Results.Ok(new { message = "Sync file cleared. Import will run within 10 minutes (or restart the API)." });
    }

    private static IResult GetSourceHealthAsync(DataSourceHealthRegistry registry)
    {
        var sources = registry.GetAll()
            .Select(h => new DataSourceHealthDto(
                h.Source,
                h.Status.ToString(),
                h.AgeLabel,
                h.AgeSeconds,
                h.LastError))
            .OrderBy(h => h.Source)
            .ToList();

        return Results.Ok(new { sources, checkedAt = DateTimeOffset.UtcNow });
    }
}

public class AdminKeyFilter(IConfiguration config) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx, EndpointFilterDelegate next)
    {
        var key = config["AdminApiKey"] ?? "dev-admin-key";
        if (!ctx.HttpContext.Request.Headers.TryGetValue("X-Admin-Key", out var provided)
            || provided != key)
        {
            return Results.Json(new { error = "Forbidden" }, statusCode: 403);
        }
        return await next(ctx);
    }
}

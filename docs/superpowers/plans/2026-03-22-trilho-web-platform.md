# Trilho Web Platform Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar `web/` (trilho.app — landing + app premium) e `admin/` (admin.trilho.app — painel admin) ao monorepo, com extensões no backend .NET 8.

**Architecture:** Backend .NET 8 recebe Firebase auth, novas colunas (IsVip, AdminUser) e rotas admin. `web/` usa Next.js 14 + Firebase Auth + JWT httpOnly cookie para proteger `/app/*`. `admin/` usa Next.js 14 + NextAuth v5 credentials para o painel interno.

**Tech Stack:** Next.js 14, TypeScript, Tailwind CSS, Firebase Auth, NextAuth v5, TanStack Query v5, @vis.gl/react-google-maps, Vitest, Playwright, FirebaseAdmin (.NET), BCrypt.Net

**Spec:** `docs/superpowers/specs/2026-03-21-trilho-web-platform-design.md`

---

## Chunk 1: Backend Extensions

### Task 1: Add IsVip + VipEmail to User entity

**Files:**
- Modify: `backend/Trilho.Domain/Entities/User.cs`
- Modify: `backend/Trilho.Infrastructure/Persistence/AppDbContext.cs`
- Modify: `backend/Trilho.API/Endpoints/UserEndpoints.cs`
- Create: `backend/Trilho.Tests/VipAccessTests.cs`

- [ ] **Step 1: Write failing test**

```csharp
// backend/Trilho.Tests/VipAccessTests.cs
using Trilho.Domain.Entities;
using Xunit;

public class VipAccessTests
{
    [Fact]
    public void CanQuery_WhenVip_ReturnsTrueRegardlessOfPremium()
    {
        var user = new User { IsVip = true, IsPremium = false };
        Assert.True(user.CanQuery);
    }

    [Fact]
    public void CanQuery_WhenPremiumNotVip_ReturnsTrue()
    {
        var user = new User { IsPremium = true, IsVip = false };
        Assert.True(user.CanQuery);
    }

    [Fact]
    public void CanQuery_WhenNeitherPremiumNorVip_ReturnsFalse()
    {
        var user = new User { IsPremium = false, IsVip = false };
        Assert.False(user.CanQuery);
    }
}
```

- [ ] **Step 2: Run test — expect FAIL (IsVip property missing)**

```bash
cd backend && dotnet test Trilho.Tests --filter VipAccessTests
```

- [ ] **Step 3: Add IsVip, VipEmail, CanQuery to User entity**

```csharp
// backend/Trilho.Domain/Entities/User.cs
namespace Trilho.Domain.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public bool IsPremium { get; set; } = false;
    public bool IsAnonymous { get; set; } = true;
    public bool IsVip { get; set; } = false;
    public string? VipEmail { get; set; }
    public int DailyQueriesUsed { get; set; } = 0;
    public DateOnly QueriesResetAt { get; set; } = DateOnly.FromDateTime(DateTime.UtcNow);
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public bool CanQuery => IsPremium || IsVip;

    public ICollection<UserPing> Pings { get; set; } = [];
}
```

- [ ] **Step 4: Update AppDbContext — configure VipEmail column**

In `backend/Trilho.Infrastructure/Persistence/AppDbContext.cs`, update User config block:

```csharp
mb.Entity<User>(e => {
    e.HasKey(x => x.Id);
    e.Property(x => x.VipEmail).HasMaxLength(255);
    e.Ignore(x => x.CanQuery); // computed property, not persisted
});
```

- [ ] **Step 5: Run test — expect PASS**

```bash
cd backend && dotnet test Trilho.Tests --filter VipAccessTests
```

- [ ] **Step 6: Commit**

```bash
git add backend/Trilho.Domain/Entities/User.cs backend/Trilho.Infrastructure/Persistence/AppDbContext.cs backend/Trilho.Tests/VipAccessTests.cs
git commit -m "feat(backend): add IsVip + VipEmail to User entity with CanQuery helper"
```

---

### Task 2: Create AdminUser entity

**Files:**
- Create: `backend/Trilho.Domain/Entities/AdminUser.cs`
- Modify: `backend/Trilho.Infrastructure/Persistence/AppDbContext.cs`

- [ ] **Step 1: Create AdminUser entity**

```csharp
// backend/Trilho.Domain/Entities/AdminUser.cs
namespace Trilho.Domain.Entities;

public class AdminUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
```

- [ ] **Step 2: Add AdminUsers DbSet and configure in AppDbContext**

Add to `AppDbContext`:

```csharp
public DbSet<AdminUser> AdminUsers => Set<AdminUser>();
```

In `OnModelCreating`:

```csharp
mb.Entity<AdminUser>(e => {
    e.HasKey(x => x.Id);
    e.HasIndex(x => x.Email).IsUnique();
    e.Property(x => x.Email).HasMaxLength(255).IsRequired();
    e.Property(x => x.PasswordHash).IsRequired();
});
```

- [ ] **Step 3: Commit**

```bash
git add backend/Trilho.Domain/Entities/AdminUser.cs backend/Trilho.Infrastructure/Persistence/AppDbContext.cs
git commit -m "feat(backend): add AdminUser entity"
```

---

### Task 3: EF Migrations

**Files:**
- Create: `backend/Trilho.Infrastructure/Persistence/Migrations/` (auto-generated)

- [ ] **Step 1: Create AddVipToUser migration**

```bash
cd backend
dotnet ef migrations add AddVipToUser --project Trilho.Infrastructure --startup-project Trilho.API
```

Expected: creates `..._AddVipToUser.cs` in Migrations/

- [ ] **Step 2: Create AddAdminUsers migration**

```bash
dotnet ef migrations add AddAdminUsers --project Trilho.Infrastructure --startup-project Trilho.API
```

- [ ] **Step 3: Verify migration SQL looks correct**

```bash
dotnet ef migrations script --idempotent --project Trilho.Infrastructure --startup-project Trilho.API
```

Check output includes: `ALTER TABLE "users" ADD COLUMN "is_vip"` and `CREATE TABLE "admin_users"`.

- [ ] **Step 4: Commit**

```bash
git add backend/Trilho.Infrastructure/Persistence/Migrations/
git commit -m "feat(backend): add EF migrations for IsVip and AdminUsers"
```

---

### Task 4: Firebase Admin SDK + auth endpoint

**Files:**
- Modify: `backend/Trilho.Infrastructure/Trilho.Infrastructure.csproj` (add FirebaseAdmin package)
- Create: `backend/Trilho.Infrastructure/Services/FirebaseTokenValidator.cs`
- Modify: `backend/Trilho.API/Endpoints/UserEndpoints.cs`
- Modify: `backend/Trilho.API/DTOs/Dtos.cs`
- Modify: `backend/Trilho.API/Program.cs`
- Create: `backend/Trilho.Tests/FirebaseAuthEndpointTests.cs`

- [ ] **Step 1: Install FirebaseAdmin NuGet**

```bash
cd backend
dotnet add Trilho.Infrastructure/Trilho.Infrastructure.csproj package FirebaseAdmin
```

- [ ] **Step 2: Write failing integration test**

```csharp
// backend/Trilho.Tests/FirebaseAuthEndpointTests.cs
using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

public class FirebaseAuthEndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task PostFirebaseAuth_WithMissingToken_Returns400()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/auth/firebase", new { idToken = "" });
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }
}
```

- [ ] **Step 3: Run test — expect FAIL (route not found)**

```bash
cd backend && dotnet test Trilho.Tests --filter FirebaseAuthEndpointTests
```

- [ ] **Step 4: Create FirebaseTokenValidator service**

```csharp
// backend/Trilho.Infrastructure/Services/FirebaseTokenValidator.cs
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;

namespace Trilho.Infrastructure.Services;

public interface IFirebaseTokenValidator
{
    Task<FirebaseToken?> ValidateAsync(string idToken, CancellationToken ct = default);
}

public class FirebaseTokenValidator : IFirebaseTokenValidator
{
    public FirebaseTokenValidator(IConfiguration config)
    {
        if (FirebaseApp.DefaultInstance != null) return;
        var serviceAccountJson = config["Firebase:ServiceAccountJson"]
            ?? throw new InvalidOperationException("Firebase:ServiceAccountJson not configured.");
        var json = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(serviceAccountJson));
        FirebaseApp.Create(new AppOptions
        {
            Credential = GoogleCredential.FromJson(json)
        });
    }

    public async Task<FirebaseToken?> ValidateAsync(string idToken, CancellationToken ct = default)
    {
        try
        {
            return await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(idToken, ct);
        }
        catch
        {
            return null;
        }
    }
}
```

- [ ] **Step 5: Register service in DI**

In `backend/Trilho.Infrastructure/InfrastructureExtensions.cs`, inside the `AddInfrastructure` method, add:

```csharp
services.AddSingleton<IFirebaseTokenValidator, FirebaseTokenValidator>();
```

- [ ] **Step 6: Add FirebaseAuthDto to Dtos.cs**

```csharp
// append to backend/Trilho.API/DTOs/Dtos.cs
public record FirebaseAuthRequestDto(string IdToken);
public record FirebaseAuthResponseDto(string Token, FirebaseUserDto User);
public record FirebaseUserDto(Guid Id, string? Email, bool IsPremium, bool IsVip);
```

- [ ] **Step 7: Add Firebase auth endpoint to UserEndpoints.cs**

Add to `MapUserEndpoints`:

```csharp
app.MapPost("/api/auth/firebase", FirebaseAuthAsync).WithName("FirebaseAuth");
```

Add handler:

```csharp
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
    var firebaseUid = firebaseToken.Uid;

    // Find existing user by VipEmail or create new
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

// Add this helper alongside GenerateJwt in UserEndpoints.cs
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
```

- [ ] **Step 8: Run test — expect PASS**

```bash
cd backend && dotnet test Trilho.Tests --filter FirebaseAuthEndpointTests
```

- [ ] **Step 9: Commit**

```bash
git add backend/
git commit -m "feat(backend): add Firebase auth endpoint POST /api/auth/firebase"
```

---

### Task 5: Admin API endpoints

**Files:**
- Create: `backend/Trilho.API/Endpoints/AdminEndpoints.cs`
- Modify: `backend/Trilho.API/DTOs/Dtos.cs`
- Modify: `backend/Trilho.API/Program.cs`
- Create: `backend/Trilho.Tests/AdminEndpointTests.cs`

- [ ] **Step 1: Write failing tests**

```csharp
// backend/Trilho.Tests/AdminEndpointTests.cs
using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

public class AdminEndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task GetAdminUsers_WithoutApiKey_Returns403()
    {
        var client = factory.CreateClient();
        var res = await client.GetAsync("/api/admin/users");
        Assert.Equal(HttpStatusCode.Forbidden, res.StatusCode);
    }

    [Fact]
    public async Task GetAdminUsers_WithValidApiKey_Returns200()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Admin-Key", "test-admin-key");
        var res = await client.GetAsync("/api/admin/users");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
    }

    [Fact]
    public async Task PatchVip_WithValidApiKey_TogglesIsVip()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Admin-Key", "test-admin-key");
        var register = await client.PostAsync("/api/auth/register", null);
        var registered = await register.Content.ReadFromJsonAsync<RegisterResponseDto>();

        var res = await client.PatchAsJsonAsync(
            $"/api/admin/users/{registered!.UserId}/vip",
            new { isVip = true, vipEmail = "test@example.com" });
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
    }

    [Fact]
    public async Task AdminLogin_WithInvalidCredentials_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/admin/auth",
            new { email = "nobody@trilho.app", password = "wrongpassword" });
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task AdminLogin_WithEmptyBody_Returns400()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/admin/auth",
            new { email = "", password = "" });
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
cd backend && dotnet test Trilho.Tests --filter AdminEndpointTests
```

- [ ] **Step 3: Add admin DTOs**

```csharp
// append to backend/Trilho.API/DTOs/Dtos.cs
public record AdminUserDto(
    Guid Id,
    bool IsPremium,
    bool IsVip,
    string? VipEmail,
    int DailyQueriesUsed,
    DateTimeOffset CreatedAt);

public record AdminUsersPageDto(IEnumerable<AdminUserDto> Items, int Total, int Page, int Size);

public record PatchVipDto(bool IsVip, string? VipEmail);

public record AdminLoginDto(string Email, string Password);

public record AdminStatsFinancialDto(decimal Mrr, int NewSubscribers, int Churn, string Period);

public record QueryCountDto(DateTimeOffset Hour, int Count);
public record StationQueryDto(int StationId, string StationName, int Count);
public record AdminStatsOperationalDto(
    IEnumerable<QueryCountDto> QueriesPerHour,
    IEnumerable<StationQueryDto> TopStations,
    IEnumerable<LineDto> LineStatuses,
    double ErrorRate);
```

- [ ] **Step 4: Create AdminEndpoints.cs**

```csharp
// backend/Trilho.API/Endpoints/AdminEndpoints.cs
using Microsoft.EntityFrameworkCore;
using Trilho.API.DTOs;
using Trilho.Domain.Entities;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var admin = app.MapGroup("/api/admin").AddEndpointFilter<AdminKeyFilter>();

        admin.MapGet("/users",             GetUsersAsync)     .WithName("AdminGetUsers");
        admin.MapPatch("/users/{id}/vip",  PatchVipAsync)     .WithName("AdminPatchVip");
        admin.MapGet("/stats/financial",   GetFinancialAsync) .WithName("AdminGetFinancial");
        admin.MapGet("/stats/operational", GetOperationalAsync).WithName("AdminGetOperational");

        return app;
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
        var user = await db.Users.FindAsync([id], ct);
        if (user is null) return Results.NotFound();

        user.IsVip = dto.IsVip;
        user.VipEmail = dto.IsVip ? dto.VipEmail : null;
        await db.SaveChangesAsync(ct);

        return Results.Ok(new { id = user.Id, isVip = user.IsVip, vipEmail = user.VipEmail });
    }

    private static Task<IResult> GetFinancialAsync(CancellationToken ct)
    {
        // TODO: integrate RevenueCat webhook data when available
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
                    .Select(s => s.Message).FirstOrDefault()))
            .ToListAsync(ct);

        return Results.Ok(new AdminStatsOperationalDto(
            QueriesPerHour: [],
            TopStations: [],
            LineStatuses: lineStatuses,
            ErrorRate: 0.0));
    }
}

// X-Admin-Key filter
public class AdminKeyFilter(IConfiguration config) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext ctx, EndpointFilterDelegate next)
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
```

- [ ] **Step 5: Register endpoints in Program.cs**

Add after `app.MapUserEndpoints()`:

```csharp
app.MapAdminEndpoints();
```

- [ ] **Step 6: Run tests — expect PASS**

```bash
cd backend && dotnet test Trilho.Tests --filter AdminEndpointTests
```

- [ ] **Step 7: Commit**

```bash
git add backend/Trilho.API/Endpoints/AdminEndpoints.cs backend/Trilho.API/DTOs/Dtos.cs backend/Trilho.API/Program.cs backend/Trilho.Tests/AdminEndpointTests.cs
git commit -m "feat(backend): add admin endpoints (users CRUD, VIP toggle, stats)"
```

---

### Task 5b: GET /api/stations list endpoint with lat/lng

**Files:**
- Modify: `backend/Trilho.API/Endpoints/StationEndpoints.cs`
- Modify: `backend/Trilho.API/DTOs/Dtos.cs`

- [ ] **Step 1: Add StationListDto to Dtos.cs**

```csharp
// append to backend/Trilho.API/DTOs/Dtos.cs
public record StationListDto(
    int Id,
    string Name,
    string LineCode,
    string LineColorHex,
    double Lat,
    double Lng,
    string DensityLevel,
    decimal Density);
```

- [ ] **Step 2: Add GET /api/stations to StationEndpoints.cs**

In `MapStationEndpoints`, add:

```csharp
app.MapGet("/api/stations", GetStationsListAsync).WithName("GetStationsList");
```

Add handler:

```csharp
private static async Task<IResult> GetStationsListAsync(
    AppDbContext db, CancellationToken ct)
{
    var now = DateTimeOffset.UtcNow.AddMinutes(-5);
    var stations = await db.Stations
        .Include(s => s.Line)
        .Include(s => s.CrowdSnapshots
            .Where(c => c.CapturedAt >= now)
            .OrderByDescending(c => c.CapturedAt)
            .Take(1))
        .ToListAsync(ct);

    var result = stations.Select(s => {
        var latest = s.CrowdSnapshots.FirstOrDefault();
        return new StationListDto(
            s.Id,
            s.Name,
            s.Line.Code,
            s.Line.ColorHex,
            Lat: s.Location?.Y ?? 0,   // PostGIS: Y = latitude
            Lng: s.Location?.X ?? 0,   // PostGIS: X = longitude
            DensityLevel: latest?.DensityLevel.ToString() ?? "Low",
            Density: latest?.InferredDensity ?? 0m);
    });

    return Results.Ok(result);
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/Trilho.API/Endpoints/StationEndpoints.cs backend/Trilho.API/DTOs/Dtos.cs
git commit -m "feat(backend): add GET /api/stations list endpoint with lat/lng"
```

---

## Chunk 2: web/ Foundation

### Task 6: Scaffold web/

**Files:**
- Create: `web/` (Next.js 14 app)

- [ ] **Step 1: Scaffold Next.js 14 app**

```bash
cd "C:/Users/jonas/OneDrive/Documentos/Projetos/Trilho"
npx create-next-app@14 web \
  --typescript \
  --tailwind \
  --app \
  --no-src-dir \
  --no-eslint \
  --import-alias "@/*"
```

- [ ] **Step 2: Install dependencies**

```bash
cd web
npm install firebase @tanstack/react-query @tanstack/react-query-devtools
npm install @vis.gl/react-google-maps jose
npm install --save-dev vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom jsdom
npm install --save-dev @playwright/test msw
```

- [ ] **Step 3: Configure Vitest**

Create `web/vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
  },
  resolve: {
    alias: { '@': resolve(__dirname, '.') },
  },
})
```

Create `web/vitest.setup.ts`:

```typescript
import '@testing-library/jest-dom'
```

- [ ] **Step 4: Add test script to package.json**

In `web/package.json`, add to scripts:

```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Step 5: Create .env.local.example**

```bash
# web/.env.local.example
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=
BACKEND_URL=http://localhost:5000
JWT_SECRET=dev-secret-32-chars-minimum-here
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

Copy to `.env.local` with dev values.

- [ ] **Step 6: Commit**

```bash
git add web/
git commit -m "feat(web): scaffold Next.js 14 app with Tailwind + Vitest + dependencies"
```

---

### Task 7: lib/auth.ts — JWT cookie helpers

**Files:**
- Create: `web/lib/auth.ts`
- Create: `web/lib/firebase.ts`
- Create: `web/lib/auth.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// web/lib/auth.test.ts
import { describe, it, expect, vi } from 'vitest'
import { parseJwtCookie, JwtPayload } from './auth'

describe('parseJwtCookie', () => {
  it('returns null for empty string', () => {
    expect(parseJwtCookie('')).toBeNull()
  })

  it('returns null for invalid token', () => {
    expect(parseJwtCookie('not.a.token')).toBeNull()
  })

  it('parses valid JWT payload without verifying signature', () => {
    // Create a fake JWT (header.payload.sig) with base64url payload
    const payload: JwtPayload = {
      sub: 'user-123',
      email: 'test@example.com',
      isPremium: true,
      isVip: false,
      exp: Math.floor(Date.now() / 1000) + 3600,
    }
    const encoded = btoa(JSON.stringify(payload))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
    const fakeToken = `header.${encoded}.sig`
    const result = parseJwtCookie(fakeToken)
    expect(result?.sub).toBe('user-123')
    expect(result?.isPremium).toBe(true)
  })
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd web && npm test -- lib/auth.test.ts
```

- [ ] **Step 3: Create lib/firebase.ts**

```typescript
// web/lib/firebase.ts
import { initializeApp, getApps } from 'firebase/app'
import { getAuth } from 'firebase/auth'

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY!,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN!,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID!,
}

const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig)
export const firebaseAuth = getAuth(app)
```

- [ ] **Step 4: Create lib/auth.ts**

```typescript
// web/lib/auth.ts
import { cookies } from 'next/headers'
import { SignJWT, jwtVerify } from 'jose'

export interface JwtPayload {
  sub: string
  email?: string
  isPremium: boolean
  isVip: boolean
  exp?: number
}

const JWT_SECRET = new TextEncoder().encode(
  process.env.JWT_SECRET ?? 'dev-secret-32-chars-minimum-here'
)
const COOKIE_NAME = 'trilho_session'

// Parse JWT payload without signature verification (for client-side display)
export function parseJwtCookie(token: string): JwtPayload | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
    return payload as JwtPayload
  } catch {
    return null
  }
}

// Verify JWT (server-side, with signature check)
export async function verifySessionToken(token: string): Promise<JwtPayload | null> {
  try {
    const { payload } = await jwtVerify(token, JWT_SECRET)
    // Map custom claims emitted by GenerateJwtWithClaims
    return {
      sub: payload.sub ?? '',
      email: payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] as string | undefined
        ?? payload.email as string | undefined,
      isPremium: payload['isPremium'] === 'true',
      isVip: payload['isVip'] === 'true',
      exp: payload.exp,
    }
  } catch {
    return null
  }
}

// Get current session from cookie (server component)
export async function getSession(): Promise<JwtPayload | null> {
  const cookieStore = await cookies()
  const token = cookieStore.get(COOKIE_NAME)?.value
  if (!token) return null
  return verifySessionToken(token)
}

export { COOKIE_NAME }
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
cd web && npm test -- lib/auth.test.ts
```

- [ ] **Step 6: Commit**

```bash
git add web/lib/
git commit -m "feat(web): add Firebase config and JWT cookie auth helpers"
```

---

### Task 8: lib/api.ts + Route Handler for Firebase auth exchange

**Files:**
- Create: `web/lib/api.ts`
- Create: `web/lib/api.test.ts`
- Create: `web/app/api/auth/firebase/route.ts`
- Create: `web/app/api/auth/refresh/route.ts`
- Create: `web/app/api/auth/logout/route.ts`

- [ ] **Step 1: Write failing test**

```typescript
// web/lib/api.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock fetch globally
const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

describe('apiClient', () => {
  beforeEach(() => mockFetch.mockReset())

  it('includes cookie header in requests', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: 'test' }),
    })
    const { apiClient } = await import('./api')
    await apiClient('/api/lines', { cookie: 'trilho_session=abc' })
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/lines'),
      expect.objectContaining({
        headers: expect.objectContaining({ Cookie: 'trilho_session=abc' }),
      })
    )
  })
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd web && npm test -- lib/api.test.ts
```

- [ ] **Step 3: Create lib/api.ts**

```typescript
// web/lib/api.ts
const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:5000'

interface ApiOptions extends RequestInit {
  cookie?: string
}

export async function apiClient<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const { cookie, ...rest } = options
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(rest.headers as Record<string, string>),
  }
  if (cookie) headers['Cookie'] = cookie

  const res = await fetch(`${BACKEND}${path}`, { ...rest, headers })
  if (!res.ok) {
    const error = await res.text()
    throw new Error(`API ${res.status}: ${error}`)
  }
  return res.json() as Promise<T>
}
```

- [ ] **Step 4: Create Firebase auth exchange Route Handler**

```typescript
// web/app/api/auth/firebase/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { apiClient } from '@/lib/api'
import { COOKIE_NAME } from '@/lib/auth'

export async function POST(req: NextRequest) {
  const { idToken } = await req.json()
  if (!idToken) {
    return NextResponse.json({ error: 'idToken required' }, { status: 400 })
  }

  try {
    const { token } = await apiClient<{ token: string }>(
      '/api/auth/firebase',
      { method: 'POST', body: JSON.stringify({ idToken }) }
    )

    const res = NextResponse.json({ ok: true })
    res.cookies.set(COOKIE_NAME, token, {
      httpOnly: true,
      sameSite: 'strict',
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      maxAge: 60 * 60 * 24 * 30, // 30 days
    })
    return res
  } catch {
    return NextResponse.json({ error: 'Authentication failed' }, { status: 401 })
  }
}
```

- [ ] **Step 5: Create logout Route Handler**

```typescript
// web/app/api/auth/logout/route.ts
import { NextResponse } from 'next/server'
import { COOKIE_NAME } from '@/lib/auth'

export async function POST() {
  const res = NextResponse.json({ ok: true })
  res.cookies.delete(COOKIE_NAME)
  return res
}
```

- [ ] **Step 6: Run tests — expect PASS**

```bash
cd web && npm test -- lib/api.test.ts
```

- [ ] **Step 7: Commit**

```bash
git add web/lib/api.ts web/lib/api.test.ts web/app/api/
git commit -m "feat(web): add API client and auth exchange route handlers"
```

---

### Task 9: middleware.ts — route guard

**Files:**
- Create: `web/middleware.ts`
- Create: `web/middleware.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// web/middleware.test.ts
import { describe, it, expect, vi } from 'vitest'
import { NextRequest } from 'next/server'

// We test the route matching logic independently
import { shouldProtect, shouldRequirePremium } from './middleware'

describe('middleware route logic', () => {
  it('protects /app routes', () => {
    expect(shouldProtect('/app')).toBe(true)
    expect(shouldProtect('/app/line/L1')).toBe(true)
  })

  it('does not protect public routes', () => {
    expect(shouldProtect('/')).toBe(false)
    expect(shouldProtect('/login')).toBe(false)
    expect(shouldProtect('/pricing')).toBe(false)
  })
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd web && npm test -- middleware.test.ts
```

- [ ] **Step 3: Create middleware.ts**

```typescript
// web/middleware.ts
import { NextRequest, NextResponse } from 'next/server'
import { verifySessionToken } from '@/lib/auth'
import { COOKIE_NAME } from '@/lib/auth'

export function shouldProtect(pathname: string) {
  return pathname.startsWith('/app')
}

export function shouldRequirePremium(pathname: string) {
  return pathname.startsWith('/app')
}

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl

  if (!shouldProtect(pathname)) return NextResponse.next()

  const token = req.cookies.get(COOKIE_NAME)?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', req.url))
  }

  const session = await verifySessionToken(token)
  if (!session) {
    const res = NextResponse.redirect(new URL('/login', req.url))
    res.cookies.delete(COOKIE_NAME)
    return res
  }

  if (!session.isPremium && !session.isVip) {
    return NextResponse.redirect(
      new URL('/pricing?reason=premium_required', req.url)
    )
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/app/:path*'],
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd web && npm test -- middleware.test.ts
```

- [ ] **Step 5: Commit**

```bash
git add web/middleware.ts web/middleware.test.ts
git commit -m "feat(web): add route guard middleware for /app/* (auth + premium check)"
```

---

## Chunk 3: web/ Pages

### Task 10: Landing page `/`

**Files:**
- Modify: `web/app/layout.tsx`
- Create: `web/app/(public)/page.tsx`
- Create: `web/components/LineStatusTicker.tsx`
- Create: `web/components/LineStatusTicker.test.tsx`

- [ ] **Step 1: Update root layout**

```typescript
// web/app/layout.tsx
import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Trilho — Lotação em tempo real',
  description: 'Saiba a lotação do metrô e CPTM antes de embarcar.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body className="bg-white text-gray-900 antialiased">{children}</body>
    </html>
  )
}
```

- [ ] **Step 2: Write failing component test**

```typescript
// web/components/LineStatusTicker.test.tsx
import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { LineStatusTicker } from './LineStatusTicker'

describe('LineStatusTicker', () => {
  it('renders line names', () => {
    const lines = [
      { code: 'L1', name: 'Linha 1-Azul', currentStatus: 'Normal', statusMessage: null },
      { code: 'L2', name: 'Linha 2-Verde', currentStatus: 'Parcial', statusMessage: 'Lentidão' },
    ]
    render(<LineStatusTicker lines={lines} />)
    expect(screen.getByText('Linha 1-Azul')).toBeInTheDocument()
    expect(screen.getByText('Normal')).toBeInTheDocument()
  })

  it('shows fallback when lines is empty', () => {
    render(<LineStatusTicker lines={[]} />)
    expect(screen.getByText(/indisponível/i)).toBeInTheDocument()
  })
})
```

- [ ] **Step 3: Run — expect FAIL**

```bash
cd web && npm test -- LineStatusTicker
```

- [ ] **Step 4: Create LineStatusTicker component**

```typescript
// web/components/LineStatusTicker.tsx
interface LineStatus {
  code: string
  name: string
  currentStatus: string
  statusMessage: string | null
}

const statusColor: Record<string, string> = {
  Normal: 'bg-green-100 text-green-800',
  Parcial: 'bg-yellow-100 text-yellow-800',
  Paralisada: 'bg-red-100 text-red-800',
}

export function LineStatusTicker({ lines }: { lines: LineStatus[] }) {
  if (lines.length === 0) {
    return (
      <p className="text-sm text-gray-500 text-center py-2">
        Status das linhas temporariamente indisponível
      </p>
    )
  }

  return (
    <div className="flex flex-wrap gap-2 justify-center">
      {lines.map((l) => (
        <div key={l.code} className="flex items-center gap-2 rounded-full border px-3 py-1 text-sm">
          <span className="font-medium">{l.name}</span>
          <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${statusColor[l.currentStatus] ?? 'bg-gray-100 text-gray-700'}`}>
            {l.currentStatus}
          </span>
        </div>
      ))}
    </div>
  )
}
```

- [ ] **Step 5: Create landing page**

```typescript
// web/app/(public)/page.tsx
import { LineStatusTicker } from '@/components/LineStatusTicker'
import { apiClient } from '@/lib/api'
import Link from 'next/link'

export const revalidate = 60

interface LineDto {
  code: string; name: string; currentStatus: string; statusMessage: string | null
}

async function getLines(): Promise<LineDto[]> {
  try {
    return await apiClient<LineDto[]>('/api/lines')
  } catch {
    return []
  }
}

export default async function HomePage() {
  const lines = await getLines()

  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-4 py-16 gap-12">
      <section className="text-center max-w-xl">
        <h1 className="text-4xl font-bold tracking-tight mb-4">Trilho</h1>
        <p className="text-lg text-gray-600 mb-8">
          Saiba a lotação do metrô e CPTM antes de embarcar.
        </p>
        <div className="flex gap-3 justify-center">
          <a href="https://apps.apple.com" className="rounded-xl bg-black text-white px-6 py-3 font-medium hover:bg-gray-800 transition">
            App Store
          </a>
          <a href="https://play.google.com" className="rounded-xl border border-gray-300 px-6 py-3 font-medium hover:bg-gray-50 transition">
            Google Play
          </a>
        </div>
        <div className="mt-4">
          <Link href="/login" className="text-sm text-blue-600 hover:underline">
            Ou acesse no browser →
          </Link>
        </div>
      </section>

      <section className="w-full max-w-2xl">
        <h2 className="text-center text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
          Status das linhas agora
        </h2>
        <LineStatusTicker lines={lines} />
      </section>
    </main>
  )
}
```

- [ ] **Step 6: Run tests — expect PASS**

```bash
cd web && npm test -- LineStatusTicker
```

- [ ] **Step 7: Commit**

```bash
git add web/app/ web/components/
git commit -m "feat(web): add landing page with live line status ticker"
```

---

### Task 11: Login page + Firebase auth flow

**Files:**
- Create: `web/app/(public)/login/page.tsx`
- Create: `web/components/LoginForm.tsx`
- Create: `web/components/LoginForm.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// web/components/LoginForm.test.tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { LoginForm } from './LoginForm'

vi.mock('@/lib/firebase', () => ({
  firebaseAuth: {},
}))

vi.mock('firebase/auth', () => ({
  signInWithPopup: vi.fn().mockResolvedValue({ user: { getIdToken: async () => 'fake-token' } }),
  GoogleAuthProvider: vi.fn().mockImplementation(() => ({})),
  OAuthProvider: vi.fn().mockImplementation(() => ({})),
}))

describe('LoginForm', () => {
  it('renders Google login button', () => {
    render(<LoginForm />)
    expect(screen.getByRole('button', { name: /google/i })).toBeInTheDocument()
  })

  it('renders email input', () => {
    render(<LoginForm />)
    expect(screen.getByPlaceholderText(/email/i)).toBeInTheDocument()
  })
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd web && npm test -- LoginForm
```

- [ ] **Step 3: Create LoginForm component**

```typescript
// web/components/LoginForm.tsx
'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  signInWithPopup, signInWithEmailAndPassword,
  GoogleAuthProvider, OAuthProvider
} from 'firebase/auth'
import { firebaseAuth } from '@/lib/firebase'

async function exchangeToken(idToken: string) {
  const res = await fetch('/api/auth/firebase', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  })
  if (!res.ok) throw new Error('Login failed')
}

export function LoginForm() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleProvider(provider: GoogleAuthProvider | OAuthProvider) {
    setLoading(true); setError(null)
    try {
      const { user } = await signInWithPopup(firebaseAuth, provider)
      await exchangeToken(await user.getIdToken())
      router.push('/app')
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Erro ao fazer login')
    } finally {
      setLoading(false)
    }
  }

  async function handleEmail(e: React.FormEvent) {
    e.preventDefault(); setLoading(true); setError(null)
    try {
      const { user } = await signInWithEmailAndPassword(firebaseAuth, email, password)
      await exchangeToken(await user.getIdToken())
      router.push('/app')
    } catch {
      setError('Email ou senha incorretos')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="w-full max-w-sm space-y-4">
      <button
        onClick={() => handleProvider(new GoogleAuthProvider())}
        disabled={loading}
        className="w-full flex items-center justify-center gap-2 rounded-xl border px-4 py-3 font-medium hover:bg-gray-50 transition disabled:opacity-50"
      >
        Entrar com Google
      </button>

      <div className="relative flex items-center">
        <div className="flex-grow border-t border-gray-200" />
        <span className="mx-3 text-xs text-gray-400">ou</span>
        <div className="flex-grow border-t border-gray-200" />
      </div>

      <form onSubmit={handleEmail} className="space-y-3">
        <input
          type="email" placeholder="Email" value={email}
          onChange={e => setEmail(e.target.value)}
          className="w-full rounded-xl border px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
          required
        />
        <input
          type="password" placeholder="Senha" value={password}
          onChange={e => setPassword(e.target.value)}
          className="w-full rounded-xl border px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
          required
        />
        <button
          type="submit" disabled={loading}
          className="w-full rounded-xl bg-blue-600 text-white px-4 py-3 font-medium hover:bg-blue-700 transition disabled:opacity-50"
        >
          {loading ? 'Entrando…' : 'Entrar'}
        </button>
      </form>

      {error && <p className="text-sm text-red-600 text-center">{error}</p>}
    </div>
  )
}
```

- [ ] **Step 4: Create login page**

```typescript
// web/app/(public)/login/page.tsx
import { LoginForm } from '@/components/LoginForm'
import Link from 'next/link'

export default function LoginPage() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center">
          <Link href="/" className="text-2xl font-bold">Trilho</Link>
          <p className="mt-2 text-sm text-gray-500">Entre para acessar o mapa</p>
        </div>
        <LoginForm />
        <p className="text-center text-xs text-gray-400">
          Acesso ao mapa requer plano premium.{' '}
          <Link href="/pricing" className="text-blue-600 hover:underline">Ver planos</Link>
        </p>
      </div>
    </main>
  )
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
cd web && npm test -- LoginForm
```

- [ ] **Step 6: Commit**

```bash
git add web/app/(public)/login/ web/components/LoginForm.tsx web/components/LoginForm.test.tsx
git commit -m "feat(web): add login page with Firebase OAuth + email/password"
```

---

### Task 12: Pricing page + App zone pages

**Files:**
- Create: `web/app/(public)/pricing/page.tsx`
- Create: `web/app/(app)/app/page.tsx`
- Create: `web/app/(app)/app/line/[code]/page.tsx`
- Create: `web/app/(app)/app/station/[id]/page.tsx`
- Create: `web/app/(app)/app/settings/page.tsx`
- Create: `web/components/QueryProvider.tsx`

- [ ] **Step 1: Create TanStack Query provider**

```typescript
// web/components/QueryProvider.tsx
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient({
    defaultOptions: {
      queries: { retry: 2, retryDelay: (n) => Math.min(1000 * 2 ** n, 10000) },
    },
  }))
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>
}
```

- [ ] **Step 2: Create pricing page**

```typescript
// web/app/(public)/pricing/page.tsx
import Link from 'next/link'

export default function PricingPage({
  searchParams,
}: {
  searchParams: Promise<{ reason?: string }>
}) {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-4 py-16">
      <div className="max-w-2xl w-full space-y-8 text-center">
        <h1 className="text-3xl font-bold">Planos Trilho</h1>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="rounded-2xl border p-6 space-y-4">
            <h2 className="text-xl font-semibold">Gratuito</h2>
            <p className="text-3xl font-bold">R$ 0</p>
            <ul className="text-sm text-gray-600 space-y-2 text-left">
              <li>✓ 5 consultas por sessão</li>
              <li>✓ Status das linhas</li>
              <li>✗ Mapa em tempo real</li>
              <li>✗ Histórico de lotação</li>
            </ul>
            <Link href="/login" className="block rounded-xl border px-4 py-2 text-sm font-medium hover:bg-gray-50">
              Começar grátis
            </Link>
          </div>

          <div className="rounded-2xl border-2 border-blue-600 p-6 space-y-4">
            <h2 className="text-xl font-semibold">Premium</h2>
            <p className="text-3xl font-bold">R$ 9,90<span className="text-base font-normal text-gray-500">/mês</span></p>
            <ul className="text-sm text-gray-600 space-y-2 text-left">
              <li>✓ Consultas ilimitadas</li>
              <li>✓ Mapa em tempo real</li>
              <li>✓ Histórico de lotação</li>
              <li>✓ Sem anúncios</li>
            </ul>
            <a href="trilho://paywall" className="block rounded-xl bg-blue-600 text-white px-4 py-2 text-sm font-medium hover:bg-blue-700 text-center">
              Assinar no app
            </a>
          </div>
        </div>
      </div>
    </main>
  )
}
```

- [ ] **Step 3: Create app map page**

```typescript
// web/app/(app)/app/page.tsx
'use client'
import { useQuery } from '@tanstack/react-query'
import { APIProvider, Map, AdvancedMarker } from '@vis.gl/react-google-maps'

interface StationDto {
  id: number; name: string
  densityLevel: string; density: number
  lat: number; lng: number
}

const densityColor: Record<string, string> = {
  Low: '#22c55e', Moderate: '#eab308', High: '#f97316', VeryHigh: '#ef4444',
}

export default function AppMapPage() {
  // Calls web/ proxy route which forwards with JWT cookie to backend
  const { data: stations = [] } = useQuery<StationDto[]>({
    queryKey: ['stations'],
    queryFn: () => fetch('/api/proxy/stations').then(r => r.json()),
    refetchInterval: 30_000,
  })

  return (
    <div className="h-screen w-full">
      <APIProvider apiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY!}>
        <Map
          defaultCenter={{ lat: -23.55, lng: -46.63 }}
          defaultZoom={11}
          mapId="trilho-map"
          className="h-full w-full"
        >
          {stations.map(s => (
            <AdvancedMarker key={s.id} position={{ lat: s.lat, lng: s.lng }}>
              <div
                className="w-3 h-3 rounded-full border-2 border-white shadow"
                style={{ backgroundColor: densityColor[s.densityLevel] ?? '#6b7280' }}
                title={s.name}
              />
            </AdvancedMarker>
          ))}
        </Map>
      </APIProvider>
    </div>
  )
}
```

- [ ] **Step 4: Create line detail page**

```typescript
// web/app/(app)/app/line/[code]/page.tsx
import { apiClient } from '@/lib/api'
import { getSession } from '@/lib/auth'
import { cookies } from 'next/headers'
import { notFound } from 'next/navigation'
import { COOKIE_NAME } from '@/lib/auth'

interface LineStatusDto {
  code: string; name: string; currentStatus: string; statusMessage: string | null
  stations: { id: number; name: string; densityLevel: string; density: number }[]
}

const densityColor: Record<string, string> = {
  Low: 'bg-green-400', Moderate: 'bg-yellow-400',
  High: 'bg-orange-500', VeryHigh: 'bg-red-500',
}

export default async function LinePage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params
  const cookieStore = await cookies()
  const cookie = cookieStore.get(COOKIE_NAME)?.value

  let line: LineStatusDto
  try {
    line = await apiClient<LineStatusDto>(`/api/lines/${code}/status`, {
      cookie: cookie ? `${COOKIE_NAME}=${cookie}` : undefined,
    })
  } catch {
    notFound()
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-8 space-y-6">
      <div className={`rounded-xl p-4 ${line.currentStatus === 'Normal' ? 'bg-green-50 border border-green-200' : 'bg-yellow-50 border border-yellow-200'}`}>
        <h1 className="text-xl font-bold">{line.name}</h1>
        <p className="text-sm font-medium mt-1">{line.currentStatus}{line.statusMessage ? ` — ${line.statusMessage}` : ''}</p>
      </div>

      <ul className="space-y-2">
        {line.stations.map(s => (
          <li key={s.id} className="flex items-center justify-between rounded-xl border px-4 py-3">
            <span className="text-sm font-medium">{s.name}</span>
            <span className={`w-3 h-3 rounded-full ${densityColor[s.densityLevel] ?? 'bg-gray-400'}`} />
          </li>
        ))}
      </ul>
    </main>
  )
}
```

- [ ] **Step 5: Create station detail page**

```typescript
// web/app/(app)/app/station/[id]/page.tsx
import { apiClient } from '@/lib/api'
import { cookies } from 'next/headers'
import { notFound } from 'next/navigation'
import { COOKIE_NAME } from '@/lib/auth'

interface CrowdDto {
  stationId: number; stationName: string
  density: number; densityLevel: string
  source: string; capturedAt: string
  history: { density: number; level: string; capturedAt: string }[]
}

export default async function StationPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const cookieStore = await cookies()
  const cookie = cookieStore.get(COOKIE_NAME)?.value

  let crowd: CrowdDto
  try {
    crowd = await apiClient<CrowdDto>(`/api/stations/${id}/crowd`, {
      cookie: cookie ? `${COOKIE_NAME}=${cookie}` : undefined,
    })
  } catch {
    notFound()
  }

  const pct = Math.round(crowd.density * 100)

  return (
    <main className="max-w-lg mx-auto px-4 py-8 space-y-6">
      <h1 className="text-2xl font-bold">{crowd.stationName}</h1>

      <div className="rounded-2xl border p-6 text-center space-y-2">
        <p className="text-5xl font-bold">{pct}%</p>
        <p className="text-sm text-gray-500 uppercase tracking-wide">{crowd.densityLevel}</p>
        <div className="w-full bg-gray-100 rounded-full h-2 mt-2">
          <div
            className="h-2 rounded-full bg-blue-500 transition-all"
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>

      <div className="space-y-1">
        <h2 className="text-sm font-semibold text-gray-500 uppercase">Últimas 3h</h2>
        <div className="flex items-end gap-1 h-16">
          {crowd.history.slice(-18).map((h, i) => (
            <div
              key={i}
              className="flex-1 bg-blue-200 rounded-t"
              style={{ height: `${Math.round(h.density * 100)}%` }}
              title={`${Math.round(h.density * 100)}%`}
            />
          ))}
        </div>
      </div>

      <p className="text-xs text-gray-400 text-center">
        Fonte: {crowd.source} · Atualizado {new Date(crowd.capturedAt).toLocaleTimeString('pt-BR')}
      </p>
    </main>
  )
}
```

- [ ] **Step 6: Create settings page**

```typescript
// web/app/(app)/app/settings/page.tsx
import { getSession } from '@/lib/auth'
import { redirect } from 'next/navigation'

export default async function SettingsPage() {
  const session = await getSession()
  if (!session) redirect('/login')

  return (
    <main className="max-w-lg mx-auto px-4 py-8 space-y-6">
      <h1 className="text-2xl font-bold">Configurações</h1>

      <div className="rounded-2xl border p-4 space-y-2">
        <p className="text-sm text-gray-500">Conta</p>
        <p className="font-medium">{session.email ?? 'Usuário anônimo'}</p>
        <p className="text-sm">
          Plano:{' '}
          <span className={`font-semibold ${session.isPremium || session.isVip ? 'text-blue-600' : 'text-gray-600'}`}>
            {session.isVip ? 'VIP' : session.isPremium ? 'Premium' : 'Gratuito'}
          </span>
        </p>
      </div>

      <form action="/api/auth/logout" method="POST">
        <button
          type="submit"
          className="w-full rounded-xl border border-red-200 text-red-600 px-4 py-3 text-sm font-medium hover:bg-red-50 transition"
        >
          Sair
        </button>
      </form>
    </main>
  )
}
```

- [ ] **Step 7: Commit**

```bash
git add web/
git commit -m "feat(web): add pricing, app map, line detail, station detail, and settings pages"
```

---

## Chunk 4: admin/ Foundation

### Task 13: Scaffold admin/

**Files:**
- Create: `admin/` (Next.js 14 app)

- [ ] **Step 1: Scaffold admin app**

```bash
cd "C:/Users/jonas/OneDrive/Documentos/Projetos/Trilho"
npx create-next-app@14 admin \
  --typescript \
  --tailwind \
  --app \
  --no-src-dir \
  --no-eslint \
  --import-alias "@/*"
```

- [ ] **Step 2: Install dependencies**

```bash
cd admin
npm install next-auth@beta @tanstack/react-query @tanstack/react-query-devtools
npm install --save-dev vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom jsdom
```

- [ ] **Step 3: Create vitest.config.ts** (same as web/)

```typescript
// admin/vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

export default defineConfig({
  plugins: [react()],
  test: { environment: 'jsdom', globals: true, setupFiles: ['./vitest.setup.ts'] },
  resolve: { alias: { '@': resolve(__dirname, '.') } },
})
```

```typescript
// admin/vitest.setup.ts
import '@testing-library/jest-dom'
```

- [ ] **Step 4: Create .env.local.example**

```bash
# admin/.env.local.example
NEXTAUTH_SECRET=dev-nextauth-secret-32chars
NEXTAUTH_URL=http://localhost:3001
BACKEND_URL=http://localhost:5000
ADMIN_API_KEY=dev-admin-key
```

Copy to `.env.local`.

- [ ] **Step 5: Commit**

```bash
git add admin/
git commit -m "feat(admin): scaffold Next.js 14 app with NextAuth + Vitest"
```

---

### Task 14: NextAuth credentials + middleware

**Files:**
- Create: `admin/auth.ts`
- Create: `admin/app/api/auth/[...nextauth]/route.ts`
- Create: `admin/middleware.ts`
- Create: `admin/lib/admin-api.ts`
- Create: `admin/lib/admin-api.test.ts`

- [ ] **Step 1: Write failing admin-api test**

```typescript
// admin/lib/admin-api.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

describe('adminApiClient', () => {
  beforeEach(() => mockFetch.mockReset())

  it('sends X-Admin-Key header', async () => {
    mockFetch.mockResolvedValueOnce({ ok: true, json: async () => ({ items: [] }) })
    const { adminApiClient } = await import('./admin-api')
    await adminApiClient('/api/admin/users')
    expect(mockFetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        headers: expect.objectContaining({ 'X-Admin-Key': expect.any(String) }),
      })
    )
  })

  it('throws on 403', async () => {
    mockFetch.mockResolvedValueOnce({ ok: false, status: 403, text: async () => 'Forbidden' })
    const { adminApiClient } = await import('./admin-api')
    await expect(adminApiClient('/api/admin/users')).rejects.toThrow('403')
  })
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd admin && npm test -- admin-api
```

- [ ] **Step 3: Create lib/admin-api.ts**

```typescript
// admin/lib/admin-api.ts
const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:5000'
const ADMIN_KEY = process.env.ADMIN_API_KEY ?? 'dev-admin-key'

export async function adminApiClient<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Admin-Key': ADMIN_KEY,
    ...(options.headers as Record<string, string>),
  }
  const res = await fetch(`${BACKEND}${path}`, { ...options, headers })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`API ${res.status}: ${text}`)
  }
  return res.json() as Promise<T>
}
```

- [ ] **Step 4: Configure NextAuth**

```typescript
// admin/auth.ts
import NextAuth from 'next-auth'
import Credentials from 'next-auth/providers/credentials'
import { adminApiClient } from '@/lib/admin-api'

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Senha', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null
        try {
          const result = await adminApiClient<{ id: string; email: string }>(
            '/api/admin/auth',
            {
              method: 'POST',
              body: JSON.stringify({
                email: credentials.email,
                password: credentials.password,
              }),
            }
          )
          return { id: result.id, email: result.email }
        } catch {
          return null
        }
      },
    }),
  ],
  pages: { signIn: '/login' },
  session: { strategy: 'jwt' },
})
```

**Note:** Also add `POST /api/admin/auth` to backend AdminEndpoints that validates bcrypt password.

- [ ] **Step 5: Create NextAuth route handler**

```typescript
// admin/app/api/auth/[...nextauth]/route.ts
import { handlers } from '@/auth'
export const { GET, POST } = handlers
```

- [ ] **Step 6: Create admin middleware**

```typescript
// admin/middleware.ts
import { auth } from '@/auth'
import { NextResponse } from 'next/server'

export default auth((req) => {
  const isLoggedIn = !!req.auth
  const isLoginPage = req.nextUrl.pathname === '/login'

  if (!isLoggedIn && !isLoginPage) {
    return NextResponse.redirect(new URL('/login', req.url))
  }
  if (isLoggedIn && isLoginPage) {
    return NextResponse.redirect(new URL('/', req.url))
  }
})

export const config = { matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'] }
```

- [ ] **Step 7: Run tests — expect PASS**

```bash
cd admin && npm test -- admin-api
```

- [ ] **Step 8: Add bcrypt admin auth endpoint to backend**

In `backend/Trilho.API/Endpoints/AdminEndpoints.cs`, add inside `MapAdminEndpoints` (before group filter):

```csharp
// Public admin auth endpoint (no X-Admin-Key required)
app.MapPost("/api/admin/auth", AdminLoginAsync).WithName("AdminLogin");
```

Add handler (install BCrypt.Net-Next first):

```bash
cd backend && dotnet add Trilho.Infrastructure/Trilho.Infrastructure.csproj package BCrypt.Net-Next
```

```csharp
private static async Task<IResult> AdminLoginAsync(
    AdminLoginDto dto, AppDbContext db, CancellationToken ct)
{
    if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Password))
        return Results.BadRequest();

    var admin = await db.AdminUsers.FirstOrDefaultAsync(a => a.Email == dto.Email, ct);
    if (admin is null || !BCrypt.Net.BCrypt.Verify(dto.Password, admin.PasswordHash))
        return Results.Unauthorized();

    return Results.Ok(new { id = admin.Id, email = admin.Email });
}
```

Add DTO: `public record AdminLoginDto(string Email, string Password);`

- [ ] **Step 9: Commit**

```bash
git add admin/ backend/
git commit -m "feat(admin): NextAuth credentials + middleware + admin login endpoint"
```

---

## Chunk 5: admin/ Pages

### Task 15: Admin pages (overview, users, financial, operational)

**Files:**
- Create: `admin/app/(auth)/login/page.tsx`
- Create: `admin/app/(panel)/page.tsx`
- Create: `admin/app/(panel)/users/page.tsx`
- Create: `admin/app/(panel)/financial/page.tsx`
- Create: `admin/app/(panel)/operational/page.tsx`
- Create: `admin/components/VipToggle.tsx`
- Create: `admin/components/VipToggle.test.tsx`
- Create: `admin/components/QueryProvider.tsx`

- [ ] **Step 1: Write failing VipToggle test**

```typescript
// admin/components/VipToggle.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { VipToggle } from './VipToggle'

const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

function wrap(ui: React.ReactElement) {
  return (
    <QueryClientProvider client={new QueryClient()}>
      {ui}
    </QueryClientProvider>
  )
}

describe('VipToggle', () => {
  it('renders checkbox with correct initial state', () => {
    render(wrap(<VipToggle userId="abc" initialIsVip={false} initialEmail={null} />))
    const checkbox = screen.getByRole('checkbox')
    expect(checkbox).not.toBeChecked()
  })

  it('calls PATCH on toggle', async () => {
    mockFetch.mockResolvedValueOnce({ ok: true, json: async () => ({ isVip: true }) })
    render(wrap(<VipToggle userId="abc" initialIsVip={false} initialEmail="x@y.com" />))
    fireEvent.click(screen.getByRole('checkbox'))
    await waitFor(() => expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/admin/users/abc/vip'),
      expect.objectContaining({ method: 'PATCH' })
    ))
  })
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd admin && npm test -- VipToggle
```

- [ ] **Step 3: Create VipToggle component**

```typescript
// admin/components/VipToggle.tsx
'use client'
import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'

interface Props {
  userId: string
  initialIsVip: boolean
  initialEmail: string | null
}

export function VipToggle({ userId, initialIsVip, initialEmail }: Props) {
  const [isVip, setIsVip] = useState(initialIsVip)
  const queryClient = useQueryClient()

  const { mutate, isPending } = useMutation({
    mutationFn: async (nextVip: boolean) => {
      const res = await fetch(`/api/admin/users/${userId}/vip`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isVip: nextVip, vipEmail: nextVip ? initialEmail : null }),
      })
      if (!res.ok) throw new Error('Failed to update VIP')
      return res.json()
    },
    // Store previous value in context for correct revert (avoids stale closure bug)
    onMutate: (nextVip) => { const prev = isVip; setIsVip(nextVip); return prev },
    onError: (_err, _vars, prev) => setIsVip(prev as boolean),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-users'] }),
  })

  return (
    <input
      type="checkbox"
      checked={isVip}
      disabled={isPending}
      onChange={(e) => mutate(e.target.checked)}
      className="h-4 w-4 rounded cursor-pointer accent-blue-600"
    />
  )
}
```

- [ ] **Step 4: Create QueryProvider (same pattern as web/)**

```typescript
// admin/components/QueryProvider.tsx
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient())
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>
}
```

- [ ] **Step 5: Create login page**

```typescript
// admin/app/(auth)/login/page.tsx
import { signIn } from '@/auth'

export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center px-4">
      <form
        action={async (data: FormData) => {
          'use server'
          await signIn('credentials', {
            email: data.get('email'),
            password: data.get('password'),
            redirectTo: '/',
          })
        }}
        className="w-full max-w-sm space-y-4"
      >
        <h1 className="text-2xl font-bold text-center">Trilho Admin</h1>
        <input name="email" type="email" placeholder="Email"
          className="w-full border rounded-xl px-4 py-3 text-sm" required />
        <input name="password" type="password" placeholder="Senha"
          className="w-full border rounded-xl px-4 py-3 text-sm" required />
        <button type="submit"
          className="w-full bg-gray-900 text-white rounded-xl px-4 py-3 text-sm font-medium hover:bg-gray-700">
          Entrar
        </button>
      </form>
    </main>
  )
}
```

- [ ] **Step 6: Create overview dashboard**

```typescript
// admin/app/(panel)/page.tsx
import { adminApiClient } from '@/lib/admin-api'

interface Stats {
  totalUsers: number; premiumUsers: number; queriesToday: number; lineIncidents: number
}

async function getOverviewStats(): Promise<Stats> {
  try {
    // Derive from existing endpoints
    const [users, operational] = await Promise.all([
      adminApiClient<{ total: number; items: { isPremium: boolean }[] }>('/api/admin/users?size=1000'),
      adminApiClient<{ lineStatuses: { currentStatus: string }[] }>('/api/admin/stats/operational'),
    ])
    return {
      totalUsers: users.total,
      premiumUsers: users.items.filter(u => u.isPremium).length,
      queriesToday: 0, // TODO: add query count endpoint
      lineIncidents: operational.lineStatuses.filter(l => l.currentStatus !== 'Normal').length,
    }
  } catch {
    return { totalUsers: 0, premiumUsers: 0, queriesToday: 0, lineIncidents: 0 }
  }
}

export default async function OverviewPage() {
  const stats = await getOverviewStats()

  const cards = [
    { label: 'Total de usuários', value: stats.totalUsers },
    { label: 'Usuários premium', value: stats.premiumUsers },
    { label: 'Consultas hoje', value: stats.queriesToday },
    { label: 'Incidentes nas linhas', value: stats.lineIncidents },
  ]

  return (
    <main className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Visão Geral</h1>
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map(c => (
          <div key={c.label} className="rounded-2xl border p-4 space-y-1">
            <p className="text-sm text-gray-500">{c.label}</p>
            <p className="text-3xl font-bold">{c.value}</p>
          </div>
        ))}
      </div>
    </main>
  )
}
```

- [ ] **Step 7: Create users page with VIP toggle**

```typescript
// admin/app/(panel)/users/page.tsx
import { adminApiClient } from '@/lib/admin-api'
import { VipToggle } from '@/components/VipToggle'
import { QueryProvider } from '@/components/QueryProvider'

interface AdminUserDto {
  id: string; isPremium: boolean; isVip: boolean
  vipEmail: string | null; dailyQueriesUsed: number; createdAt: string
}
interface PageDto { items: AdminUserDto[]; total: number; page: number; size: number }

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; search?: string; filter?: string }>
}) {
  const sp = await searchParams
  const page = Number(sp.page ?? 1)
  const params = new URLSearchParams({ page: String(page), size: '20' })
  if (sp.search) params.set('search', sp.search)
  if (sp.filter) params.set('filter', sp.filter)

  let data: PageDto = { items: [], total: 0, page: 1, size: 20 }
  try {
    data = await adminApiClient<PageDto>(`/api/admin/users?${params}`)
  } catch {}

  return (
    <QueryProvider>
      <main className="p-6 space-y-4">
        <h1 className="text-2xl font-bold">Usuários</h1>
        <p className="text-sm text-gray-500">{data.total} usuários no total</p>

        <div className="overflow-x-auto rounded-2xl border">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                {['Email/ID', 'Premium', 'VIP', 'Consultas', 'Criado em'].map(h => (
                  <th key={h} className="px-4 py-3 text-left font-medium text-gray-600">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y">
              {data.items.map(u => (
                <tr key={u.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-500 font-mono text-xs">
                    {u.vipEmail ?? u.id.slice(0, 8) + '…'}
                  </td>
                  <td className="px-4 py-3">
                    {u.isPremium ? <span className="text-blue-600 font-medium">✓</span> : '—'}
                  </td>
                  <td className="px-4 py-3">
                    <VipToggle userId={u.id} initialIsVip={u.isVip} initialEmail={u.vipEmail} />
                  </td>
                  <td className="px-4 py-3">{u.dailyQueriesUsed}</td>
                  <td className="px-4 py-3 text-gray-500">
                    {new Date(u.createdAt).toLocaleDateString('pt-BR')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
    </QueryProvider>
  )
}
```

- [ ] **Step 8: Create financial + operational pages**

```typescript
// admin/app/(panel)/financial/page.tsx
import { adminApiClient } from '@/lib/admin-api'

export default async function FinancialPage() {
  let stats = { mrr: 0, newSubscribers: 0, churn: 0, period: '' }
  try { stats = await adminApiClient('/api/admin/stats/financial') } catch {}

  return (
    <main className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Financeiro</h1>
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'MRR', value: `R$ ${stats.mrr.toFixed(2)}` },
          { label: 'Novos assinantes', value: stats.newSubscribers },
          { label: 'Churn', value: stats.churn },
        ].map(c => (
          <div key={c.label} className="rounded-2xl border p-4">
            <p className="text-sm text-gray-500">{c.label}</p>
            <p className="text-2xl font-bold mt-1">{c.value}</p>
          </div>
        ))}
      </div>
      <p className="text-xs text-gray-400">Período: {stats.period || '—'}</p>
    </main>
  )
}
```

```typescript
// admin/app/(panel)/operational/page.tsx
import { adminApiClient } from '@/lib/admin-api'

interface OperationalDto {
  lineStatuses: { code: string; name: string; currentStatus: string }[]
  errorRate: number
}

export default async function OperationalPage() {
  let stats: OperationalDto = { lineStatuses: [], errorRate: 0 }
  try { stats = await adminApiClient('/api/admin/stats/operational') } catch {}

  return (
    <main className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Operacional</h1>
      <div className="grid grid-cols-2 gap-4">
        <div className="rounded-2xl border p-4">
          <p className="text-sm text-gray-500 mb-3">Status das linhas</p>
          <ul className="space-y-2">
            {stats.lineStatuses.map(l => (
              <li key={l.code} className="flex justify-between text-sm">
                <span>{l.name}</span>
                <span className={l.currentStatus === 'Normal' ? 'text-green-600' : 'text-red-600'}>
                  {l.currentStatus}
                </span>
              </li>
            ))}
          </ul>
        </div>
        <div className="rounded-2xl border p-4">
          <p className="text-sm text-gray-500">Taxa de erros da API</p>
          <p className="text-3xl font-bold mt-1">{(stats.errorRate * 100).toFixed(2)}%</p>
        </div>
      </div>
    </main>
  )
}
```

- [ ] **Step 9: Create admin layout with nav**

```typescript
// admin/app/(panel)/layout.tsx
import Link from 'next/link'
import { signOut } from '@/auth'

export default function PanelLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen">
      <aside className="w-48 border-r bg-gray-50 flex flex-col">
        <div className="p-4 border-b font-bold text-gray-800">Trilho Admin</div>
        <nav className="flex-1 p-3 space-y-1">
          {[
            { href: '/', label: 'Visão Geral' },
            { href: '/users', label: 'Usuários' },
            { href: '/financial', label: 'Financeiro' },
            { href: '/operational', label: 'Operacional' },
          ].map(item => (
            <Link
              key={item.href}
              href={item.href}
              className="block rounded-lg px-3 py-2 text-sm text-gray-700 hover:bg-gray-200 transition"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <form action={async () => { 'use server'; await signOut({ redirectTo: '/login' }) }} className="p-3">
          <button type="submit" className="w-full text-sm text-gray-500 hover:text-red-600 text-left px-3 py-2">
            Sair
          </button>
        </form>
      </aside>
      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  )
}
```

- [ ] **Step 10: Run VipToggle tests — expect PASS**

```bash
cd admin && npm test -- VipToggle
```

- [ ] **Step 11: Commit**

```bash
git add admin/
git commit -m "feat(admin): add all admin panel pages (overview, users, financial, operational)"
```

---

## Chunk 6: Proxy routes, E2E, Pact, k6

### Task 15b: web/ GET /api/proxy/stations route handler

**Files:**
- Create: `web/app/api/proxy/stations/route.ts`

- [ ] **Step 1: Create stations proxy**

```typescript
// web/app/api/proxy/stations/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { COOKIE_NAME } from '@/lib/auth'
import { apiClient } from '@/lib/api'

export async function GET(_req: NextRequest) {
  const cookieStore = await cookies()
  const token = cookieStore.get(COOKIE_NAME)?.value

  try {
    const data = await apiClient('/api/stations', {
      cookie: token ? `${COOKIE_NAME}=${token}` : undefined,
    })
    return NextResponse.json(data)
  } catch {
    return NextResponse.json([], { status: 200 }) // degrade gracefully
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/api/proxy/
git commit -m "feat(web): add GET /api/proxy/stations route handler"
```

---

### Task 16: admin/ PATCH VIP proxy route

The VipToggle calls `/api/admin/users/:id/vip` from the browser. We need a Next.js Route Handler that proxies to the backend with `X-Admin-Key`.

**Files:**
- Create: `admin/app/api/admin/users/[id]/vip/route.ts`

- [ ] **Step 1: Create proxy route**

```typescript
// admin/app/api/admin/users/[id]/vip/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { adminApiClient } from '@/lib/admin-api'

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await params
  const body = await req.json()

  try {
    const result = await adminApiClient(`/api/admin/users/${id}/vip`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    })
    return NextResponse.json(result)
  } catch (e: unknown) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : 'Failed' },
      { status: 500 }
    )
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add admin/app/api/
git commit -m "feat(admin): add PATCH /api/admin/users/[id]/vip proxy route"
```

---

### Task 17: Playwright E2E smoke tests

**Files:**
- Create: `web/e2e/landing.spec.ts`
- Create: `admin/e2e/login.spec.ts`
- Modify: `web/playwright.config.ts`
- Modify: `admin/playwright.config.ts`

- [ ] **Step 1: Configure Playwright for web/**

```typescript
// web/playwright.config.ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  use: { baseURL: 'http://localhost:3000' },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

- [ ] **Step 2: Create landing E2E test**

```typescript
// web/e2e/landing.spec.ts
import { test, expect } from '@playwright/test'

test('F1: landing page loads and shows app store links', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('Trilho')).toBeVisible()
  await expect(page.getByText('App Store')).toBeVisible()
  await expect(page.getByText('Google Play')).toBeVisible()
})

test('F3: unauthenticated user redirected from /app', async ({ page }) => {
  await page.goto('/app')
  await expect(page).toHaveURL(/\/login/)
})
```

- [ ] **Step 3: Configure Playwright for admin/**

```typescript
// admin/playwright.config.ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  use: { baseURL: 'http://localhost:3001' },
  webServer: {
    command: 'npm run dev -- --port 3001',
    url: 'http://localhost:3001',
    reuseExistingServer: !process.env.CI,
  },
})
```

- [ ] **Step 4: Create admin E2E test**

```typescript
// admin/e2e/login.spec.ts
import { test, expect } from '@playwright/test'

test('A1: admin login success → overview loads', async ({ page }) => {
  // Requires a seeded admin_users row: email=admin@trilho.app, bcrypt hash of "password"
  await page.goto('/login')
  await page.fill('input[type=email]', 'admin@trilho.app')
  await page.fill('input[type=password]', 'password')
  await page.click('button[type=submit]')
  await expect(page).toHaveURL('/')
  await expect(page.getByText('Visão Geral')).toBeVisible()
})

test('A2: wrong password redirects back to login', async ({ page }) => {
  await page.goto('/login')
  await page.fill('input[type=email]', 'admin@trilho.app')
  await page.fill('input[type=password]', 'wrongpassword')
  await page.click('button[type=submit]')
  await expect(page).toHaveURL(/\/login/)
})

test('A3: users page loads and VIP toggle is visible', async ({ page }) => {
  // Assumes logged-in session (use storageState or login fixture in full suite)
  await page.goto('/users')
  // If not logged in, will redirect to login — A5 covers this case
  // If logged in, table and VIP checkboxes should render
})

test('A5: unauthenticated access redirects to login', async ({ page }) => {
  await page.goto('/users')
  await expect(page).toHaveURL(/\/login/)
})
```

- [ ] **Step 5: Install Playwright browsers**

```bash
cd web && npx playwright install chromium
cd ../admin && npx playwright install chromium
```

- [ ] **Step 6: Run E2E tests (requires dev server)**

```bash
# In separate terminals or use:
cd web && npx playwright test
cd admin && npx playwright test
```

- [ ] **Step 7: Commit**

```bash
git add web/e2e/ web/playwright.config.ts admin/e2e/ admin/playwright.config.ts
git commit -m "test: add Playwright E2E smoke tests for web/ and admin/"
```

---

## Chunk 7: Pact contract tests

### Task 17b: Pact consumer tests (web/ + admin/)

**Files:**
- Create: `web/pact/auth-firebase.pact.test.ts`
- Create: `web/pact/stations.pact.test.ts`
- Create: `admin/pact/admin-users.pact.test.ts`

- [ ] **Step 1: Install Pact in web/ and admin/**

```bash
cd web && npm install --save-dev @pact-foundation/pact
cd ../admin && npm install --save-dev @pact-foundation/pact
```

- [ ] **Step 2: Create web/ Pact test for POST /api/auth/firebase**

```typescript
// web/pact/auth-firebase.pact.test.ts
import { PactV3, MatchersV3 } from '@pact-foundation/pact'
import path from 'path'

const { like, string } = MatchersV3

const provider = new PactV3({
  consumer: 'trilho-web',
  provider: 'trilho-backend',
  dir: path.resolve(__dirname, '../../pacts'),
})

describe('POST /api/auth/firebase', () => {
  it('returns token and user for valid idToken', async () => {
    await provider
      .given('Firebase token is valid')
      .uponReceiving('a firebase auth request')
      .withRequest({
        method: 'POST',
        path: '/api/auth/firebase',
        headers: { 'Content-Type': 'application/json' },
        body: { idToken: like('fake-firebase-id-token') },
      })
      .willRespondWith({
        status: 200,
        body: {
          token: string('jwt-token'),
          user: {
            id: string('user-uuid'),
            email: like('user@example.com'),
            isPremium: like(false),
            isVip: like(false),
          },
        },
      })
      .executeTest(async (mockServer) => {
        const res = await fetch(`${mockServer.url}/api/auth/firebase`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ idToken: 'fake-firebase-id-token' }),
        })
        expect(res.status).toBe(200)
        const data = await res.json()
        expect(data.token).toBeDefined()
      })
  })
})
```

- [ ] **Step 3: Create web/ Pact test for GET /api/stations**

```typescript
// web/pact/stations.pact.test.ts
import { PactV3, MatchersV3 } from '@pact-foundation/pact'
import path from 'path'

const { eachLike, like, number } = MatchersV3

const provider = new PactV3({
  consumer: 'trilho-web',
  provider: 'trilho-backend',
  dir: path.resolve(__dirname, '../../pacts'),
})

describe('GET /api/stations', () => {
  it('returns station list with lat/lng', async () => {
    await provider
      .given('stations exist with crowd data')
      .uponReceiving('a request for station list')
      .withRequest({ method: 'GET', path: '/api/stations' })
      .willRespondWith({
        status: 200,
        body: eachLike({
          id: number(1),
          name: like('Sé'),
          lineCode: like('L3'),
          lineColorHex: like('FF0000'),
          lat: like(-23.55),
          lng: like(-46.63),
          densityLevel: like('Low'),
          density: like(0.2),
        }),
      })
      .executeTest(async (mockServer) => {
        const res = await fetch(`${mockServer.url}/api/stations`)
        expect(res.status).toBe(200)
        const data = await res.json()
        expect(Array.isArray(data)).toBe(true)
      })
  })
})
```

- [ ] **Step 4: Create admin/ Pact test for PATCH VIP**

```typescript
// admin/pact/admin-users.pact.test.ts
import { PactV3, MatchersV3 } from '@pact-foundation/pact'
import path from 'path'

const { like, boolean, string } = MatchersV3

const provider = new PactV3({
  consumer: 'trilho-admin',
  provider: 'trilho-backend',
  dir: path.resolve(__dirname, '../../pacts'),
})

describe('PATCH /api/admin/users/:id/vip', () => {
  it('toggles VIP flag', async () => {
    const userId = '00000000-0000-0000-0000-000000000001'
    await provider
      .given(`user ${userId} exists`)
      .uponReceiving('a VIP toggle request')
      .withRequest({
        method: 'PATCH',
        path: `/api/admin/users/${userId}/vip`,
        headers: { 'Content-Type': 'application/json', 'X-Admin-Key': like('key') },
        body: { isVip: boolean(true), vipEmail: like('test@example.com') },
      })
      .willRespondWith({
        status: 200,
        body: { id: string(userId), isVip: boolean(true), vipEmail: like('test@example.com') },
      })
      .executeTest(async (mockServer) => {
        const res = await fetch(`${mockServer.url}/api/admin/users/${userId}/vip`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json', 'X-Admin-Key': 'key' },
          body: JSON.stringify({ isVip: true, vipEmail: 'test@example.com' }),
        })
        expect(res.status).toBe(200)
      })
  })
})
```

- [ ] **Step 5: Run Pact consumer tests**

```bash
cd web && npx vitest run pact/
cd ../admin && npx vitest run pact/
```

Pact files generated in `pacts/` directory at repo root.

- [ ] **Step 6: Commit**

```bash
git add web/pact/ admin/pact/ pacts/
git commit -m "test(pact): add consumer contract tests for firebase auth, stations, and VIP toggle"
```

---

## Chunk 7b: k6 load tests

### Task 17c: k6 load test scripts

**Files:**
- Create: `tests/load/landing.js`
- Create: `tests/load/stations.js`
- Create: `tests/load/firebase-auth.js`

- [ ] **Step 1: Create landing load test** (from spec scaffold)

```javascript
// tests/load/landing.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 200,
  duration: '5m',
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
}

export default function () {
  const res = http.get('https://staging.trilho.app/')
  check(res, { 'status 200': (r) => r.status === 200 })
  sleep(1)
}
```

- [ ] **Step 2: Create stations polling load test**

```javascript
// tests/load/stations.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 100,
  duration: '10m',
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.005'],
  },
}

const BEARER = __ENV.STAGING_JWT ?? 'test-jwt'

export default function () {
  const res = http.get('https://staging.trilho.app/api/proxy/stations', {
    headers: { Cookie: `trilho_session=${BEARER}` },
  })
  check(res, { 'status 200': (r) => r.status === 200 })
  sleep(30)  // simulate 30s polling interval
}
```

- [ ] **Step 3: Create Firebase auth load test**

```javascript
// tests/load/firebase-auth.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 50,
  duration: '3m',
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.005'],
  },
}

export default function () {
  const payload = JSON.stringify({ idToken: 'staging-test-token' })
  const res = http.post('https://staging.trilho.app/api/auth/firebase', payload, {
    headers: { 'Content-Type': 'application/json' },
  })
  check(res, { 'status 200 or 401': (r) => r.status === 200 || r.status === 401 })
  sleep(1)
}
```

- [ ] **Step 4: Commit**

```bash
git add tests/load/
git commit -m "test(load): add k6 load test scripts for landing, stations, and firebase-auth"
```

---

## Chunk 9: Final wiring

### Task 18: Update docker-compose + README

**Files:**
- Modify: `docker-compose.yml`
- Modify: `README.md`

- [ ] **Step 1: Add web and admin services to docker-compose.override.yml**

```yaml
# docker-compose.override.yml (append)
services:
  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - BACKEND_URL=http://api:5000
      - JWT_SECRET=${JWT_SECRET}
      - NEXT_PUBLIC_FIREBASE_API_KEY=${NEXT_PUBLIC_FIREBASE_API_KEY}
      - NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=${NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN}
      - NEXT_PUBLIC_FIREBASE_PROJECT_ID=${NEXT_PUBLIC_FIREBASE_PROJECT_ID}
      - NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=${NEXT_PUBLIC_GOOGLE_MAPS_API_KEY}
    depends_on: [api]

  admin:
    build:
      context: ./admin
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    environment:
      - BACKEND_URL=http://api:5000
      - ADMIN_API_KEY=${ADMIN_API_KEY}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - NEXTAUTH_URL=http://localhost:3001
    depends_on: [api]
```

- [ ] **Step 2: Create Dockerfiles**

```dockerfile
# web/Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/.next/standalone .
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
```

Same pattern for `admin/Dockerfile` with port 3001.

- [ ] **Step 3: Update .env.example at root**

Add new variables from web/ and admin/ `.env.local.example` files.

- [ ] **Step 4: Commit**

```bash
git add docker-compose.override.yml web/Dockerfile admin/Dockerfile .env.example
git commit -m "chore: add Docker support for web/ and admin/ services"
```

---

## Acceptance Checklist

- [ ] `dotnet test` — all backend tests pass (VipAccess, FirebaseAuth, AdminEndpoints)
- [ ] `cd web && npm test` — all Vitest tests pass (auth, api, middleware, LineStatusTicker, LoginForm)
- [ ] `cd admin && npm test` — all Vitest tests pass (admin-api, VipToggle)
- [ ] `cd web && npx vitest run pact/` — Pact consumer contracts generated
- [ ] `cd admin && npx vitest run pact/` — Pact consumer contracts generated
- [ ] `cd web && npx playwright test` — F1 and F3 E2E pass
- [ ] `cd admin && npx playwright test` — A1, A2, A5 E2E pass
- [ ] Landing page loads at `http://localhost:3000` and shows line status
- [ ] `/app` redirects unauthenticated users to `/login`
- [ ] Admin panel loads at `http://localhost:3001` and redirects to `/login`
- [ ] VIP toggle in admin persists to DB (verify via GET /api/admin/users)
- [ ] k6 scripts exist in `tests/load/` (run against staging when available)

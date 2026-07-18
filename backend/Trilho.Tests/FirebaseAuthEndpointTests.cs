using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Moq;
using StackExchange.Redis;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Services;
using Xunit;

public class TrilhoTestFactory : WebApplicationFactory<Program>
{
    // Stable DB name per factory instance — prevents new GUID per scope
    private readonly string _dbName = "TrilhoTestDb_" + Guid.NewGuid();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureAppConfiguration((ctx, cfg) =>
        {
            cfg.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["AdminApiKey"] = "test-admin-key"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Replace Postgres with InMemory
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.RemoveAll<AppDbContext>();
            var dbName = _dbName; // capture for lambda closure
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseInMemoryDatabase(dbName));

            // Replace Redis with a mock
            services.RemoveAll<IConnectionMultiplexer>();
            var redisMock = new Mock<IConnectionMultiplexer>();
            redisMock.Setup(x => x.IsConnected).Returns(false);
            services.AddSingleton(redisMock.Object);

            // Remove background workers
            services.RemoveAll<Microsoft.Extensions.Hosting.IHostedService>();

            // Replace FirebaseTokenValidator with a no-op (always returns null = unauthorized)
            services.RemoveAll<IFirebaseTokenValidator>();
            services.AddSingleton<IFirebaseTokenValidator, NoOpFirebaseTokenValidator>();
        });
    }
}

/// <summary>
/// Always returns null — simulates Firebase SDK not configured or invalid token.
/// </summary>
public class NoOpFirebaseTokenValidator : IFirebaseTokenValidator
{
    public Task<FirebaseAdmin.Auth.FirebaseToken?> ValidateAsync(string idToken, CancellationToken ct = default)
        => Task.FromResult<FirebaseAdmin.Auth.FirebaseToken?>(null);
}

public class FirebaseAuthEndpointTests(TrilhoTestFactory factory)
    : IClassFixture<TrilhoTestFactory>
{
    [Fact]
    public async Task PostFirebaseAuth_WithMissingToken_Returns400()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/auth/firebase", new { idToken = "" });
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }
}

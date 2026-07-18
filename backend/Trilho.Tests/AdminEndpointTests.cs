using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Trilho.API.DTOs;
using Xunit;

public class AdminEndpointTests(TrilhoTestFactory factory)
    : IClassFixture<TrilhoTestFactory>
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

        // Register a user first
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

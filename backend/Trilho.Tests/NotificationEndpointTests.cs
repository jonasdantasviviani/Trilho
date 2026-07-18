using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Trilho.API.DTOs;
using Xunit;

public class NotificationEndpointTests(TrilhoTestFactory factory)
    : IClassFixture<TrilhoTestFactory>
{
    // Helper: register an anonymous user and return (userId, token)
    private async Task<(Guid UserId, string Token)> RegisterUserAsync()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsync("/api/auth/register", null);
        res.EnsureSuccessStatusCode();
        var dto = await res.Content.ReadFromJsonAsync<RegisterResponseDto>();
        return (dto!.UserId, dto.Token);
    }

    // Helper: create an authenticated client
    private async Task<HttpClient> CreateAuthenticatedClientAsync()
    {
        var (_, token) = await RegisterUserAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    // -------------------------------------------------------------------------
    // RegisterToken
    // -------------------------------------------------------------------------

    [Fact]
    public async Task RegisterToken_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/notifications/register-token", new
        {
            token = "fcm-token-no-auth"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task RegisterToken_WithNewToken_Returns200Registered()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.PostAsJsonAsync("/api/notifications/register-token", new
        {
            token = "fcm-new-token-abc123",
            platform = "android"
        });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.Contains("registrado", body.GetProperty("message").GetString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task RegisterToken_WithSameToken_Returns200Updated()
    {
        var client = await CreateAuthenticatedClientAsync();
        const string deviceToken = "fcm-same-token-xyz789";

        // First registration
        var res1 = await client.PostAsJsonAsync("/api/notifications/register-token", new
        {
            token = deviceToken,
            platform = "ios"
        });
        Assert.Equal(HttpStatusCode.OK, res1.StatusCode);

        // Second registration with same token
        var res2 = await client.PostAsJsonAsync("/api/notifications/register-token", new
        {
            token = deviceToken,
            platform = "ios"
        });

        Assert.Equal(HttpStatusCode.OK, res2.StatusCode);

        var body = await res2.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.Contains("atualizado", body.GetProperty("message").GetString(), StringComparison.OrdinalIgnoreCase);
    }

    // -------------------------------------------------------------------------
    // GetSubscriptions
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetSubscriptions_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.GetAsync("/api/notifications/subscriptions");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task GetSubscriptions_AfterRegisterToken_ReturnsDevice()
    {
        var client = await CreateAuthenticatedClientAsync();
        const string deviceToken = "fcm-token-for-subscriptions-test";

        // Register device token
        var registerRes = await client.PostAsJsonAsync("/api/notifications/register-token", new
        {
            token = deviceToken,
            platform = "android"
        });
        Assert.Equal(HttpStatusCode.OK, registerRes.StatusCode);

        // Get subscriptions
        var res = await client.GetAsync("/api/notifications/subscriptions");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, body.GetProperty("total").GetInt32());

        var devices = body.GetProperty("devices");
        Assert.Equal(JsonValueKind.Array, devices.ValueKind);
        Assert.Equal(1, devices.GetArrayLength());

        var firstDevice = devices[0];
        Assert.Equal(deviceToken, firstDevice.GetProperty("token").GetString());
    }

    // -------------------------------------------------------------------------
    // UnregisterToken
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UnregisterToken_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.DeleteAsync("/api/notifications/token/any-fcm-token");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task UnregisterToken_AfterRegistered_Returns200AndRemovesFromSubscriptions()
    {
        var client = await CreateAuthenticatedClientAsync();
        const string deviceToken = "fcm-token-to-unregister";

        // Register token
        var registerRes = await client.PostAsJsonAsync("/api/notifications/register-token", new
        {
            token = deviceToken,
            platform = "android"
        });
        Assert.Equal(HttpStatusCode.OK, registerRes.StatusCode);

        // Unregister token
        var deleteRes = await client.DeleteAsync($"/api/notifications/token/{deviceToken}");
        Assert.Equal(HttpStatusCode.OK, deleteRes.StatusCode);

        var deleteBody = await deleteRes.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(deleteBody.GetProperty("success").GetBoolean());

        // Verify subscriptions are now empty
        var subsRes = await client.GetAsync("/api/notifications/subscriptions");
        Assert.Equal(HttpStatusCode.OK, subsRes.StatusCode);

        var subsBody = await subsRes.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(0, subsBody.GetProperty("total").GetInt32());
    }

    [Fact]
    public async Task UnregisterToken_WhenTokenNotFound_Returns200Idempotent()
    {
        // The endpoint is intentionally idempotent: deleting a non-existent token still returns 200.
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.DeleteAsync("/api/notifications/token/fcm-token-does-not-exist");

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
    }

    // -------------------------------------------------------------------------
    // SubscribeLine / UnsubscribeLine
    // -------------------------------------------------------------------------

    [Fact]
    public async Task SubscribeLine_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.PostAsync("/api/notifications/subscribe/1-AZUL", null);
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task UnsubscribeLine_WithoutAuth_Returns401()
    {
        var client = factory.CreateClient();
        var res = await client.DeleteAsync("/api/notifications/subscribe/1-AZUL");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task SubscribeLine_Returns200WithCorrectTopic()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.PostAsync("/api/notifications/subscribe/1-AZUL", null);

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.Equal("line_1-azul", body.GetProperty("topic").GetString());
        Assert.Contains("1-AZUL", body.GetProperty("message").GetString());
    }

    [Fact]
    public async Task SubscribeLine_TopicIsAlwaysLowercase_EvenWithMixedCaseInput()
    {
        var client = await CreateAuthenticatedClientAsync();

        // Pass a mixed-case lineCode; topic must be fully lowercase
        var res = await client.PostAsync("/api/notifications/subscribe/LINE-ABC", null);

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        var topic = body.GetProperty("topic").GetString();
        Assert.Equal("line_line-abc", topic);
        // topic must contain no uppercase letters
        Assert.Equal(topic, topic!.ToLowerInvariant());
    }

    [Fact]
    public async Task UnsubscribeLine_Returns200WithMessage()
    {
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.DeleteAsync("/api/notifications/subscribe/3-VERDE");

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
        Assert.Contains("3-VERDE", body.GetProperty("message").GetString());
    }

    [Fact]
    public async Task UnsubscribeLine_WhenNotPreviouslySubscribed_Returns200Idempotent()
    {
        // Unsubscribing from a line the user never subscribed to must still return 200.
        var client = await CreateAuthenticatedClientAsync();

        var res = await client.DeleteAsync("/api/notifications/subscribe/9-NEVER-SUBSCRIBED");

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("success").GetBoolean());
    }
}

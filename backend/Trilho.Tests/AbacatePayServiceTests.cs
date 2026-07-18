using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using System.Net;
using Trilho.Infrastructure.Services;
using Xunit;

public class AbacatePayServiceTests
{
    private static IConfiguration BuildConfig(string? apiKey = null, string? baseUrl = null)
    {
        var dict = new Dictionary<string, string?>();
        if (apiKey != null) dict["AbacatePay:ApiKey"] = apiKey;
        if (baseUrl != null) dict["AbacatePay:BaseUrl"] = baseUrl;
        return new ConfigurationBuilder().AddInMemoryCollection(dict).Build();
    }

    // ── No API key → throws (no silent mock) ─────────────────────────────────

    [Fact]
    public async Task CreatePixCharge_WhenApiKeyMissing_ThrowsInvalidOperationException()
    {
        var config = BuildConfig(); // no API key
        var httpClient = new HttpClient();
        var service = new AbacatePayService(httpClient, config, NullLogger<AbacatePayService>.Instance);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreatePixChargeAsync(
                userId: "user1",
                email: "test@example.com",
                name: "Test",
                taxId: "000.000.000-00",
                amountInCents: 990));
    }

    [Fact]
    public async Task CheckPixPayment_WhenApiKeyMissing_ReturnsNull()
    {
        var config = BuildConfig();
        var httpClient = new HttpClient();
        var service = new AbacatePayService(httpClient, config, NullLogger<AbacatePayService>.Instance);

        var result = await service.CheckPixPaymentAsync("any-pix-id");

        Assert.Null(result);
    }

    // ── API key present, API returns error → throws / returns null ────────────

    [Fact]
    public async Task CreatePixCharge_WhenApiReturns500_ThrowsHttpRequestException()
    {
        var handler = new FakeHttpMessageHandler(HttpStatusCode.InternalServerError, "internal error");
        var httpClient = new HttpClient(handler);
        var config = BuildConfig(apiKey: "real-api-key", baseUrl: "http://fake.invalid");
        var service = new AbacatePayService(httpClient, config, NullLogger<AbacatePayService>.Instance);

        await Assert.ThrowsAsync<HttpRequestException>(() =>
            service.CreatePixChargeAsync("u1", "e@e.com", "Name", "000", 990));
    }

    [Fact]
    public async Task CheckPixPayment_WhenApiReturnsNonSuccess_ReturnsNull()
    {
        var handler = new FakeHttpMessageHandler(HttpStatusCode.NotFound, "not found");
        var httpClient = new HttpClient(handler);
        var config = BuildConfig(apiKey: "fake-key", baseUrl: "http://fake.invalid");
        var service = new AbacatePayService(httpClient, config, NullLogger<AbacatePayService>.Instance);

        var result = await service.CheckPixPaymentAsync("missing-id");

        Assert.Null(result);
    }

    [Fact]
    public async Task CheckPixPayment_WhenApiReturns500_ReturnsNull()
    {
        var handler = new FakeHttpMessageHandler(HttpStatusCode.InternalServerError, "server error");
        var httpClient = new HttpClient(handler);
        var config = BuildConfig(apiKey: "fake-key", baseUrl: "http://fake.invalid");
        var service = new AbacatePayService(httpClient, config, NullLogger<AbacatePayService>.Instance);

        var result = await service.CheckPixPaymentAsync("any-id");

        Assert.Null(result);
    }

    // ── API key present → Authorization header is set ─────────────────────────

    [Fact]
    public async Task CreatePixCharge_WhenApiKeyPresent_SendsRequestWithBearerToken()
    {
        HttpRequestMessage? capturedRequest = null;
        var handler = new CapturingHttpMessageHandler(HttpStatusCode.InternalServerError, "error",
            req => capturedRequest = req);
        var httpClient = new HttpClient(handler);
        var config = BuildConfig(apiKey: "my-secret-key", baseUrl: "http://fake.invalid");
        var service = new AbacatePayService(httpClient, config, NullLogger<AbacatePayService>.Instance);

        // Will throw due to 500, but we only care that the request was sent with the right headers.
        await Assert.ThrowsAsync<HttpRequestException>(() =>
            service.CreatePixChargeAsync("u1", "e@e.com", "Name", "000", 100));

        Assert.NotNull(capturedRequest);
        Assert.True(capturedRequest!.Headers.Contains("Authorization"));
        var authHeader = capturedRequest.Headers.GetValues("Authorization").First();
        Assert.StartsWith("Bearer ", authHeader);
        Assert.Contains("my-secret-key", authHeader);
    }
}

/// <summary>Minimal fake HttpMessageHandler for unit tests.</summary>
public class FakeHttpMessageHandler(HttpStatusCode status, string body) : HttpMessageHandler
{
    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        return Task.FromResult(new HttpResponseMessage(status)
        {
            Content = new StringContent(body)
        });
    }
}

/// <summary>Captures the outgoing request for assertion, then returns a configured response.</summary>
public class CapturingHttpMessageHandler(
    HttpStatusCode status,
    string body,
    Action<HttpRequestMessage> onRequest) : HttpMessageHandler
{
    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        onRequest(request);
        return Task.FromResult(new HttpResponseMessage(status)
        {
            Content = new StringContent(body)
        });
    }
}

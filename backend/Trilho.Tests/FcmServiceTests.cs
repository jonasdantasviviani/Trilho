using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Trilho.Infrastructure.Services;
using Xunit;

public class FcmServiceTests
{
    private static IConfiguration EmptyConfig() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>())
            .Build();

    // FcmService.SendNotificationAsync slices token[..8] in the debug log,
    // so any token passed must be at least 8 characters long.
    private const string FakeToken = "fake-token-12345678";

    [Fact]
    public async Task SendNotification_WhenDisabled_ReturnsFalse()
    {
        var service = new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance);

        var result = await service.SendNotificationAsync(
            token: FakeToken,
            title: "Test",
            body: "Test body");

        Assert.False(result);
    }

    [Fact]
    public async Task SendNotification_WhenDisabled_WithData_ReturnsFalse()
    {
        var service = new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance);

        var result = await service.SendNotificationAsync(
            token: FakeToken,
            title: "Alert",
            body: "Something happened",
            data: new Dictionary<string, string> { ["key"] = "value" });

        Assert.False(result);
    }

    [Fact]
    public async Task SendToTopic_WhenDisabled_ReturnsZero()
    {
        var service = new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance);

        var result = await service.SendToTopicAsync("trilho-alerts", "Title", "Body");

        Assert.Equal(0, result);
    }

    [Fact]
    public async Task SendToTopic_WhenDisabled_WithData_ReturnsZero()
    {
        var service = new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance);

        var result = await service.SendToTopicAsync(
            "trilho-alerts", "Title", "Body",
            data: new Dictionary<string, string> { ["type"] = "alert" });

        Assert.Equal(0, result);
    }

    [Fact]
    public async Task SendToUsers_WhenDisabled_ReturnsZero()
    {
        var service = new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance);

        var result = await service.SendToUsersAsync(
            new[] { Guid.NewGuid() }, "Title", "Body");

        Assert.Equal(0, result);
    }

    [Fact]
    public async Task SendToUsers_WhenDisabled_WithMultipleUsers_ReturnsZero()
    {
        var service = new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance);

        var result = await service.SendToUsersAsync(
            new[] { Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid() },
            "Batch Title", "Batch Body");

        Assert.Equal(0, result);
    }

    [Fact]
    public async Task SendToUsers_WhenDisabled_WithEmptyList_ReturnsZero()
    {
        var service = new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance);

        var result = await service.SendToUsersAsync(
            Array.Empty<Guid>(), "Title", "Body");

        Assert.Equal(0, result);
    }

    [Fact]
    public void FcmService_WhenCredentialsPathMissing_DoesNotThrow()
    {
        // Construction should succeed with empty config — no Firebase init attempted
        var exception = Record.Exception(() =>
            new FcmService(EmptyConfig(), NullLogger<FcmService>.Instance));

        Assert.Null(exception);
    }

    [Fact]
    public void FcmService_WhenCredentialsPathIsWhitespace_DoesNotThrow()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Firebase:CredentialsPath"] = "   "
            })
            .Build();

        var exception = Record.Exception(() =>
            new FcmService(config, NullLogger<FcmService>.Instance));

        Assert.Null(exception);
    }
}

using Microsoft.AspNetCore.SignalR;

namespace Trilho.API.Hubs;

public class CrowdHub : Hub
{
    /// <summary>Clients subscribe to receive CrowdUpdated events for a specific line.</summary>
    public async Task SubscribeLine(string lineCode)
        => await Groups.AddToGroupAsync(Context.ConnectionId, $"line:{lineCode}");

    public async Task UnsubscribeLine(string lineCode)
        => await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"line:{lineCode}");
}

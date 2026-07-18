namespace Trilho.Domain.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public bool IsPremium { get; set; } = false;
    public bool IsAnonymous { get; set; } = true;
    public int DailyQueriesUsed { get; set; } = 0;
    public DateOnly QueriesResetAt { get; set; } = DateOnly.FromDateTime(DateTime.UtcNow);
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public bool IsVip { get; set; } = false;
    public string? VipEmail { get; set; }
    public bool CanQuery => IsPremium || IsVip;

    public string? TaxId { get; set; }
    public string? ActiveBillingId { get; set; }
    public DateTime? IsPremiumUntil { get; set; }
    public DateTime? SubscriptionCancelledAt { get; set; }
    public bool SubscriptionCancelledByUser { get; set; } = false;
    public DateTime? SubscriptionStartedAt { get; set; }
    public string? CurrentPaymentMethod { get; set; }

    public ICollection<UserPing> Pings { get; set; } = [];
    public ICollection<UserDeviceToken> DeviceTokens { get; set; } = [];
}

public class UserDeviceToken
{
    public int Id { get; set; }
    public Guid UserId { get; set; }
    public string Token { get; set; } = string.Empty;
    public string Platform { get; set; } = "android";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? LastNotifiedAt { get; set; }
    public User User { get; set; } = null!;
}

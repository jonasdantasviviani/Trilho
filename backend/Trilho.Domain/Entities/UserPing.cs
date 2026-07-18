namespace Trilho.Domain.Entities;

public class UserPing
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public int StationId { get; set; }
    public Station Station { get; set; } = null!;
    /// <summary>GPS latitude — stored for velocity anti-fraud checks.</summary>
    public double Lat { get; set; }
    /// <summary>GPS longitude — stored for velocity anti-fraud checks.</summary>
    public double Lng { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

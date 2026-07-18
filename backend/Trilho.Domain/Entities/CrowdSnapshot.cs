using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class CrowdSnapshot
{
    public long Id { get; set; }
    public int StationId { get; set; }
    public Station Station { get; set; } = null!;
    public int UserCount { get; set; } = 0;
    public decimal InferredDensity { get; set; }   // 0.00–1.00
    public DensityLevel DensityLevel { get; set; }
    public CrowdSource Source { get; set; }
    public DateTimeOffset CapturedAt { get; set; } = DateTimeOffset.UtcNow;
}

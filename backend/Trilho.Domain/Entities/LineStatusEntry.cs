using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class LineStatusEntry
{
    public long Id { get; set; }
    public int LineId { get; set; }
    public Line Line { get; set; } = null!;
    public OperationalStatus Status { get; set; }
    public string? Message { get; set; }
    public string? SourceUrl { get; set; }
    public DateTimeOffset CapturedAt { get; set; } = DateTimeOffset.UtcNow;
}

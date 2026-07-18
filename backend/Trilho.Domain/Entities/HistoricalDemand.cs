using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class HistoricalDemand
{
    public int StationId { get; set; }
    public Station Station { get; set; } = null!;
    public DayType DayType { get; set; }
    public short Hour { get; set; }       // 0–23
    public int AvgPassengers { get; set; }
}

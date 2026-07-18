using NetTopologySuite.Geometries;

namespace Trilho.Domain.Entities;

public class Station
{
    public int Id { get; set; }
    public string? ExternalId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int LineId { get; set; }
    public Line Line { get; set; } = null!;
    public int Sequence { get; set; }
    public Point Location { get; set; } = null!;   // GEOGRAPHY(POINT, 4326)
    public int Capacity { get; set; } = 1000;

    public ICollection<CrowdSnapshot> CrowdSnapshots { get; set; } = [];
    public ICollection<HistoricalDemand> HistoricalDemands { get; set; } = [];
}

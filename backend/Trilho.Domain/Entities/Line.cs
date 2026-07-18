using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class Line
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;      // "1-AZUL", "7-RUBI"
    public string Name { get; set; } = string.Empty;
    public LineType Type { get; set; }
    public string ColorHex { get; set; } = string.Empty;  // 6 chars, no #
    public int HeadwayPeakSec { get; set; } = 180;
    public int HeadwayOffPeakSec { get; set; } = 360;

    public int CityId { get; set; }
    public City City { get; set; } = null!;

    public ICollection<Station> Stations { get; set; } = [];
    public ICollection<LineStatusEntry> StatusHistory { get; set; } = [];
}

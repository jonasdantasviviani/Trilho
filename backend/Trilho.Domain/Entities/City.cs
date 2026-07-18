namespace Trilho.Domain.Entities;

public class City
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string State { get; set; } = string.Empty;
    public string Country { get; set; } = "BR";
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<Line> Lines { get; set; } = [];
}

using NetTopologySuite.Geometries;

namespace Trilho.Domain.Entities;

public class GtfsAgency
{
    public int Id { get; set; }
    public string AgencyId { get; set; } = string.Empty;
    public string AgencyName { get; set; } = string.Empty;
    public string AgencyUrl { get; set; } = string.Empty;
    public string AgencyTimezone { get; set; } = string.Empty;
}

public class GtfsRoute
{
    public int Id { get; set; }
    public string RouteId { get; set; } = string.Empty;
    public string AgencyId { get; set; } = string.Empty;
    public string RouteShortName { get; set; } = string.Empty;
    public string RouteLongName { get; set; } = string.Empty;
    public string RouteColor { get; set; } = string.Empty;
    public string RouteTextColor { get; set; } = string.Empty;
}

public class GtfsStop
{
    public int Id { get; set; }
    public string StopId { get; set; } = string.Empty;
    public string StopName { get; set; } = string.Empty;
    public double StopLat { get; set; }
    public double StopLon { get; set; }
    public string? StopCode { get; set; }
    public Point Location { get; set; } = null!;
}

public class GtfsTrip
{
    public int Id { get; set; }
    public string TripId { get; set; } = string.Empty;
    public string RouteId { get; set; } = string.Empty;
    public string ServiceId { get; set; } = string.Empty;
    public string? TripHeadsign { get; set; }
    public bool DirectionId { get; set; }
}

public class GtfsStopTime
{
    public int Id { get; set; }
    public string TripId { get; set; } = string.Empty;
    public string StopId { get; set; } = string.Empty;
    public int StopSequence { get; set; }
    public string? ArrivalTime { get; set; }
    public string? DepartureTime { get; set; }
}

public class GtfsCalendar
{
    public int Id { get; set; }
    public string ServiceId { get; set; } = string.Empty;
    public bool Monday { get; set; }
    public bool Tuesday { get; set; }
    public bool Wednesday { get; set; }
    public bool Thursday { get; set; }
    public bool Friday { get; set; }
    public bool Saturday { get; set; }
    public bool Sunday { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
}

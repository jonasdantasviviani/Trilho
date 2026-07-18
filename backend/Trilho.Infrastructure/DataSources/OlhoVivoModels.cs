using System.Text.Json.Serialization;

namespace Trilho.Infrastructure.DataSources;

// ── Vehicle positions (/Posicao) ──────────────────────────────────────────────

public record OlhoVivoPosition(
    [property: JsonPropertyName("p")] int VehicleId,
    [property: JsonPropertyName("a")] bool Accessible,
    [property: JsonPropertyName("py")] double Lat,
    [property: JsonPropertyName("px")] double Lng,
    [property: JsonPropertyName("ta")] string UpdatedAt
);

public record OlhoVivoLine(
    [property: JsonPropertyName("c")]  string LineCode,
    [property: JsonPropertyName("cl")] int LineId,
    [property: JsonPropertyName("qv")] int VehicleCount,
    [property: JsonPropertyName("vs")] List<OlhoVivoPosition> Vehicles
);

public record OlhoVivoPositionResponse(
    [property: JsonPropertyName("hr")] string Hour,
    [property: JsonPropertyName("l")]  List<OlhoVivoLine> Lines
);

public record BusVehiclePosition(string LineCode, int VehicleId, double Lat, double Lng, DateTimeOffset UpdatedAt);

// ── Stop search (/Parada/Buscar) ──────────────────────────────────────────────

public record OlhoVivoBusStop(
    [property: JsonPropertyName("cp")] int StopCode,
    [property: JsonPropertyName("np")] string StopName,
    [property: JsonPropertyName("ed")] string? Address,
    [property: JsonPropertyName("py")] double Lat,
    [property: JsonPropertyName("px")] double Lng);

// ── Arrival predictions (/Previsao/Parada) ────────────────────────────────────

/// <summary>Approaching vehicle with its estimated arrival time ("HH:MM").</summary>
/// <remarks>
/// The OlhoVivo API returns the vehicle prefix field ("p") as a JSON string
/// even though it looks like a number, so <see cref="Prefix"/> is typed as string.
/// </remarks>
public record OlhoVivoArrivalVehicle(
    [property: JsonPropertyName("p")]  string? Prefix,
    [property: JsonPropertyName("t")]  string ArrivalTime,   // wall-clock "HH:MM" in BRT
    [property: JsonPropertyName("a")]  bool Accessible,
    [property: JsonPropertyName("ta")] string? UpdatedAt,
    [property: JsonPropertyName("py")] double Lat,
    [property: JsonPropertyName("px")] double Lng);

public record OlhoVivoArrivalLine(
    [property: JsonPropertyName("c")]   string LineCode,
    [property: JsonPropertyName("cl")]  int LineId,
    [property: JsonPropertyName("sl")]  int Direction,
    [property: JsonPropertyName("lt0")] string TerminusFrom,
    [property: JsonPropertyName("lt1")] string TerminusTo,
    [property: JsonPropertyName("qv")]  int VehicleCount,
    [property: JsonPropertyName("vs")]  List<OlhoVivoArrivalVehicle>? Vehicles);

public record OlhoVivoArrivalStop(
    [property: JsonPropertyName("cp")] int StopCode,
    [property: JsonPropertyName("np")] string StopName,
    [property: JsonPropertyName("py")] double Lat,
    [property: JsonPropertyName("px")] double Lng,
    [property: JsonPropertyName("l")]  List<OlhoVivoArrivalLine>? Lines);

public record OlhoVivoArrivalResponse(
    [property: JsonPropertyName("hr")] string? Hour,
    [property: JsonPropertyName("p")]  OlhoVivoArrivalStop? Stop);

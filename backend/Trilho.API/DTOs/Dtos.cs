namespace Trilho.API.DTOs;

public record CrowdDto(
    int StationId,
    string StationName,
    decimal Density,
    string DensityLevel,
    string Source,
    DateTimeOffset CapturedAt,
    IEnumerable<CrowdHistoryPoint> History
);

public record CrowdHistoryPoint(decimal Density, string Level, DateTimeOffset CapturedAt);

public record ForecastDto(int Hour, int AvgPassengers, string ExpectedLevel);

public record LineDto(
    int Id,
    string Code,
    string Name,
    string Type,
    string ColorHex,
    string CurrentStatus,
    string? StatusMessage,
    DateTimeOffset? StatusCapturedAt = null
);

public record LineStatusDto(
    string Code,
    string Status,
    string? Message,
    DateTimeOffset CapturedAt,
    IEnumerable<StationCrowdDto> Stations
);

public record StationCrowdDto(int Id, string Name, string DensityLevel, decimal Density);

public record VehiclePositionDto(int VehicleId, double Lat, double Lng, string LineCode, DateTimeOffset UpdatedAt);

public record RegisterResponseDto(Guid UserId, string Token);

public record UsageDto(int QueriesUsed, int QueriesLimit, bool IsPremium, bool IsAnonymous);

public record FirebaseAuthRequestDto(string IdToken);
public record FirebaseAuthResponseDto(string Token, FirebaseUserDto User);
public record FirebaseUserDto(Guid Id, string? Email, bool IsPremium, bool IsVip);

public record AdminUserDto(
    Guid Id,
    bool IsPremium,
    bool IsVip,
    string? VipEmail,
    int DailyQueriesUsed,
    DateTimeOffset CreatedAt);

public record AdminUsersPageDto(IEnumerable<AdminUserDto> Items, int Total, int Page, int Size);

public record PatchVipDto(bool IsVip, string? VipEmail);

public record AdminLoginDto(string Email, string Password);

public record AdminStatsFinancialDto(decimal Mrr, int NewSubscribers, int Churn, string Period);

public record QueryCountDto(DateTimeOffset Hour, int Count);
public record StationQueryDto(int StationId, string StationName, int Count);
public record AdminStatsOperationalDto(
    IEnumerable<QueryCountDto> QueriesPerHour,
    IEnumerable<StationQueryDto> TopStations,
    IEnumerable<LineDto> LineStatuses,
    double ErrorRate);

public record StationListDto(
    int Id,
    string Name,
    string LineCode,
    string LineColorHex,
    double Lat,
    double Lng,
    string DensityLevel,
    decimal Density);

public record PingRequestDto(double Lat, double Lng, DateTimeOffset Timestamp);

/// <param name="Rejected">True when the ping was rejected by anti-fraud (duplicate or velocity).</param>
public record PingResponseDto(int StationId, string StationName, bool InsideGeofence, bool Rejected = false);

public record DataSourceHealthDto(string Source, string Status, string AgeLabel, double AgeSeconds, string? LastError);

public record NearbyStationsDto(int Id, string Name, string LineCode, double DistanceMeters);

public record GtfsStatusDto(
    DateTime? SyncedAt,
    string? Source,
    DateTime? FileModifiedAt,
    bool IsCurrent,
    object? ImportedCounts,
    object DbCounts,
    string? SyncFilePath);

public record ArrivalTimeDto(int EstimatedMinutes, bool IsEstimated);
public record DirectionArrivalsDto(string Terminus, string? LineCode, IEnumerable<ArrivalTimeDto> Arrivals);
public record StationArrivalsDto(int StationId, IEnumerable<DirectionArrivalsDto> Directions);

// mobile/lib/core/models/station_arrivals_model.dart

class ArrivalTime {
  final int estimatedMinutes;
  final bool isEstimated;

  const ArrivalTime({required this.estimatedMinutes, required this.isEstimated});

  factory ArrivalTime.fromJson(Map<String, dynamic> j) => ArrivalTime(
        estimatedMinutes: j['estimatedMinutes'] as int,
        isEstimated: j['isEstimated'] as bool? ?? true,
      );
}

class DirectionArrivals {
  final String terminus;
  final List<ArrivalTime> arrivals;
  final String? lineCode; // optional — populated from API when available

  const DirectionArrivals({
    required this.terminus,
    required this.arrivals,
    this.lineCode,
  });

  factory DirectionArrivals.fromJson(Map<String, dynamic> j) =>
      DirectionArrivals(
        terminus: j['terminus'] as String,
        arrivals: (j['arrivals'] as List)
            .map((a) => ArrivalTime.fromJson(a as Map<String, dynamic>))
            .toList(),
        lineCode: j['lineCode'] as String?,
      );
}

class StationArrivals {
  final int stationId;
  final List<DirectionArrivals> directions;

  const StationArrivals({required this.stationId, required this.directions});

  factory StationArrivals.fromJson(Map<String, dynamic> j) => StationArrivals(
        stationId: j['stationId'] as int,
        directions: (j['directions'] as List)
            .map((d) => DirectionArrivals.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  /// Used when arrivals are unavailable (no headway data or API error).
  factory StationArrivals.unavailable({required int stationId}) =>
      StationArrivals(stationId: stationId, directions: const []);
}

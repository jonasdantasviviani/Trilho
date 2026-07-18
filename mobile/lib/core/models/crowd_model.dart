class CrowdModel {
  final int stationId;
  final String stationName;
  final double density;
  final String densityLevel;
  final String source;
  final DateTime capturedAt;
  final List<CrowdHistoryPoint> history;

  const CrowdModel({
    required this.stationId,
    required this.stationName,
    required this.density,
    required this.densityLevel,
    required this.source,
    required this.capturedAt,
    required this.history,
  });

  /// True when real crowd data exists. False for the "no data yet" placeholder.
  bool get hasData => densityLevel != 'Unknown';

  factory CrowdModel.fromJson(Map<String, dynamic> j) => CrowdModel(
        stationId: j['stationId'] as int,
        stationName: j['stationName'] as String,
        density: (j['density'] as num).toDouble(),
        densityLevel: j['densityLevel'] as String,
        source: j['source'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        history: (j['history'] as List)
            .map((h) => CrowdHistoryPoint.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

class CrowdHistoryPoint {
  final double density;
  final String level;
  final DateTime capturedAt;

  const CrowdHistoryPoint({
    required this.density,
    required this.level,
    required this.capturedAt,
  });

  factory CrowdHistoryPoint.fromJson(Map<String, dynamic> j) => CrowdHistoryPoint(
        density: (j['density'] as num).toDouble(),
        level: j['level'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
      );
}

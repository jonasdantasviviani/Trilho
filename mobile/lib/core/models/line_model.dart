// mobile/lib/core/models/line_model.dart
class LineModel {
  final int id;
  final String code;
  final String name;
  final String type;
  final String colorHex;
  final String currentStatus;
  final String? statusMessage;
  final DateTime? statusCapturedAt;  // when the status was last scraped
  final List<String>? termini;       // e.g. ['Tucuruvi', 'Jabaquara']
  final int? headwaySeconds;         // average train interval in seconds
  final List<int>? stationIds;       // ordered station IDs for this line

  const LineModel({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.colorHex,
    required this.currentStatus,
    this.statusMessage,
    this.statusCapturedAt,
    this.termini,
    this.headwaySeconds,
    this.stationIds,
  });

  factory LineModel.fromJson(Map<String, dynamic> j) => LineModel(
        id: j['id'] as int,
        code: j['code'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        colorHex: j['colorHex'] as String,
        currentStatus: j['currentStatus'] as String,
        statusMessage: j['statusMessage'] as String?,
        statusCapturedAt: j['statusCapturedAt'] != null
            ? DateTime.tryParse(j['statusCapturedAt'] as String)
            : null,
        termini: (j['termini'] as List?)?.cast<String>(),
        headwaySeconds: j['headwaySeconds'] as int?,
        stationIds: (j['stationIds'] as List?)?.cast<int>(),
      );

  /// Returns ARGB int for use with Color(). ColorHex is stored without #.
  int get colorValue => int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16);

  /// True when the last status update is older than 5 minutes.
  bool get isStale {
    if (statusCapturedAt == null) return false;
    return DateTime.now().toUtc().difference(statusCapturedAt!.toUtc()) >
        const Duration(minutes: 5);
  }
}

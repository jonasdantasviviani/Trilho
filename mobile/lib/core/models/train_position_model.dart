// mobile/lib/core/models/train_position_model.dart

class TrainPositionModel {
  final String lineCode;
  final double lat;
  final double lng;
  final DateTime updatedAt;

  const TrainPositionModel({
    required this.lineCode,
    required this.lat,
    required this.lng,
    required this.updatedAt,
  });

  factory TrainPositionModel.fromJson(Map<String, dynamic> j) =>
      TrainPositionModel(
        lineCode: j['lineCode'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

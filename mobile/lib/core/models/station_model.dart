class StationModel {
  final int id;
  final String name;
  final String densityLevel; // Low | Medium | High | Packed
  final double density;      // 0.0–1.0
  final double lat;
  final double lng;

  const StationModel({
    required this.id,
    required this.name,
    required this.densityLevel,
    required this.density,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  factory StationModel.fromJson(Map<String, dynamic> j) => StationModel(
        id: j['id'] as int,
        name: j['name'] as String,
        densityLevel: j['densityLevel'] as String,
        density: (j['density'] as num).toDouble(),
        lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0.0,
      );
}

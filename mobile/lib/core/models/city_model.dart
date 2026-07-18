// City catalog — add new cities to CityRegistry.all
import 'schematic_model.dart';
import '../data/sao_paulo_schematic.dart';

class CityModel {
  final String id;
  final String name;
  final String stateCode;
  final String stateName;
  final double lat;
  final double lng;
  final double defaultZoom;
  final String? schematicId; // null = no schematic yet

  const CityModel({
    required this.id,
    required this.name,
    required this.stateCode,
    required this.stateName,
    required this.lat,
    required this.lng,
    required this.defaultZoom,
    this.schematicId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CityModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name, $stateCode';
}

class CityRegistry {
  CityRegistry._();

  static const List<CityModel> all = [
    CityModel(
      id: 'sao-paulo-sp',
      name: 'São Paulo',
      stateCode: 'SP',
      stateName: 'São Paulo',
      lat: -23.5505,
      lng: -46.6333,
      defaultZoom: 11.0,
      schematicId: 'sao-paulo-sp',
    ),
    CityModel(
      id: 'curitiba-pr',
      name: 'Curitiba',
      stateCode: 'PR',
      stateName: 'Paraná',
      lat: -25.4284,
      lng: -49.2733,
      defaultZoom: 11.0,
    ),
    CityModel(
      id: 'rio-de-janeiro-rj',
      name: 'Rio de Janeiro',
      stateCode: 'RJ',
      stateName: 'Rio de Janeiro',
      lat: -22.9068,
      lng: -43.1729,
      defaultZoom: 11.0,
    ),
    CityModel(
      id: 'belo-horizonte-mg',
      name: 'Belo Horizonte',
      stateCode: 'MG',
      stateName: 'Minas Gerais',
      lat: -19.9167,
      lng: -43.9345,
      defaultZoom: 11.0,
    ),
    CityModel(
      id: 'porto-alegre-rs',
      name: 'Porto Alegre',
      stateCode: 'RS',
      stateName: 'Rio Grande do Sul',
      lat: -30.0346,
      lng: -51.2177,
      defaultZoom: 11.0,
    ),
  ];

  /// Returns [TransitSchematic] for city, or null if not yet available.
  /// Never throws.
  static TransitSchematic? getSchematic(String cityId) => switch (cityId) {
        'sao-paulo-sp' => saoPauloSchematic,
        _ => null,
      };

  static Map<String, List<CityModel>> get byState {
    final map = <String, List<CityModel>>{};
    for (final city in all) {
      map.putIfAbsent(city.stateName, () => []).add(city);
    }
    for (final cities in map.values) {
      cities.sort((a, b) => a.name.compareTo(b.name));
    }
    return map;
  }

  static CityModel? findById(String id) {
    for (final city in all) {
      if (city.id == id) return city;
    }
    return null;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/station_model.dart';

void main() {
  test('StationModel.fromJson parses lat and lng', () {
    final json = {
      'id': 1,
      'name': 'Luz',
      'lineCode': '10',
      'densityLevel': 'Medium',
      'density': 0.5,
      'lat': -23.5342,
      'lng': -46.6337,
    };

    final model = StationModel.fromJson(json);

    expect(model.lat, -23.5342);
    expect(model.lng, -46.6337);
  });

  test('StationModel.fromJson defaults lat/lng to 0.0 when absent', () {
    final json = {
      'id': 1,
      'name': 'Luz',
      'densityLevel': 'Low',
      'density': 0.2,
    };

    final model = StationModel.fromJson(json);

    expect(model.lat, 0.0);
    expect(model.lng, 0.0);
  });
}

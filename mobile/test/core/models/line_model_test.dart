// mobile/test/core/models/line_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/line_model.dart';

void main() {
  group('LineModel.fromJson', () {
    test('parses new nullable fields when present', () {
      final json = {
        'id': 1,
        'code': 'L1',
        'name': 'Linha 1 - Azul',
        'type': 'Metro',
        'colorHex': '0000CD',
        'currentStatus': 'Normal',
        'termini': ['Tucuruvi', 'Jabaquara'],
        'headwaySeconds': 180,
        'stationIds': [10, 11, 12, 13],
      };

      final model = LineModel.fromJson(json);
      expect(model.termini, ['Tucuruvi', 'Jabaquara']);
      expect(model.headwaySeconds, 180);
      expect(model.stationIds, [10, 11, 12, 13]);
    });

    test('new fields default to null when absent (backward compat)', () {
      final json = {
        'id': 1,
        'code': 'L1',
        'name': 'Linha 1 - Azul',
        'type': 'Metro',
        'colorHex': '0000CD',
        'currentStatus': 'Normal',
      };

      final model = LineModel.fromJson(json);
      expect(model.termini, isNull);
      expect(model.headwaySeconds, isNull);
      expect(model.stationIds, isNull);
    });

    test('colorValue converts hex correctly', () {
      final model = LineModel.fromJson({
        'id': 1, 'code': 'L1', 'name': 'Test', 'type': 'Metro',
        'colorHex': '0000CD', 'currentStatus': 'Normal',
      });
      expect(model.colorValue, 0xFF0000CD);
    });
  });
}

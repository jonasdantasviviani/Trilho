import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/data/sao_paulo_schematic.dart';

void main() {
  group('saoPauloSchematic', () {
    test('canvas size is 1500x1000', () {
      expect(saoPauloSchematic.canvasSize, const Size(1500, 1000));
    });

    test('has all 16 lines', () {
      final codes = saoPauloSchematic.lines.map((l) => l.lineCode).toSet();
      for (final code in ['L1','L2','L3','L4','L5','L15','L7','L8','L9','L10','L11','L12','L13','L17','LA','LB']) {
        expect(codes, contains(code), reason: 'Missing line $code');
      }
    });

    test('all lines have at least 2 points', () {
      for (final line in saoPauloSchematic.lines) {
        expect(line.points.length, greaterThanOrEqualTo(2), reason: '${line.lineCode} has < 2 points');
      }
    });

    test('all lines have at least 2 stationIds', () {
      for (final line in saoPauloSchematic.lines) {
        expect(line.stationIds.length, greaterThanOrEqualTo(2), reason: '${line.lineCode} has < 2 stations');
      }
    });

    test('all stations have non-empty names', () {
      for (final st in saoPauloSchematic.stations) {
        expect(st.name.trim().isNotEmpty, true, reason: 'Station ${st.stationId} has empty name');
      }
    });

    test('all station positions within canvas bounds', () {
      for (final st in saoPauloSchematic.stations) {
        expect(st.position.dx, inInclusiveRange(0, 1500), reason: '${st.name} x out of bounds');
        expect(st.position.dy, inInclusiveRange(0, 1000), reason: '${st.name} y out of bounds');
      }
    });

    test('interchange stations have isInterchange true and multiple lineCodes', () {
      final luz = saoPauloSchematic.stations.where((s) => s.name == 'Luz').firstOrNull;
      expect(luz, isNotNull);
      expect(luz!.isInterchange, true);
      expect(luz.lineCodes.length, greaterThanOrEqualTo(2));
    });

    test('all stationIds in lines resolve to existing stations', () {
      final ids = saoPauloSchematic.stations.map((s) => s.stationId).toSet();
      for (final line in saoPauloSchematic.lines) {
        for (final id in line.stationIds) {
          expect(ids, contains(id), reason: 'Line ${line.lineCode} references unknown stationId $id');
        }
      }
    });

    test('no duplicate stationIds in stations list', () {
      final ids = saoPauloSchematic.stations.map((s) => s.stationId).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, uniqueIds.length, reason: 'Duplicate stationIds found');
    });
  });
}

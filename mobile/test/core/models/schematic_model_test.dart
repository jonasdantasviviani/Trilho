// mobile/test/core/models/schematic_model_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/schematic_model.dart';

void main() {
  group('SchematicStation', () {
    test('maxCapacity defaults to 1200 when not provided', () {
      const s = SchematicStation(stationId: 1, name: 'Test', position: Offset(100, 200));
      expect(s.maxCapacity, 1200);
    });

    test('uses provided maxCapacity', () {
      const s = SchematicStation(stationId: 1, name: 'Test', position: Offset(0, 0), maxCapacity: 800);
      expect(s.maxCapacity, 800);
    });
  });

  group('TransitSchematic', () {
    test('stationById returns station when found', () {
      const schematic = TransitSchematic(
        canvasSize: Size(1000, 800),
        lines: [],
        stations: [
          SchematicStation(stationId: 5, name: 'Test', position: Offset(200, 300)),
        ],
      );
      expect(schematic.stationById(5)?.stationId, 5);
    });

    test('stationById returns null when not found', () {
      const schematic = TransitSchematic(
        canvasSize: Size(1000, 800),
        lines: [],
        stations: [],
      );
      expect(schematic.stationById(99), isNull);
    });

    test('stationsForLine returns only stations matching line stationIds', () {
      const schematic = TransitSchematic(
        canvasSize: Size(1000, 800),
        lines: [SchematicLine(lineCode: 'L1', points: [], stationIds: [1, 2])],
        stations: [
          SchematicStation(stationId: 1, name: 'A', position: Offset(100, 100)),
          SchematicStation(stationId: 2, name: 'B', position: Offset(100, 200)),
          SchematicStation(stationId: 3, name: 'C', position: Offset(100, 300)),
        ],
      );
      final stations = schematic.stationsForLine('L1');
      expect(stations.map((s) => s.stationId).toList(), [1, 2]);
    });

    test('stationsForLine returns empty list for unknown line code', () {
      const schematic = TransitSchematic(
        canvasSize: Size(1000, 800),
        lines: [],
        stations: [],
      );
      expect(schematic.stationsForLine('UNKNOWN'), isEmpty);
    });
  });

  group('SchematicStation extended fields', () {
    test('has name field', () {
      const s = SchematicStation(
        stationId: 1,
        name: 'Luz',
        position: Offset(100, 100),
        isInterchange: true,
        lineCodes: ['L1', 'L3'],
        labelSide: LabelSide.above,
      );
      expect(s.name, 'Luz');
      expect(s.isInterchange, true);
      expect(s.lineCodes, ['L1', 'L3']);
      expect(s.labelSide, LabelSide.above);
      expect(s.maxCapacity, 1200); // default
    });

    test('LabelSide enum has above, below, left and right', () {
      expect(LabelSide.values.length, 4);
      expect(LabelSide.values,
          containsAll([LabelSide.above, LabelSide.below, LabelSide.left, LabelSide.right]));
    });
  });

  group('TransitSchematic.stationsForLine with name', () {
    test('returns stations with names', () {
      const schematic = TransitSchematic(
        canvasSize: Size(1000, 800),
        lines: [
          SchematicLine(lineCode: 'L1', points: [Offset(0,0), Offset(100,0)], stationIds: [1, 2]),
        ],
        stations: [
          SchematicStation(stationId: 1, name: 'Tucuruvi', position: Offset(10, 0), labelSide: LabelSide.above),
          SchematicStation(stationId: 2, name: 'Parada Inglesa', position: Offset(50, 0), labelSide: LabelSide.below),
        ],
      );
      final stations = schematic.stationsForLine('L1');
      expect(stations.map((s) => s.name).toList(), ['Tucuruvi', 'Parada Inglesa']);
    });
  });
}

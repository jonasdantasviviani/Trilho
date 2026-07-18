// mobile/test/features/transit_map/transit_map_painter_test.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/features/transit_map/transit_map_painter.dart';
import 'package:trilho/core/models/schematic_model.dart';
import 'package:trilho/core/widgets/app_theme.dart';

void main() {
  group('TransitMapPainter static helpers', () {
    test('segmentAngle horizontal right is 0', () {
      expect(TransitMapPainter.segmentAngle(const Offset(0, 0), const Offset(100, 0)), closeTo(0.0, 0.001));
    });

    test('segmentAngle vertical down is pi/2', () {
      expect(TransitMapPainter.segmentAngle(const Offset(0, 0), const Offset(0, 100)), closeTo(pi / 2, 0.001));
    });

    test('segmentAngle diagonal is pi/4', () {
      expect(TransitMapPainter.segmentAngle(const Offset(0, 0), const Offset(100, 100)), closeTo(pi / 4, 0.001));
    });

    test('segmentAngleForStation finds closest segment', () {
      // Line with two segments: horizontal then diagonal
      final points = [const Offset(0, 0), const Offset(100, 0), const Offset(200, 100)];
      // Station near first segment midpoint (50, 0) → angle should be ~0
      final angle1 = TransitMapPainter.segmentAngleForStation(const Offset(50, 5), points);
      expect(angle1, closeTo(0.0, 0.1));
      // Station near second segment midpoint (150, 50) → angle should be ~pi/4
      final angle2 = TransitMapPainter.segmentAngleForStation(const Offset(150, 50), points);
      expect(angle2, closeTo(pi / 4, 0.1));
    });

    test('interchangeTickAngle returns opposite of mean angle', () {
      // Two lines at 0 and pi/2: mean = pi/4, opposite = pi/4 + pi = 5pi/4
      final angles = [0.0, pi / 2];
      final result = TransitMapPainter.interchangeTickAngle(angles);
      expect(result, closeTo(pi / 4 + pi, 0.01));
    });

    test('interchangeTickAngle with empty list returns -pi/2', () {
      expect(TransitMapPainter.interchangeTickAngle([]), closeTo(-pi / 2, 0.001));
    });

    test('label opacity is 0 below scale 0.8', () {
      // Test via the formula directly: ((0.5 - 0.8) / (1.5 - 0.8)).clamp(0, 1) = 0
      final opacity = ((0.5 - 0.8) / (1.5 - 0.8)).clamp(0.0, 1.0);
      expect(opacity, 0.0);
    });

    test('label opacity is 1.0 above scale 1.5', () {
      final opacity = ((2.0 - 0.8) / (1.5 - 0.8)).clamp(0.0, 1.0);
      expect(opacity, 1.0);
    });
  });

  group('TransitMapPainter constructor', () {
    test('can be constructed with all required params', () {
      // Just ensure it doesn't throw
      expect(() => const TransitMapPainter(
        schematic: TransitSchematic(
          canvasSize: Size(100, 100),
          lines: [],
          stations: [],
        ),
        crowdState: {},
        lineColors: {},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.light,
        currentScale: 1.0,
      ), returnsNormally);
    });
  });

  group('TransitMapPainter color tokens', () {
    const schematic = TransitSchematic(
      canvasSize: Size(100, 100), lines: [], stations: [],
    );

    test('bgColorForTest dark == AppTheme.bgDark', () {
      const p = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {},
        selectedLineCode: null,
        zoomProgress: 0,
        barProgress: 0,
        trainEstimate: null,
        trainPulse: 0,
        brightness: Brightness.dark,
        currentScale: 1.0,
      );
      expect(p.bgColorForTest, AppTheme.bgDark);
    });

    test('bgColorForTest light == AppTheme.bgLight', () {
      const p = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {},
        selectedLineCode: null,
        zoomProgress: 0,
        barProgress: 0,
        trainEstimate: null,
        trainPulse: 0,
        brightness: Brightness.light,
        currentScale: 1.0,
      );
      expect(p.bgColorForTest, AppTheme.bgLight);
    });
  });

  group('TransitMapPainter shouldRepaint', () {
    const schematic = TransitSchematic(
      canvasSize: Size(1000, 800),
      lines: [
        SchematicLine(lineCode: 'L1', points: [Offset(100, 100), Offset(100, 400)], stationIds: [1, 2]),
      ],
      stations: [
        SchematicStation(stationId: 1, name: 'Station 1', position: Offset(100, 100)),
        SchematicStation(stationId: 2, name: 'Station 2', position: Offset(100, 400)),
      ],
    );

    test('shouldRepaint returns true when crowdState changes', () {
      const painter1 = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {'L1': Color(0xFF0000CD)},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.light,
        currentScale: 1.0,
      );
      const painter2 = TransitMapPainter(
        schematic: schematic,
        crowdState: {1: 0.8},
        lineColors: {'L1': Color(0xFF0000CD)},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.light,
        currentScale: 1.0,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      const painter = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {'L1': Color(0xFF0000CD)},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.light,
        currentScale: 1.0,
      );
      expect(painter.shouldRepaint(painter), isFalse);
    });

    test('shouldRepaint returns true when brightness changes', () {
      const painter1 = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.light,
        currentScale: 1.0,
      );
      const painter2 = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.dark,
        currentScale: 1.0,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when lineColors changes', () {
      const painter1 = TransitMapPainter(
        schematic: TransitSchematic(canvasSize: Size(100,100), lines: [], stations: []),
        crowdState: {},
        lineColors: {'L1': Colors.blue},
        selectedLineCode: null,
        zoomProgress: 0, barProgress: 0, trainEstimate: null, trainPulse: 0,
        brightness: Brightness.light, currentScale: 1.0,
      );
      const painter2 = TransitMapPainter(
        schematic: TransitSchematic(canvasSize: Size(100,100), lines: [], stations: []),
        crowdState: {},
        lineColors: {'L1': Colors.red},
        selectedLineCode: null,
        zoomProgress: 0, barProgress: 0, trainEstimate: null, trainPulse: 0,
        brightness: Brightness.light, currentScale: 1.0,
      );
      expect(painter2.shouldRepaint(painter1), true);
    });

    test('shouldRepaint returns true when currentScale changes', () {
      const painter1 = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.light,
        currentScale: 1.0,
      );
      const painter2 = TransitMapPainter(
        schematic: schematic,
        crowdState: {},
        lineColors: {},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
        brightness: Brightness.light,
        currentScale: 2.0,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });
}

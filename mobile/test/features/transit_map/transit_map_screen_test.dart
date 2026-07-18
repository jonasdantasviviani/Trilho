// mobile/test/features/transit_map/transit_map_screen_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/line_model.dart';
import 'package:trilho/core/models/schematic_model.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/providers/lines_provider.dart';
import 'package:trilho/core/providers/transit_map_provider.dart';
import 'package:trilho/core/providers/signalr_provider.dart';
import 'package:trilho/features/transit_map/transit_map_screen.dart';

void main() {
  group('findStationAt', () {
    final stations = [
      const SchematicStation(stationId: 1, name: 'Sé', position: Offset(100, 200)),
      const SchematicStation(stationId: 2, name: 'Anhangabaú', position: Offset(300, 200)),
      const SchematicStation(stationId: 3, name: 'República', position: Offset(500, 200)),
    ];

    test('returns station when tap is within radius', () {
      final result = findStationAt(stations, const Offset(105, 205), 24.0);
      expect(result?.stationId, 1);
    });

    test('returns null when tap is outside all stations', () {
      final result = findStationAt(stations, const Offset(999, 999), 24.0);
      expect(result, isNull);
    });

    test('returns closest station when two are within radius', () {
      // Tap at (110, 200) — closer to station 1 (dist=10) than station 2 (dist=190)
      final result = findStationAt(stations, const Offset(110, 200), 50.0);
      expect(result?.stationId, 1);
    });

    test('returns null for empty list', () {
      final result = findStationAt([], const Offset(100, 200), 24.0);
      expect(result, isNull);
    });
  });


  testWidgets('shows loading state while schematic loads', (tester) async {
    final completer = Completer<TransitSchematic?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transitMapProvider.overrideWith((ref) => completer.future),
          signalRProvider.overrideWith((ref) => SignalRNotifier()),
          selectedCityProvider.overrideWith((ref) => SelectedCityNotifier.skipHive()),
          linesProvider.overrideWith((ref) => Future.value(<LineModel>[])),
        ],
        child: const MaterialApp(home: TransitMapScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('shows "em breve" banner when schematic is null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transitMapProvider.overrideWith((ref) => Future.value(null)),
          signalRProvider.overrideWith((ref) => SignalRNotifier()),
          selectedCityProvider.overrideWith((ref) => SelectedCityNotifier.skipHive()),
          linesProvider.overrideWith((ref) => Future.value(<LineModel>[])),
        ],
        child: const MaterialApp(home: TransitMapScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('em breve'), findsOneWidget);
  });

  testWidgets('shows CustomPaint when schematic is available', (tester) async {
    const schematic = TransitSchematic(
      canvasSize: Size(1000, 800),
      lines: [SchematicLine(lineCode: 'L1', points: [Offset(0, 0), Offset(100, 100)], stationIds: [])],
      stations: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transitMapProvider.overrideWith((ref) => Future.value(schematic)),
          signalRProvider.overrideWith((ref) => SignalRNotifier()),
          selectedCityProvider.overrideWith((ref) => SelectedCityNotifier.skipHive()),
          linesProvider.overrideWith((ref) => Future.value(<LineModel>[])),
        ],
        child: const MaterialApp(home: TransitMapScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('TransitMapScreen has a Stack with chips overlay', (tester) async {
    const schematic = TransitSchematic(
      canvasSize: Size(1000, 800),
      lines: [SchematicLine(lineCode: 'L1', points: [Offset(0, 0), Offset(100, 100)], stationIds: [])],
      stations: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transitMapProvider.overrideWith((ref) => Future.value(schematic)),
          signalRProvider.overrideWith((ref) => SignalRNotifier()),
          selectedCityProvider.overrideWith((ref) => SelectedCityNotifier.skipHive()),
          linesProvider.overrideWith((ref) => Future.value(<LineModel>[])),
        ],
        child: const MaterialApp(home: TransitMapScreen()),
      ),
    );

    await tester.pumpAndSettle();
    // Stack layout: InteractiveViewer fills body, chips float on top
    expect(find.byType(Stack), findsWidgets);
    // Chips scroll row
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}

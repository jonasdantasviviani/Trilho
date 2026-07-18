# Animated Transit Map Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Google Maps screen with an animated official metro schematic diagram that zooms into lines, shows real-time crowd bars, estimated train position, and redesigned station detail screen.

**Architecture:** A `CustomPainter` (`TransitMapPainter`) inside an `InteractiveViewer` renders the metro schematic. A `LineZoomController` orchestrates the multi-step animation (fade + camera zoom + capacity bars + train icon). `StationDetailScreen` is fully redesigned with direction cards and animated people count. `google_maps_flutter` is removed entirely.

**Tech Stack:** Flutter, Riverpod, go_router, CustomPainter, InteractiveViewer, TransformationController, AnimationController, SpringSimulation, SignalR (existing)

**Spec:** `docs/superpowers/specs/2026-04-07-animated-transit-map-design.md`

---

## Chunk 1: Data Foundation

### Task 1: Schematic models

**Files:**
- Create: `mobile/lib/core/models/schematic_model.dart`
- Create: `mobile/test/core/models/schematic_model_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// mobile/test/core/models/schematic_model_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/schematic_model.dart';

void main() {
  group('SchematicStation', () {
    test('capacity defaults to 1200 when not provided', () {
      const s = SchematicStation(stationId: 1, position: Offset(100, 200));
      expect(s.capacity, 1200);
    });

    test('uses provided capacity', () {
      const s = SchematicStation(stationId: 1, position: Offset(0, 0), capacity: 800);
      expect(s.capacity, 800);
    });
  });

  group('TransitSchematic', () {
    test('stationById returns station when found', () {
      const schematic = TransitSchematic(
        canvasSize: Size(1000, 800),
        lines: [],
        stations: [
          SchematicStation(stationId: 5, position: Offset(200, 300)),
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
          SchematicStation(stationId: 1, position: Offset(100, 100)),
          SchematicStation(stationId: 2, position: Offset(100, 200)),
          SchematicStation(stationId: 3, position: Offset(100, 300)),
        ],
      );
      final stations = schematic.stationsForLine('L1');
      expect(stations.map((s) => s.stationId).toList(), [1, 2]);
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they FAIL**

```bash
cd mobile && flutter test test/core/models/schematic_model_test.dart
```
Expected: compilation error (file not found)

- [ ] **Step 3: Create `schematic_model.dart`**

```dart
// mobile/lib/core/models/schematic_model.dart
import 'package:flutter/material.dart';

class SchematicStation {
  final int stationId;
  final Offset position;
  final int capacity;

  const SchematicStation({
    required this.stationId,
    required this.position,
    this.capacity = 1200,
  });
}

class SchematicLine {
  final String lineCode;
  final List<Offset> points;
  final List<int> stationIds; // ordered, matches LineModel.stationIds

  const SchematicLine({
    required this.lineCode,
    required this.points,
    required this.stationIds,
  });
}

class TransitSchematic {
  final Size canvasSize;
  final List<SchematicLine> lines;
  final List<SchematicStation> stations;

  const TransitSchematic({
    required this.canvasSize,
    required this.lines,
    required this.stations,
  });

  SchematicStation? stationById(int id) {
    for (final s in stations) {
      if (s.stationId == id) return s;
    }
    return null;
  }

  /// Returns stations for [lineCode] in the order defined by SchematicLine.stationIds.
  List<SchematicStation> stationsForLine(String lineCode) {
    final line = lines.where((l) => l.lineCode == lineCode).firstOrNull;
    if (line == null) return [];
    return line.stationIds
        .map((id) => stationById(id))
        .whereType<SchematicStation>()
        .toList();
  }
}
```

- [ ] **Step 4: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/core/models/schematic_model_test.dart
```
Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/models/schematic_model.dart mobile/test/core/models/schematic_model_test.dart
git commit -m "feat: add TransitSchematic, SchematicLine, SchematicStation models"
```

---

### Task 2: StationArrivals model

**Files:**
- Create: `mobile/lib/core/models/station_arrivals_model.dart`
- Create: `mobile/test/core/models/station_arrivals_model_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// mobile/test/core/models/station_arrivals_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/station_arrivals_model.dart';

void main() {
  group('StationArrivals', () {
    test('fromJson parses directions and arrival times', () {
      final json = {
        'stationId': 10,
        'directions': [
          {
            'terminus': 'Jabaquara',
            'arrivals': [
              {'estimatedMinutes': 2, 'isEstimated': false},
              {'estimatedMinutes': 8, 'isEstimated': false},
            ],
          },
          {
            'terminus': 'Tucuruvi',
            'arrivals': [
              {'estimatedMinutes': 4, 'isEstimated': true},
            ],
          },
        ],
      };

      final arrivals = StationArrivals.fromJson(json);
      expect(arrivals.stationId, 10);
      expect(arrivals.directions.length, 2);
      expect(arrivals.directions[0].terminus, 'Jabaquara');
      expect(arrivals.directions[0].arrivals[0].estimatedMinutes, 2);
      expect(arrivals.directions[1].arrivals[0].isEstimated, true);
    });

    test('StationArrivals.unavailable returns empty directions list', () {
      final a = StationArrivals.unavailable(stationId: 5);
      expect(a.stationId, 5);
      expect(a.directions, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they FAIL**

```bash
cd mobile && flutter test test/core/models/station_arrivals_model_test.dart
```

- [ ] **Step 3: Create `station_arrivals_model.dart`**

```dart
// mobile/lib/core/models/station_arrivals_model.dart

class ArrivalTime {
  final int estimatedMinutes;
  final bool isEstimated;

  const ArrivalTime({required this.estimatedMinutes, required this.isEstimated});

  factory ArrivalTime.fromJson(Map<String, dynamic> j) => ArrivalTime(
        estimatedMinutes: j['estimatedMinutes'] as int,
        isEstimated: j['isEstimated'] as bool? ?? true,
      );
}

class DirectionArrivals {
  final String terminus;
  final List<ArrivalTime> arrivals;

  const DirectionArrivals({required this.terminus, required this.arrivals});

  factory DirectionArrivals.fromJson(Map<String, dynamic> j) =>
      DirectionArrivals(
        terminus: j['terminus'] as String,
        arrivals: (j['arrivals'] as List)
            .map((a) => ArrivalTime.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class StationArrivals {
  final int stationId;
  final List<DirectionArrivals> directions;

  const StationArrivals({required this.stationId, required this.directions});

  factory StationArrivals.fromJson(Map<String, dynamic> j) => StationArrivals(
        stationId: j['stationId'] as int,
        directions: (j['directions'] as List)
            .map((d) => DirectionArrivals.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  /// Used when arrivals are unavailable (no headway data or API error).
  factory StationArrivals.unavailable({required int stationId}) =>
      StationArrivals(stationId: stationId, directions: []);
}
```

- [ ] **Step 4: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/core/models/station_arrivals_model_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/models/station_arrivals_model.dart mobile/test/core/models/station_arrivals_model_test.dart
git commit -m "feat: add StationArrivals model with direction cards support"
```

---

### Task 3: Update LineModel with nullable fields

**Files:**
- Modify: `mobile/lib/core/models/line_model.dart`
- Create: `mobile/test/core/models/line_model_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
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
```

- [ ] **Step 2: Run tests — verify they FAIL**

```bash
cd mobile && flutter test test/core/models/line_model_test.dart
```

- [ ] **Step 3: Update `line_model.dart`**

Replace the entire file:

```dart
// mobile/lib/core/models/line_model.dart
class LineModel {
  final int id;
  final String code;
  final String name;
  final String type;
  final String colorHex;
  final String currentStatus;
  final String? statusMessage;
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
        termini: (j['termini'] as List?)?.cast<String>(),
        headwaySeconds: j['headwaySeconds'] as int?,
        stationIds: (j['stationIds'] as List?)?.cast<int>(),
      );

  /// Returns ARGB int for use with Color(). ColorHex is stored without #.
  int get colorValue => int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16);
}
```

- [ ] **Step 4: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/core/models/line_model_test.dart
```

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
cd mobile && flutter test
```
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/core/models/line_model.dart mobile/test/core/models/line_model_test.dart
git commit -m "feat: add nullable termini, headwaySeconds, stationIds to LineModel"
```

---

### Task 4: Extend SignalR to carry density float

The current `signalRProvider` state is `Map<int, String>` (level only). The `TrainEstimator` needs float density values to detect trends. We extend it to carry both.

**Files:**
- Modify: `mobile/lib/core/providers/signalr_provider.dart`

- [ ] **Step 1: Update `SignalRNotifier` state type**

Replace `mobile/lib/core/providers/signalr_provider.dart` entirely:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants.dart';

/// State entry for a single station from SignalR.
class SignalRCrowdEntry {
  final String densityLevel;
  final double density;
  final DateTime updatedAt;

  const SignalRCrowdEntry({
    required this.densityLevel,
    required this.density,
    required this.updatedAt,
  });
}

class SignalRNotifier extends StateNotifier<Map<int, SignalRCrowdEntry>> {
  late final HubConnection _hub;

  SignalRNotifier() : super({}) {
    _connect();
  }

  Future<void> _connect() async {
    _hub = HubConnectionBuilder()
        .withUrl(AppConstants.signalrHubUrl)
        .withAutomaticReconnect()
        .build();

    _hub.on('CrowdUpdated', (args) {
      if (args == null || args.isEmpty) return;
      final data       = args[0] as Map<String, dynamic>;
      final stationId  = data['stationId'] as int;
      final level      = data['densityLevel'] as String;
      final density    = (data['density'] as num?)?.toDouble() ?? _densityFromLevel(level);
      state = {
        ...state,
        stationId: SignalRCrowdEntry(
          densityLevel: level,
          density: density,
          updatedAt: DateTime.now(),
        ),
      };
    });

    try {
      await _hub.start();
    } catch (e) {
      debugPrint('SignalR connection failed: $e');
    }
  }

  Future<void> subscribeLine(String lineCode) async {
    if (_hub.state == HubConnectionState.Connected) {
      await _hub.invoke('SubscribeLine', args: [lineCode]);
    }
  }

  /// Fallback density values when the backend doesn't send a float.
  static double _densityFromLevel(String level) => switch (level) {
        'Low'    => 0.25,
        'Medium' => 0.50,
        'High'   => 0.75,
        'Packed' => 0.95,
        _        => 0.5,
      };

  @override
  void dispose() {
    _hub.stop();
    super.dispose();
  }
}

final signalRProvider =
    StateNotifierProvider<SignalRNotifier, Map<int, SignalRCrowdEntry>>(
  (ref) => SignalRNotifier(),
);
```

- [ ] **Step 2: Update map_screen.dart to use new state type**

`map_screen.dart` watches `signalRProvider`. Since its state type changed from `Map<int, String>` to `Map<int, SignalRCrowdEntry>`, update any usage in `map_screen.dart`. Open the file and replace any `.containsKey` / map access that treated the value as a `String` density level:

Search for: `signalRProvider`
If it uses the value as a String, wrap with `.densityLevel`:
```dart
// Before (if present):
final level = crowdState[stationId];
// After:
final level = crowdState[stationId]?.densityLevel;
```

Then verify the app compiles:
```bash
cd mobile && flutter analyze lib/
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/core/providers/signalr_provider.dart
git commit -m "feat: extend SignalRNotifier state to carry density float alongside level"
```

---

### Task 5: Add getStationArrivals to ApiService + update CityModel

**Files:**
- Modify: `mobile/lib/core/services/api_service.dart`
- Modify: `mobile/lib/core/models/city_model.dart`

- [ ] **Step 1: Add `getStationArrivals` to ApiService**

In `mobile/lib/core/services/api_service.dart`, add at line 81 (after `loginWithFirebase`):

```dart
Future<StationArrivals> getStationArrivals(int stationId) async {
  final resp = await _dio.get('/api/stations/$stationId/arrivals');
  return StationArrivals.fromJson(resp.data as Map<String, dynamic>);
}
```

Also add the import at the top of the file:

```dart
import '../models/station_arrivals_model.dart';
```

- [ ] **Step 2: Add `schematicId` to CityModel and `getSchematic` to CityRegistry**

Replace `mobile/lib/core/models/city_model.dart`:

```dart
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
```

- [ ] **Step 3: Create stub `sao_paulo_schematic.dart`**

```dart
// mobile/lib/core/data/sao_paulo_schematic.dart
//
// SETUP REQUIRED: Before filling in station coordinates, call
//   GET /api/lines  (with São Paulo city header)
// to get the real station IDs from the backend. Replace the
// placeholder IDs (101, 102, …) with actual IDs.
//
// Canvas size: 1000 x 800 logical pixels.
// Origin (0,0) = top-left. X increases right, Y increases down.
// Use the official Metrô SP + CPTM map as visual reference:
//   https://www.metro.sp.gov.br/sua-viagem/rede-metro-cptm/mapa-da-rede.aspx

import 'package:flutter/material.dart';
import '../models/schematic_model.dart';

// ─── Line 1 – Azul (Blue) ──────────────────────────────────────────
// Runs roughly north-south through the city center.
// NOTE: count MUST match the number of SchematicStation entries for L1 below.
const _l1StationIds = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117];

// ─── Line 2 – Verde (Green) ────────────────────────────────────────
// Runs roughly east-west.
const _l2StationIds = [201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212];

// ─── Line 3 – Vermelha (Red) ───────────────────────────────────────
// Runs east-west, longer than L2.
const _l3StationIds = [301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318];

// ─── Line 4 – Amarela (Yellow) ─────────────────────────────────────
const _l4StationIds = [401, 402, 403, 404, 405, 406];

// ─── Line 5 – Lilás (Lilac) ────────────────────────────────────────
const _l5StationIds = [501, 502, 503, 504, 505, 506, 507, 508, 509, 510];

const TransitSchematic saoPauloSchematic = TransitSchematic(
  canvasSize: Size(1000, 800),
  lines: [
    SchematicLine(
      lineCode: 'L1',
      stationIds: _l1StationIds,
      points: [
        // Tucuruvi (north) → Jabaquara (south), vertical axis x≈380
        Offset(380, 40),
        Offset(380, 760),
      ],
    ),
    SchematicLine(
      lineCode: 'L2',
      stationIds: _l2StationIds,
      points: [
        // Vila Madalena (west) → Vila Prudente (east), roughly horizontal
        Offset(150, 400),
        Offset(850, 400),
      ],
    ),
    SchematicLine(
      lineCode: 'L3',
      stationIds: _l3StationIds,
      points: [
        // Palmeiras-Barra Funda (west) → Corinthians-Itaquera (east)
        Offset(120, 360),
        Offset(940, 360),
      ],
    ),
    SchematicLine(
      lineCode: 'L4',
      stationIds: _l4StationIds,
      points: [
        // Luz → Butantã, diagonal
        Offset(390, 330),
        Offset(190, 480),
      ],
    ),
    SchematicLine(
      lineCode: 'L5',
      stationIds: _l5StationIds,
      points: [
        // Capão Redondo (south-west) → Chácara Klabin, diagonal
        Offset(160, 660),
        Offset(480, 450),
      ],
    ),
  ],
  stations: [
    // ── L1 stations (x≈380, evenly spaced vertically) ──
    SchematicStation(stationId: 101, position: Offset(380, 40),  capacity: 1500), // Tucuruvi
    SchematicStation(stationId: 102, position: Offset(380, 80)),
    SchematicStation(stationId: 103, position: Offset(380, 130)),
    SchematicStation(stationId: 104, position: Offset(380, 180)),
    SchematicStation(stationId: 105, position: Offset(380, 230)),
    SchematicStation(stationId: 106, position: Offset(380, 280), capacity: 2000), // Tietê (interchange)
    SchematicStation(stationId: 107, position: Offset(380, 320)),
    SchematicStation(stationId: 108, position: Offset(380, 360), capacity: 2500), // Sé (major interchange)
    SchematicStation(stationId: 109, position: Offset(380, 400), capacity: 2000), // Ana Rosa (interchange L2-L5)
    SchematicStation(stationId: 110, position: Offset(380, 440)),
    SchematicStation(stationId: 111, position: Offset(380, 490)),
    SchematicStation(stationId: 112, position: Offset(380, 540)),
    SchematicStation(stationId: 113, position: Offset(380, 590)),
    SchematicStation(stationId: 114, position: Offset(380, 640)),
    SchematicStation(stationId: 115, position: Offset(380, 690)),
    SchematicStation(stationId: 116, position: Offset(380, 730)),
    SchematicStation(stationId: 117, position: Offset(380, 760), capacity: 1500), // Jabaquara
    // (add remaining L1 stations as needed)

    // ── L2 stations (y≈400, evenly spaced horizontally) ──
    SchematicStation(stationId: 201, position: Offset(150, 400), capacity: 1200), // Vila Madalena
    SchematicStation(stationId: 202, position: Offset(210, 400)),
    SchematicStation(stationId: 203, position: Offset(260, 400)),
    SchematicStation(stationId: 204, position: Offset(310, 400), capacity: 1800), // Consolação
    SchematicStation(stationId: 205, position: Offset(380, 400), capacity: 2000), // Ana Rosa (interchange with L1)
    SchematicStation(stationId: 206, position: Offset(440, 400), capacity: 2500), // Paraíso
    SchematicStation(stationId: 207, position: Offset(510, 400)),
    SchematicStation(stationId: 208, position: Offset(580, 400)),
    SchematicStation(stationId: 209, position: Offset(650, 400)),
    SchematicStation(stationId: 210, position: Offset(720, 400)),
    SchematicStation(stationId: 211, position: Offset(790, 400)),
    SchematicStation(stationId: 212, position: Offset(850, 400), capacity: 1200), // Vila Prudente

    // ── L3 stations (y≈360, full east-west span) ──
    SchematicStation(stationId: 301, position: Offset(120, 360), capacity: 1500),
    SchematicStation(stationId: 302, position: Offset(180, 360)),
    SchematicStation(stationId: 303, position: Offset(240, 360)),
    SchematicStation(stationId: 304, position: Offset(300, 360)),
    SchematicStation(stationId: 305, position: Offset(360, 360), capacity: 2000), // Palmeiras-Barra Funda
    SchematicStation(stationId: 306, position: Offset(390, 330), capacity: 3000), // Luz (major interchange)
    SchematicStation(stationId: 307, position: Offset(440, 360), capacity: 2500), // Sé (interchange with L1)
    SchematicStation(stationId: 308, position: Offset(500, 360)),
    SchematicStation(stationId: 309, position: Offset(570, 360)),
    SchematicStation(stationId: 310, position: Offset(640, 360)),
    SchematicStation(stationId: 311, position: Offset(700, 360)),
    SchematicStation(stationId: 312, position: Offset(760, 360)),
    SchematicStation(stationId: 313, position: Offset(820, 360)),
    SchematicStation(stationId: 314, position: Offset(875, 360)),
    SchematicStation(stationId: 315, position: Offset(940, 360), capacity: 1200), // Corinthians-Itaquera

    // ── L4 stations (diagonal, 6 stations) ──
    SchematicStation(stationId: 401, position: Offset(390, 330), capacity: 3000), // Luz (shared with L3)
    SchematicStation(stationId: 402, position: Offset(360, 370)),
    SchematicStation(stationId: 403, position: Offset(320, 400)),
    SchematicStation(stationId: 404, position: Offset(270, 430)),
    SchematicStation(stationId: 405, position: Offset(230, 460)),
    SchematicStation(stationId: 406, position: Offset(190, 480), capacity: 1200), // Butantã

    // ── L5 stations (south-west diagonal) ──
    SchematicStation(stationId: 501, position: Offset(160, 660), capacity: 1000), // Capão Redondo
    SchematicStation(stationId: 502, position: Offset(210, 630)),
    SchematicStation(stationId: 503, position: Offset(260, 600)),
    SchematicStation(stationId: 504, position: Offset(310, 570)),
    SchematicStation(stationId: 505, position: Offset(350, 540)),
    SchematicStation(stationId: 506, position: Offset(390, 510)),
    SchematicStation(stationId: 507, position: Offset(420, 490)),
    SchematicStation(stationId: 508, position: Offset(450, 470)),
    SchematicStation(stationId: 509, position: Offset(465, 460)),
    SchematicStation(stationId: 510, position: Offset(480, 450), capacity: 1500), // Chácara Klabin
  ],
);
```

- [ ] **Step 4: Verify compile**

```bash
cd mobile && flutter analyze lib/
```
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/services/api_service.dart mobile/lib/core/models/city_model.dart mobile/lib/core/data/sao_paulo_schematic.dart
git commit -m "feat: add getStationArrivals, schematic support in CityRegistry, SP schematic stub"
```

---

## Chunk 2: Providers

### Task 6: transitMapProvider

**Files:**
- Create: `mobile/lib/core/providers/transit_map_provider.dart`
- Create: `mobile/test/core/providers/transit_map_provider_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// mobile/test/core/providers/transit_map_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/providers/transit_map_provider.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/models/city_model.dart';

// Fake notifier that starts with a pre-seeded city.
class _FakeCityNotifier extends SelectedCityNotifier {
  final CityModel? _seed;
  _FakeCityNotifier(this._seed);
  @override
  void _init() {} // skip Hive access
  @override
  CityModel? get state => _seed;
}

void main() {
  test('transitMapProvider returns schematic for São Paulo', () async {
    final spCity = CityRegistry.findById('sao-paulo-sp');
    final container = ProviderContainer(
      overrides: [
        selectedCityProvider.overrideWith((_) => SelectedCityNotifier()..state = spCity),
      ],
    );
    addTearDown(container.dispose);

    final schematic = await container.read(transitMapProvider.future);
    expect(schematic, isNotNull);
    expect(schematic!.stations, isNotEmpty);
  });

  test('transitMapProvider returns null for city without schematic', () async {
    final cwbCity = CityRegistry.findById('curitiba-pr');
    final container = ProviderContainer(
      overrides: [
        selectedCityProvider.overrideWith((_) => SelectedCityNotifier()..state = cwbCity),
      ],
    );
    addTearDown(container.dispose);

    final schematic = await container.read(transitMapProvider.future);
    expect(schematic, isNull);
  });
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
cd mobile && flutter test test/core/providers/transit_map_provider_test.dart
```

- [ ] **Step 3: Create `transit_map_provider.dart`**

```dart
// mobile/lib/core/providers/transit_map_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../models/schematic_model.dart';
import 'city_provider.dart'; // selectedCityProvider lives here

// lineZoomProvider: null = overview mode, non-null = line code being zoomed.
final lineZoomProvider = StateProvider<String?>((ref) => null);

final transitMapProvider = FutureProvider<TransitSchematic?>((ref) async {
  // selectedCityProvider is a StateNotifierProvider<SelectedCityNotifier, CityModel?>
  final city = ref.watch(selectedCityProvider);
  if (city == null) return null;
  return CityRegistry.getSchematic(city.id); // returns null, never throws
});
```

- [ ] **Step 4: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/core/providers/transit_map_provider_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/providers/transit_map_provider.dart mobile/test/core/providers/transit_map_provider_test.dart
git commit -m "feat: add transitMapProvider and lineZoomProvider"
```

---

### Task 7: TrainEstimator + trainEstimateProvider

**Files:**
- Create: `mobile/lib/features/transit_map/train_estimator.dart`
- Create: `mobile/lib/core/providers/train_estimate_provider.dart`
- Create: `mobile/test/features/transit_map/train_estimator_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// mobile/test/features/transit_map/train_estimator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/features/transit_map/train_estimator.dart';

void main() {
  group('TrainEstimator', () {
    late TrainEstimator estimator;

    setUp(() {
      estimator = TrainEstimator(stationIds: [1, 2, 3, 4]);
    });

    test('returns null when buffer has fewer than 2 snapshots per station', () {
      // Only one update — not enough to detect trend
      estimator.addSnapshot(stationId: 1, density: 0.8);
      estimator.addSnapshot(stationId: 2, density: 0.3);
      expect(estimator.estimate(), isNull);
    });

    test('returns estimate when density decreases at A and increases at B', () {
      // Station 2: density decreasing (train just left)
      estimator.addSnapshot(stationId: 2, density: 0.9);
      estimator.addSnapshot(stationId: 2, density: 0.7);
      estimator.addSnapshot(stationId: 2, density: 0.5);
      // Station 3: density increasing (train approaching)
      estimator.addSnapshot(stationId: 3, density: 0.2);
      estimator.addSnapshot(stationId: 3, density: 0.4);
      estimator.addSnapshot(stationId: 3, density: 0.6);

      final result = estimator.estimate();
      expect(result, isNotNull);
      expect(result!.betweenStationIds, [2, 3]);
      expect(result.confidence, greaterThanOrEqualTo(0.4));
    });

    test('returns null when confidence < 0.4', () {
      // Small density changes — low confidence
      estimator.addSnapshot(stationId: 1, density: 0.5);
      estimator.addSnapshot(stationId: 1, density: 0.48);
      estimator.addSnapshot(stationId: 2, density: 0.5);
      estimator.addSnapshot(stationId: 2, density: 0.52);

      final result = estimator.estimate();
      // confidence = min(0.02, 0.02) * 2 = 0.04 < 0.4
      expect(result, isNull);
    });

    test('buffer caps at 3 snapshots per station (oldest dropped)', () {
      for (int i = 0; i < 5; i++) {
        estimator.addSnapshot(stationId: 1, density: i * 0.1);
      }
      // Only last 3 kept
      expect(estimator.bufferLengthForStation(1), 3);
    });
  });
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
cd mobile && flutter test test/features/transit_map/train_estimator_test.dart
```

- [ ] **Step 3: Create `train_estimator.dart`**

```dart
// mobile/lib/features/transit_map/train_estimator.dart

class TrainEstimate {
  final List<int> betweenStationIds; // [stationA, stationB]
  final double confidence;           // 0.0–1.0
  final bool isEstimated;            // always true for crowd-based

  const TrainEstimate({
    required this.betweenStationIds,
    required this.confidence,
    this.isEstimated = true,
  });
}

class TrainEstimator {
  final List<int> stationIds;
  final int bufferSize;

  // stationId → list of recent density values (newest last)
  final Map<int, List<double>> _buffer = {};

  TrainEstimator({required this.stationIds, this.bufferSize = 3});

  void addSnapshot({required int stationId, required double density}) {
    _buffer.putIfAbsent(stationId, () => []).add(density);
    if (_buffer[stationId]!.length > bufferSize) {
      _buffer[stationId]!.removeAt(0);
    }
  }

  /// Returns best estimate or null if confidence < 0.4.
  TrainEstimate? estimate() {
    TrainEstimate? best;

    for (int i = 0; i < stationIds.length - 1; i++) {
      final idA = stationIds[i];
      final idB = stationIds[i + 1];
      final bufA = _buffer[idA];
      final bufB = _buffer[idB];

      if (bufA == null || bufA.length < 2) continue;
      if (bufB == null || bufB.length < 2) continue;

      final deltaA = bufA.first - bufA.last; // positive = decreasing
      final deltaB = bufB.last - bufB.first; // positive = increasing

      if (deltaA > 0 && deltaB > 0) {
        final confidence = (deltaA < deltaB ? deltaA : deltaB) * 2;
        if (confidence >= 0.4) {
          if (best == null || confidence > best.confidence) {
            best = TrainEstimate(
              betweenStationIds: [idA, idB],
              confidence: confidence.clamp(0.0, 1.0),
            );
          }
        }
      }
    }

    return best;
  }

  int bufferLengthForStation(int id) => _buffer[id]?.length ?? 0;
}
```

- [ ] **Step 4: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/features/transit_map/train_estimator_test.dart
```

- [ ] **Step 5: Create `train_estimate_provider.dart`**

```dart
// mobile/lib/core/providers/train_estimate_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/signalr_provider.dart';
import '../../features/transit_map/train_estimator.dart';

/// Family key: ordered stationIds list from LineModel.stationIds.
///
/// IMPORTANT: Riverpod uses reference equality for List keys.
/// Always pass `lineModel.stationIds!` (a stable reference from the provider),
/// never an inline list literal. Use `trainEstimateProvider(line.stationIds!)`.
final trainEstimateProvider = StreamProvider.family<TrainEstimate?, List<int>>(
  (ref, stationIds) async* {
    final estimator = TrainEstimator(stationIds: stationIds);

    // Use ref.read to get the stream — NOT ref.watch.
    // ref.watch inside a StreamProvider body would restart the stream
    // (and reset the estimator buffer) on every SignalR update.
    await for (final crowdState in ref.read(signalRProvider.notifier).stream) {
      for (final entry in crowdState.entries) {
        estimator.addSnapshot(stationId: entry.key, density: entry.value.density);
      }
      yield estimator.estimate();
    }
  },
);
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/transit_map/train_estimator.dart mobile/lib/core/providers/train_estimate_provider.dart mobile/test/features/transit_map/train_estimator_test.dart
git commit -m "feat: add TrainEstimator and trainEstimateProvider (crowd-based)"
```

---

### Task 8: stationArrivalsProvider

**Files:**
- Create: `mobile/lib/core/providers/station_arrivals_provider.dart`
- Create: `mobile/test/core/providers/station_arrivals_provider_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// mobile/test/core/providers/station_arrivals_provider_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/station_arrivals_model.dart';
import 'package:trilho/core/providers/station_arrivals_provider.dart';
import 'package:trilho/core/providers/app_providers.dart';
import 'package:trilho/core/services/api_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([ApiService])
import 'station_arrivals_provider_test.mocks.dart';

void main() {
  test('returns arrivals from API when successful', () async {
    final mockApi = MockApiService();
    final fakeArrivals = StationArrivals(
      stationId: 1,
      directions: [
        DirectionArrivals(
          terminus: 'Jabaquara',
          arrivals: [const ArrivalTime(estimatedMinutes: 3, isEstimated: false)],
        ),
      ],
    );

    when(mockApi.getStationArrivals(1)).thenAnswer((_) async => fakeArrivals);

    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(mockApi)],
    );
    addTearDown(container.dispose);

    final result = await container.read(stationArrivalsProvider(1).future);
    expect(result.directions.length, 1);
    expect(result.directions[0].terminus, 'Jabaquara');
  });

  test('returns unavailable when API returns 404', () async {
    final mockApi = MockApiService();
    when(mockApi.getStationArrivals(1)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/stations/1/arrivals'),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(mockApi)],
    );
    addTearDown(container.dispose);

    final result = await container.read(stationArrivalsProvider(1).future);
    expect(result.directions, isEmpty);
  });
}
```

> **Note:** This test requires `mockito` + `build_runner`. Add to `pubspec.yaml` dev_dependencies if not present:
> ```yaml
> dev_dependencies:
>   mockito: ^5.4.4
>   build_runner: ^2.4.9
> ```
> Then run: `cd mobile && flutter pub get && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2: Run — verify FAIL**

```bash
cd mobile && flutter test test/core/providers/station_arrivals_provider_test.dart
```

- [ ] **Step 3: Create provider with fallback logic**

```dart
// mobile/lib/core/providers/station_arrivals_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station_arrivals_model.dart';
import '../models/line_model.dart';
import 'app_providers.dart';

/// Returns arrival predictions for [stationId].
/// Falls back to headway-computed data if backend returns 404.
/// Returns StationArrivals.unavailable() if no data can be computed.
final stationArrivalsProvider =
    FutureProvider.family<StationArrivals, int>((ref, stationId) async {
  final api = ref.watch(apiServiceProvider);

  try {
    return await api.getStationArrivals(stationId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) {
      return StationArrivals.unavailable(stationId: stationId);
    }
    rethrow;
  }
});
```

- [ ] **Step 4: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/core/providers/station_arrivals_provider_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/providers/station_arrivals_provider.dart mobile/test/core/providers/station_arrivals_provider_test.dart mobile/pubspec.yaml
git commit -m "feat: add stationArrivalsProvider with 404 fallback"
```

---

## Chunk 3: Transit Map Painter + Zoom Controller

### Task 9: TransitMapPainter

**Files:**
- Create: `mobile/lib/features/transit_map/transit_map_painter.dart`
- Create: `mobile/test/features/transit_map/transit_map_painter_test.dart`

- [ ] **Step 1: Create test directory**

```bash
mkdir -p mobile/test/features/transit_map
```

- [ ] **Step 2: Write failing tests**

```dart
// mobile/test/features/transit_map/transit_map_painter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/features/transit_map/transit_map_painter.dart';
import 'package:trilho/core/models/schematic_model.dart';

void main() {
  group('TransitMapPainter', () {
    const schematic = TransitSchematic(
      canvasSize: Size(1000, 800),
      lines: [
        SchematicLine(lineCode: 'L1', points: [Offset(100, 100), Offset(100, 400)], stationIds: [1, 2]),
      ],
      stations: [
        SchematicStation(stationId: 1, position: Offset(100, 100)),
        SchematicStation(stationId: 2, position: Offset(100, 400)),
      ],
    );

    test('shouldRepaint returns true when crowdState changes', () {
      final painter1 = TransitMapPainter(
        schematic: schematic,
        crowdState: const {},
        lineColors: const {'L1': Color(0xFF0000CD)},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
      );
      final painter2 = TransitMapPainter(
        schematic: schematic,
        crowdState: const {1: 0.8},
        lineColors: const {'L1': Color(0xFF0000CD)},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      final painter = TransitMapPainter(
        schematic: schematic,
        crowdState: const {},
        lineColors: const {'L1': Color(0xFF0000CD)},
        selectedLineCode: null,
        zoomProgress: 0.0,
        barProgress: 0.0,
        trainEstimate: null,
        trainPulse: 0.0,
      );
      expect(painter.shouldRepaint(painter), isFalse);
    });
  });
}
```

- [ ] **Step 3: Run — verify FAIL**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_painter_test.dart
```

- [ ] **Step 4: Create `transit_map_painter.dart`**

```dart
// mobile/lib/features/transit_map/transit_map_painter.dart
import 'package:flutter/material.dart';
import '../../core/models/schematic_model.dart';
import '../../core/models/station_arrivals_model.dart';
import '../transit_map/train_estimator.dart';

/// Renders the transit schematic: lines, stations, capacity bars, train icon.
///
/// All animation values (zoomProgress, barProgress, trainPulse) are passed
/// from the parent — this painter is purely functional.
class TransitMapPainter extends CustomPainter {
  final TransitSchematic schematic;
  final Map<int, double> crowdState;        // stationId → density 0.0–1.0
  final Map<String, Color> lineColors;      // lineCode → Color
  final String? selectedLineCode;           // null = overview
  final double zoomProgress;               // 0.0–1.0 (used for fade)
  final double barProgress;                // 0.0–1.0 (used for bar height)
  final TrainEstimate? trainEstimate;
  final double trainPulse;                 // 0.0–1.0 (sinusoidal pulse)

  const TransitMapPainter({
    required this.schematic,
    required this.crowdState,
    required this.lineColors,
    required this.selectedLineCode,
    required this.zoomProgress,
    required this.barProgress,
    required this.trainEstimate,
    required this.trainPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width  / schematic.canvasSize.width;
    final scaleY = size.height / schematic.canvasSize.height;

    // ── 1. Draw line polylines ──────────────────────────────────────
    for (final line in schematic.lines) {
      final isSelected = selectedLineCode == line.lineCode;
      final opacity = selectedLineCode == null
          ? 1.0
          : isSelected
              ? 1.0
              : 0.15 + (0.85 * (1.0 - zoomProgress));

      final color = (lineColors[line.lineCode] ?? Colors.grey).withValues(alpha: opacity);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 4.0 * scaleX
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < line.points.length; i++) {
        final p = Offset(line.points[i].dx * scaleX, line.points[i].dy * scaleY);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    // ── 2. Draw station dots + labels + capacity bars ───────────────
    for (final station in schematic.stations) {
      final pos = Offset(station.position.dx * scaleX, station.position.dy * scaleY);
      final density = crowdState[station.stationId] ?? 0.0;
      final dotColor = _colorForDensity(density);

      final isOnSelectedLine = selectedLineCode != null &&
          schematic.stationsForLine(selectedLineCode!).any((s) => s.stationId == station.stationId);
      final dotOpacity = selectedLineCode == null
          ? 1.0
          : isOnSelectedLine
              ? 1.0
              : 0.20 + (0.80 * (1.0 - zoomProgress));

      // Dot
      canvas.drawCircle(
        pos,
        6.0 * scaleX,
        Paint()..color = dotColor.withValues(alpha: dotOpacity),
      );
      canvas.drawCircle(
        pos,
        6.0 * scaleX,
        Paint()
          ..color = Colors.white.withValues(alpha: dotOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Capacity bar (only when zoomed into the line this station belongs to)
      if (isOnSelectedLine && barProgress > 0) {
        const barWidth = 5.0;
        const maxBarHeight = 24.0;
        final barHeight = maxBarHeight * density * barProgress * scaleY;
        final barX = pos.dx + 10.0 * scaleX;
        final barY = pos.dy + (maxBarHeight * scaleY) / 2;

        // Background
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY - maxBarHeight * scaleY, barWidth * scaleX, maxBarHeight * scaleY),
            const Radius.circular(2),
          ),
          Paint()..color = dotColor.withValues(alpha: 0.15),
        );
        // Fill
        if (barHeight > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(barX, barY - barHeight, barWidth * scaleX, barHeight),
              const Radius.circular(2),
            ),
            Paint()..color = dotColor.withValues(alpha: dotOpacity),
          );
        }
      }
    }

    // ── 3. Draw train icon (when estimate available + zoomed) ────────
    if (trainEstimate != null && selectedLineCode != null && barProgress > 0) {
      final ids = trainEstimate!.betweenStationIds;
      final stA = schematic.stationById(ids[0]);
      final stB = ids.length > 1 ? schematic.stationById(ids[1]) : null;

      if (stA != null) {
        final posA = Offset(stA.position.dx * scaleX, stA.position.dy * scaleY);
        final posB = stB != null
            ? Offset(stB.position.dx * scaleX, stB.position.dy * scaleY)
            : posA;
        final trainPos = Offset.lerp(posA, posB, 0.5)!;

        final pulseScale = 1.0 + 0.15 * trainPulse;
        final iconPaint = Paint()
          ..color = Colors.blue.shade700.withValues(alpha: barProgress)
          ..style = PaintingStyle.fill;

        // Pulse ring
        canvas.drawCircle(
          trainPos,
          14.0 * scaleX * pulseScale,
          Paint()
            ..color = Colors.blue.shade700.withValues(alpha: 0.3 * barProgress)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        // Icon background
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: trainPos, width: 22 * scaleX, height: 16 * scaleY),
            const Radius.circular(4),
          ),
          iconPaint,
        );

        // Dashed border if estimated
        if (trainEstimate!.isEstimated) {
          _drawDashedRect(canvas, trainPos, 22 * scaleX, 16 * scaleY, scaleX, Colors.lightBlue.shade200.withValues(alpha: barProgress));
        }

        // Train symbol (text painter)
        final tp = TextPainter(
          text: const TextSpan(text: '🚆', style: TextStyle(fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, trainPos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _drawDashedRect(Canvas canvas, Offset center, double w, double h, double scale, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const dashLen = 4.0;
    const gap = 3.0;
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    _drawDashedPath(canvas, rect, paint, dashLen, gap);
  }

  void _drawDashedPath(Canvas canvas, Rect rect, Paint paint, double dashLen, double gap) {
    final path = Path()..addRect(rect);
    final metrics = path.computeMetrics().first;
    double dist = 0;
    while (dist < metrics.length) {
      canvas.drawPath(
        metrics.extractPath(dist, dist + dashLen),
        paint,
      );
      dist += dashLen + gap;
    }
  }

  Color _colorForDensity(double density) {
    if (density < 0.35) return Colors.green;
    if (density < 0.60) return Colors.amber.shade700;
    if (density < 0.80) return Colors.orange;
    return Colors.red;
  }

  @override
  bool shouldRepaint(TransitMapPainter old) =>
      old.crowdState != crowdState ||
      old.selectedLineCode != selectedLineCode ||
      old.zoomProgress != zoomProgress ||
      old.barProgress != barProgress ||
      old.trainEstimate != trainEstimate ||
      old.trainPulse != trainPulse;
}
```

- [ ] **Step 5: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_painter_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_painter.dart mobile/test/features/transit_map/transit_map_painter_test.dart
git commit -m "feat: add TransitMapPainter with lines, stations, capacity bars, train icon"
```

---

### Task 10: LineZoomController

**Files:**
- Create: `mobile/lib/features/transit_map/line_zoom_controller.dart`

This class is not independently testable (it wraps `AnimationController` and `TransformationController` which require a `TickerProvider` and widget context). It is covered by the integration test in Chunk 5.

- [ ] **Step 1: Create `line_zoom_controller.dart`**

```dart
// mobile/lib/features/transit_map/line_zoom_controller.dart
import 'package:flutter/material.dart';
import '../../core/models/schematic_model.dart';

/// Orchestrates the multi-step line zoom animation.
///
/// Owned by TransitMapScreen (TickerProviderStateMixin).
/// Call [zoomIn] / [zoomOut] / [switchLine] to drive the animation.
class LineZoomController {
  final AnimationController _ctrl;
  final TransformationController _transform;
  final Size canvasSize;

  // Current tween stored as instance var so the single listener can reference it.
  Matrix4Tween? _currentTween;

  // Pulse controller — nullable, initialized lazily via initPulse.
  AnimationController? _pulseCtrl;

  LineZoomController({
    required TickerProvider vsync,
    required TransformationController transformController,
    required this.canvasSize,
  })  : _ctrl = AnimationController(vsync: vsync),
        _transform = transformController {
    // Single persistent listener — no accumulation risk.
    _ctrl.addListener(() {
      if (_currentTween != null) {
        _transform.value = _currentTween!.evaluate(_ctrl);
      }
    });
  }

  Animation<double> get fadeProgress =>
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.31, curve: Curves.easeIn));

  Animation<double> get barProgress =>
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.46, 1.0, curve: Curves.easeOut));

  Animation<double> get trainPulse =>
      _pulseCtrl ?? const AlwaysStoppedAnimation(0.0);

  void initPulse(TickerProvider vsync) {
    _pulseCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  /// Zoom into [lineCode]. Animates: fade (0–400ms) → camera (600ms) → bars (800ms).
  Future<void> zoomIn(String lineCode, TransitSchematic schematic, Size screenSize) async {
    final stations = schematic.stationsForLine(lineCode);
    if (stations.isEmpty) return;

    _ctrl.duration = const Duration(milliseconds: 1300);
    final bbox = _boundingBox(stations, schematic.canvasSize, screenSize);
    _prepareCameraTween(bbox);
    await _ctrl.animateTo(1.0, curve: Curves.linear);
  }

  Future<void> zoomOut() async {
    _ctrl.duration = const Duration(milliseconds: 800);
    _prepareCameraTween(null);
    await _ctrl.animateBack(0.0, curve: Curves.easeInOut);
  }

  Future<void> switchLine(String newCode, TransitSchematic schematic, Size screenSize) async {
    await zoomOut();
    await zoomIn(newCode, schematic, screenSize);
  }

  void _prepareCameraTween(Rect? targetRect) {
    final begin = _transform.value;
    final Matrix4 end;

    if (targetRect == null) {
      end = Matrix4.identity();
    } else {
      final scaleX = 1.0 / targetRect.width;
      final scaleY = 1.0 / targetRect.height;
      final scale = (scaleX < scaleY ? scaleX : scaleY);
      end = Matrix4.identity()
        ..scale(scale)
        ..translate(-targetRect.left, -targetRect.top);
    }

    _currentTween = Matrix4Tween(begin: begin, end: end);
  }

  Rect _boundingBox(List<SchematicStation> stations, Size canvas, Size screen) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final s in stations) {
      final nx = s.position.dx / canvas.width;
      final ny = s.position.dy / canvas.height;
      if (nx < minX) minX = nx;
      if (ny < minY) minY = ny;
      if (nx > maxX) maxX = nx;
      if (ny > maxY) maxY = ny;
    }

    const padding = 0.20;
    return Rect.fromLTRB(
      (minX - padding).clamp(0.0, 1.0),
      (minY - padding).clamp(0.0, 1.0),
      (maxX + padding).clamp(0.0, 1.0),
      (maxY + padding).clamp(0.0, 1.0),
    );
  }

  void dispose() {
    _ctrl.dispose();
    _pulseCtrl?.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/features/transit_map/line_zoom_controller.dart
git commit -m "feat: add LineZoomController for multi-step map zoom animation"
```

---

## Chunk 4: TransitMapScreen

### Task 11: TransitMapScreen widget

**Files:**
- Create: `mobile/lib/features/transit_map/transit_map_screen.dart`
- Create: `mobile/test/features/transit_map/transit_map_screen_test.dart`

- [ ] **Step 1: Ensure test directory exists**

```bash
mkdir -p mobile/test/features/transit_map
```

- [ ] **Step 2: Write failing widget tests**

```dart
// mobile/test/features/transit_map/transit_map_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/schematic_model.dart';
import 'package:trilho/core/models/line_model.dart';
import 'package:trilho/core/providers/transit_map_provider.dart';
import 'package:trilho/core/providers/signalr_provider.dart';
import 'package:trilho/features/transit_map/transit_map_screen.dart';

void main() {
  testWidgets('shows loading state while schematic loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transitMapProvider.overrideWith((ref) => Future.delayed(const Duration(seconds: 10))),
          signalRProvider.overrideWith((ref) => SignalRNotifier()),
        ],
        child: const MaterialApp(home: TransitMapScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows "em breve" banner when schematic is null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transitMapProvider.overrideWith((ref) => Future.value(null)),
          signalRProvider.overrideWith((ref) => SignalRNotifier()),
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
        ],
        child: const MaterialApp(home: TransitMapScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
```

- [ ] **Step 3: Run — verify FAIL**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart
```

- [ ] **Step 4: Create `transit_map_screen.dart`**

```dart
// mobile/lib/features/transit_map/transit_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/line_model.dart';
import '../../core/models/schematic_model.dart';
import '../../core/providers/lines_provider.dart';
import '../../core/providers/signalr_provider.dart';
import '../../core/providers/transit_map_provider.dart';
import '../../core/providers/train_estimate_provider.dart';
import '../../core/widgets/app_error.dart';
import '../../core/widgets/app_loading.dart';
import 'transit_map_painter.dart';
import 'line_zoom_controller.dart';

class TransitMapScreen extends ConsumerStatefulWidget {
  const TransitMapScreen({super.key});

  @override
  ConsumerState<TransitMapScreen> createState() => _TransitMapScreenState();
}

class _TransitMapScreenState extends ConsumerState<TransitMapScreen>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformCtrl;
  LineZoomController? _zoomCtrl;
  String? _activeLineCode;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _transformCtrl = TransformationController();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _zoomCtrl?.dispose();
    super.dispose();
  }

  void _onLineTapped(String lineCode, TransitSchematic schematic) async {
    if (_isSwitching) return;

    if (_activeLineCode == lineCode) {
      // Deselect
      setState(() => _isSwitching = true);
      await _zoomCtrl!.zoomOut();
      if (mounted) {
        ref.read(lineZoomProvider.notifier).state = null;
        setState(() { _activeLineCode = null; _isSwitching = false; });
      }
    } else if (_activeLineCode != null) {
      // Switch line
      setState(() => _isSwitching = true);
      await _zoomCtrl!.switchLine(lineCode, schematic, context.size ?? const Size(400, 700));
      if (mounted) {
        ref.read(lineZoomProvider.notifier).state = lineCode;
        setState(() { _activeLineCode = lineCode; _isSwitching = false; });
      }
    } else {
      // Zoom in
      _ensureZoomController(schematic);
      setState(() => _isSwitching = true);
      ref.read(lineZoomProvider.notifier).state = lineCode;
      await _zoomCtrl!.zoomIn(lineCode, schematic, context.size ?? const Size(400, 700));
      if (mounted) setState(() { _activeLineCode = lineCode; _isSwitching = false; });
    }
  }

  void _ensureZoomController(TransitSchematic schematic) {
    _zoomCtrl ??= LineZoomController(
      vsync: this,
      transformController: _transformCtrl,
      canvasSize: schematic.canvasSize,
    )..initPulse(this);
  }

  @override
  Widget build(BuildContext context) {
    final schematicAsync = ref.watch(transitMapProvider);
    final linesAsync     = ref.watch(linesProvider);
    final crowdState     = ref.watch(signalRProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(selectedCityProvider)?.name ?? 'Trilho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: schematicAsync.when(
        loading: () => const AppLoading.spinner(),
        error: (e, _) => AppError(
          message: 'Não foi possível carregar o mapa',
          onRetry: () => ref.invalidate(transitMapProvider),
        ),
        data: (schematic) {
          if (schematic == null) return _buildNoSchematic(linesAsync);
          return _buildMap(schematic, crowdState, linesAsync);
        },
      ),
    );
  }

  Widget _buildMap(
    TransitSchematic schematic,
    Map<int, SignalRCrowdEntry> crowdState,
    AsyncValue<List<LineModel>> linesAsync,
  ) {
    final densityMap = crowdState.map((k, v) => MapEntry(k, v.density));
    final lineColors = linesAsync.valueOrNull?.fold<Map<String, Color>>(
          {},
          (map, l) => map..[l.code] = Color(l.colorValue),
        ) ??
        {};

    // Get train estimate if a line is zoomed
    final stationIds = _activeLineCode != null
        ? (linesAsync.valueOrNull
                ?.where((l) => l.code == _activeLineCode)
                .firstOrNull
                ?.stationIds ??
            [])
        : <int>[];
    final trainEstimate = stationIds.isNotEmpty
        ? ref.watch(trainEstimateProvider(stationIds)).valueOrNull
        : null;

    final zoomProgress = _zoomCtrl?.fadeProgress.value ?? 0.0;
    final barProgress  = _zoomCtrl?.barProgress.value ?? 0.0;
    final trainPulse   = _zoomCtrl?.trainPulse.value ?? 0.0;

    return Column(
      children: [
        _buildLineChips(linesAsync, schematic),
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.5,
            maxScale: 8.0,
            child: AnimatedBuilder(
              animation: _transformCtrl,
              builder: (ctx, _) => CustomPaint(
                painter: TransitMapPainter(
                  schematic: schematic,
                  crowdState: densityMap,
                  lineColors: lineColors,
                  selectedLineCode: _activeLineCode,
                  zoomProgress: zoomProgress,
                  barProgress: barProgress,
                  trainEstimate: trainEstimate,
                  trainPulse: trainPulse,
                ),
                size: schematic.canvasSize,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChips(AsyncValue<List<LineModel>> linesAsync, TransitSchematic schematic) {
    return linesAsync.when(
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox(height: 48),
      data: (lines) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: lines.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final line  = lines[i];
            final color = Color(line.colorValue);
            final isSelected = _activeLineCode == line.code;

            return ActionChip(
              backgroundColor: isSelected
                  ? color.withValues(alpha: 0.25)
                  : color.withValues(alpha: 0.12),
              side: BorderSide(color: color, width: isSelected ? 2.0 : 1.5),
              label: Text(
                line.code,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              onPressed: _isSwitching ? null : () => _onLineTapped(line.code, schematic),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoSchematic(AsyncValue<List<LineModel>> linesAsync) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.amber.shade100,
          padding: const EdgeInsets.all(12),
          child: const Text(
            'Mapa esquemático em breve para esta cidade',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.brown),
          ),
        ),
        Expanded(
          child: linesAsync.when(
            loading: () => const AppLoading.spinner(),
            error: (e, _) => const AppError(message: 'Não foi possível carregar as linhas'),
            data: (lines) => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lines.length,
              itemBuilder: (ctx, i) {
                final line  = lines[i];
                final color = Color(line.colorValue);
                return ListTile(
                  leading: CircleAvatar(backgroundColor: color, radius: 14),
                  title: Text(line.name),
                  subtitle: Text(line.currentStatus),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_screen.dart mobile/test/features/transit_map/transit_map_screen_test.dart
git commit -m "feat: add TransitMapScreen with schematic painter and line zoom"
```

---

## Chunk 5: Station Detail Redesign

### Task 12: Redesign StationDetailScreen

**Files:**
- Modify: `mobile/lib/features/station_detail/station_detail_screen.dart`
- Create: `mobile/test/features/transit_map/station_detail_redesign_test.dart`

- [ ] **Step 1: Ensure test directory exists**

```bash
mkdir -p mobile/test/features/station_detail
```

- [ ] **Step 2: Write failing tests**

```dart
// mobile/test/features/station_detail/station_detail_redesign_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/crowd_model.dart';
import 'package:trilho/core/models/station_arrivals_model.dart';
import 'package:trilho/core/providers/crowd_provider.dart';
import 'package:trilho/core/providers/station_arrivals_provider.dart';
import 'package:trilho/core/providers/usage_provider.dart';
import 'package:trilho/core/models/usage_model.dart';
import 'package:trilho/features/station_detail/station_detail_screen.dart';

void main() {
  final fakeCrowd = CrowdModel(
    stationId: 1,
    stationName: 'Paraíso',
    density: 0.65,
    densityLevel: 'High',
    source: 'Test',
    capturedAt: DateTime.now(),
    history: [],
  );

  final fakeArrivals = StationArrivals(
    stationId: 1,
    directions: [
      DirectionArrivals(
        terminus: 'Jabaquara',
        arrivals: [
          const ArrivalTime(estimatedMinutes: 2, isEstimated: false),
          const ArrivalTime(estimatedMinutes: 8, isEstimated: false),
        ],
      ),
      DirectionArrivals(
        terminus: 'Tucuruvi',
        arrivals: [
          const ArrivalTime(estimatedMinutes: 5, isEstimated: true),
        ],
      ),
    ],
  );

  testWidgets('shows people estimate card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usageProvider.overrideWith((ref) => Stream.value(UsageModel(queriesUsed: 0, queriesLimit: 3, isPremium: false, isAnonymous: false))),
          crowdProvider(1).overrideWith((ref) => Future.value(fakeCrowd)),
          stationArrivalsProvider(1).overrideWith((ref) => Future.value(fakeArrivals)),
        ],
        child: const MaterialApp(home: StationDetailScreen(stationId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('pessoas'), findsOneWidget);
  });

  testWidgets('shows both direction cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usageProvider.overrideWith((ref) => Stream.value(UsageModel(queriesUsed: 0, queriesLimit: 3, isPremium: false, isAnonymous: false))),
          crowdProvider(1).overrideWith((ref) => Future.value(fakeCrowd)),
          stationArrivalsProvider(1).overrideWith((ref) => Future.value(fakeArrivals)),
        ],
        child: const MaterialApp(home: StationDetailScreen(stationId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('→ Jabaquara'), findsOneWidget);
    expect(find.text('← Tucuruvi'), findsOneWidget);
  });

  testWidgets('shows "Dados indisponíveis" when arrivals empty', (tester) async {
    final noArrivals = StationArrivals.unavailable(stationId: 1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usageProvider.overrideWith((ref) => Stream.value(UsageModel(queriesUsed: 0, queriesLimit: 3, isPremium: false, isAnonymous: false))),
          crowdProvider(1).overrideWith((ref) => Future.value(fakeCrowd)),
          stationArrivalsProvider(1).overrideWith((ref) => Future.value(noArrivals)),
        ],
        child: const MaterialApp(home: StationDetailScreen(stationId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('indispon'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run — verify FAIL**

```bash
cd mobile && flutter test test/features/station_detail/station_detail_redesign_test.dart
```

- [ ] **Step 4: Rewrite `station_detail_screen.dart`**

Replace the entire file with:

```dart
// mobile/lib/features/station_detail/station_detail_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/models/station_arrivals_model.dart';
import '../../core/models/city_model.dart';
import '../../core/providers/crowd_provider.dart';
import '../../core/providers/usage_provider.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/station_arrivals_provider.dart';
import '../../core/services/admob_service.dart';
import '../../core/widgets/app_error.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_theme_constants.dart';
import '../station_detail/crowd_chart.dart';

class StationDetailScreen extends ConsumerStatefulWidget {
  final int stationId;
  const StationDetailScreen({super.key, required this.stationId});

  @override
  ConsumerState<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends ConsumerState<StationDetailScreen>
    with SingleTickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  late AnimationController _countCtrl;
  late Animation<double> _countAnim;
  double _lastDensity = 0.0;

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _countAnim = CurvedAnimation(parent: _countCtrl, curve: Curves.easeOut);
    _init();
  }

  Future<void> _init() async {
    final tracker  = ref.read(usageTrackerProvider);
    final anon     = await tracker.isAnonymous();
    final canQuery = await tracker.canQuery();
    if (!canQuery) return;

    await tracker.recordQuery();
    if (anon) {
      await AdMobService.showAnonymousQueryAd();
    } else {
      await AdMobService.showInterstitial();
    }
    _loadBanner();
  }

  void _loadBanner() {
    if (kIsWeb) return;
    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerLoaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  void _startCountUp(double density) {
    if ((density - _lastDensity).abs() > 0.01) {
      _lastDensity = density;
      _countCtrl.forward(from: 0.0);
    }
  }

  int _estimatePeople(double density, int stationId) {
    final city = ref.read(selectedCityProvider);
    final schematic = city != null ? CityRegistry.getSchematic(city.id) : null;
    final capacity = schematic?.stationById(stationId)?.capacity ?? 1200;
    return (density * capacity).round();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(usageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estação')),
      body: usageAsync.when(
        loading: () => const AppLoading.spinner(),
        error: (e, _) => const AppError(message: 'Não foi possível verificar seu acesso'),
        data: (usage) =>
            usage.canQuery ? _buildDetail() : _buildGate(context, usage.isAnonymous),
      ),
    );
  }

  Widget _buildDetail() {
    final crowdAsync    = ref.watch(crowdProvider(widget.stationId));
    final arrivalsAsync = ref.watch(stationArrivalsProvider(widget.stationId));

    return fadeSwitch(crowdAsync.when(
      loading: () => const AppLoading.spinner(key: ValueKey('loading')),
      error: (e, _) => AppError(
        message: 'Não foi possível carregar a lotação',
        onRetry: () => ref.invalidate(crowdProvider(widget.stationId)),
      ),
      data: (crowd) {
        _startCountUp(crowd.density);
        final color    = _colorForLevel(crowd.densityLevel);
        final estimate = _estimatePeople(crowd.density, widget.stationId);

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── People estimate card ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Column(children: [
                      AnimatedBuilder(
                        animation: _countAnim,
                        builder: (_, __) {
                          final displayCount = (estimate * _countAnim.value).round();
                          return Text(
                            '~$displayCount pessoas',
                            style: TextStyle(
                              color: color,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: crowd.density,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.2),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(crowd.density * 100).toStringAsFixed(0)}% — ${_labelForLevel(crowd.densityLevel)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // ── Direction cards ──────────────────────────────
                  Text('Próximos trens',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildDirectionCards(arrivalsAsync),

                  const SizedBox(height: 24),

                  // ── 3h history ────────────────────────────────────
                  if (crowd.history.isNotEmpty) ...[
                    Text('Últimas 3 horas',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(height: 160, child: CrowdChart(history: crowd.history)),
                    const SizedBox(height: 8),
                  ],

                  Text(
                    'Fonte: ${crowd.source} • ${_formatTime(crowd.capturedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // ── Banner ad ────────────────────────────────────────────
            if (_bannerLoaded && _bannerAd != null)
              SafeArea(
                top: false,
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
          ],
        );
      },
    ));
  }

  Widget _buildDirectionCards(AsyncValue<StationArrivals> arrivalsAsync) {
    return arrivalsAsync.when(
      loading: () => Row(
        children: [
          Expanded(child: _shimmerCard()),
          const SizedBox(width: 8),
          Expanded(child: _shimmerCard()),
        ],
      ),
      error: (_, __) => const Center(
        child: Text('Dados indisponíveis', style: TextStyle(color: Colors.grey)),
      ),
      data: (arrivals) {
        if (arrivals.directions.isEmpty) {
          return const Center(
            child: Text('Dados indisponíveis', style: TextStyle(color: Colors.grey)),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: arrivals.directions.asMap().entries.map((e) {
            final isFirst = e.key == 0;
            final dir = e.value;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: isFirst ? 4 : 0, left: isFirst ? 0 : 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isFirst ? '→' : '←'} ${dir.terminus}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    ...dir.arrivals.take(3).map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Text('🚆 ', style: TextStyle(fontSize: 13)),
                              Text(
                                '${a.isEstimated ? '~' : ''}${a.estimatedMinutes} min',
                                style: TextStyle(
                                  fontWeight: a == dir.arrivals.first
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: a == dir.arrivals.first
                                      ? _arrivalColor(a.estimatedMinutes)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _shimmerCard() => Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
        ),
      );

  // ── Helpers ──────────────────────────────────────────────────────

  Color _arrivalColor(int minutes) {
    if (minutes <= 2) return Colors.green;
    if (minutes <= 5) return Colors.orange;
    return Colors.grey;
  }

  Color _colorForLevel(String level) => switch (level) {
        'Low'    => Colors.green,
        'Medium' => Colors.amber.shade700,
        'High'   => Colors.orange,
        'Packed' => Colors.red,
        _        => Colors.grey,
      };

  String _labelForLevel(String level) => switch (level) {
        'Low'    => 'Tranquilo',
        'Medium' => 'Moderado',
        'High'   => 'Cheio',
        'Packed' => 'Lotado',
        _        => '—',
      };

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    return 'há ${diff.inHours}h';
  }

  // _buildGate kept from original (no changes needed)
  Widget _buildGate(BuildContext context, bool isAnonymous) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(isAnonymous ? Icons.login_rounded : Icons.lock_outline_rounded, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              isAnonymous ? 'Suas 5 consultas gratuitas acabaram' : 'Limite diário atingido',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton.icon(
                icon: Icon(isAnonymous ? Icons.login_rounded : Icons.star_rounded),
                label: Text(isAnonymous ? 'Criar conta / Entrar' : 'Ver Planos Premium'),
                onPressed: () => context.push(isAnonymous ? '/login' : '/paywall'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests — verify they PASS**

```bash
cd mobile && flutter test test/features/station_detail/station_detail_redesign_test.dart
```

- [ ] **Step 6: Run full test suite**

```bash
cd mobile && flutter test
```
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/station_detail/station_detail_screen.dart mobile/test/features/station_detail/station_detail_redesign_test.dart
git commit -m "feat: redesign StationDetailScreen with direction cards, people estimate, count-up animation"
```

---

## Chunk 6: Routing + Cleanup

### Task 13: Update router + remove old screens

**Files:**
- Modify: `mobile/lib/router.dart`
- Delete: `mobile/lib/features/map/map_screen.dart`
- Delete: `mobile/lib/features/line_detail/line_detail_screen.dart`

- [ ] **Step 1: Update `router.dart`**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/transit_map/transit_map_screen.dart';
import 'features/station_detail/station_detail_screen.dart';
import 'features/paywall/paywall_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/subscription/subscription_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/email_auth_screen.dart';
import 'features/city_picker/welcome_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final box  = Hive.box('app_prefs');
    final isAuthed = box.get('auth_done') == 'true';
    final hasCity  = box.get('selected_city_id') != null;

    if (!isAuthed && path != '/login' && path != '/login/email') return '/login';
    if (isAuthed && !hasCity && path != '/welcome' && path != '/login' && path != '/login/email') return '/welcome';
    if (isAuthed && hasCity && (path == '/login' || path == '/welcome' || path == '/login/email')) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'map',
      builder: (ctx, state) => const TransitMapScreen(),
    ),
    GoRoute(
      path: '/station/:id',
      name: 'station_detail',
      pageBuilder: (ctx, state) => CustomTransitionPage(
        key: state.pageKey,
        child: StationDetailScreen(
          stationId: int.parse(state.pathParameters['id']!),
        ),
        transitionsBuilder: (ctx, animation, secondary, child) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/paywall',
      name: 'paywall',
      builder: (ctx, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (ctx, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/subscription',
      name: 'subscription',
      builder: (ctx, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (ctx, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/login/email',
      name: 'login_email',
      builder: (ctx, state) => const EmailAuthScreen(),
    ),
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (ctx, state) => const WelcomeScreen(),
    ),
  ],
);
```

- [ ] **Step 2: Delete old files**

```bash
rm "mobile/lib/features/map/map_screen.dart"
rm "mobile/lib/features/line_detail/line_detail_screen.dart"
```

If the `map/` and `line_detail/` directories are now empty, remove them:
```bash
rmdir "mobile/lib/features/map" 2>/dev/null || true
rmdir "mobile/lib/features/line_detail" 2>/dev/null || true
```

- [ ] **Step 3: Remove google_maps_flutter from pubspec.yaml**

In `mobile/pubspec.yaml`, remove this line:
```yaml
  google_maps_flutter: ^2.6.1
```

- [ ] **Step 4: Remove Google Maps API key from Android**

```bash
grep -n "geo.API_KEY\|MAPS_API_KEY" mobile/android/app/src/main/AndroidManifest.xml
```

Remove the matching `<meta-data>` line(s) from `AndroidManifest.xml`.

- [ ] **Step 5: Remove Google Maps from iOS AppDelegate**

```bash
grep -n "GMSServices" mobile/ios/Runner/AppDelegate.swift 2>/dev/null || echo "Not present — skip"
```

If found, delete that line from `AppDelegate.swift`.

- [ ] **Step 6: Run flutter pub get and analyze**

```bash
cd mobile && flutter pub get && flutter analyze lib/
```
Expected: No errors (warnings about unused imports from deleted files may appear — fix them).

- [ ] **Step 7: Run full test suite**

```bash
cd mobile && flutter test
```
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/router.dart mobile/pubspec.yaml \
  mobile/android/app/src/main/AndroidManifest.xml \
  mobile/ios/Runner/AppDelegate.swift 2>/dev/null || true
git commit -m "feat: wire TransitMapScreen to router, add slide-up transition for stations, remove google_maps_flutter"
```

---

### Task 14: Calibrate SP schematic with real station IDs

The schematic in `sao_paulo_schematic.dart` uses placeholder IDs. This task maps them to real backend IDs.

**Files:**
- Modify: `mobile/lib/core/data/sao_paulo_schematic.dart`

- [ ] **Step 1: Start the backend and query station IDs**

```bash
# In a separate terminal, start the backend:
cd backend && dotnet run

# Then query each line's status to get real station IDs:
curl http://localhost:5000/api/lines/L1/status | python3 -m json.tool | grep -E '"id"|"name"'
curl http://localhost:5000/api/lines/L2/status | python3 -m json.tool | grep -E '"id"|"name"'
curl http://localhost:5000/api/lines/L3/status | python3 -m json.tool | grep -E '"id"|"name"'
curl http://localhost:5000/api/lines/L4/status | python3 -m json.tool | grep -E '"id"|"name"'
curl http://localhost:5000/api/lines/L5/status | python3 -m json.tool | grep -E '"id"|"name"'
```

- [ ] **Step 2: Map placeholder IDs to real IDs in the schematic**

For each station, replace the placeholder `stationId` (101, 102, …) with the real ID from the API. Also update the `_l1StationIds`, `_l2StationIds`, etc. constant lists to match.

Example: if the API returns Tucuruvi as id=43, change:
```dart
// Before:
SchematicStation(stationId: 101, position: Offset(380, 40), capacity: 1500), // Tucuruvi
// After:
SchematicStation(stationId: 43, position: Offset(380, 40), capacity: 1500),  // Tucuruvi
```

- [ ] **Step 3: Verify the app renders all stations**

Run the app (`flutter run -d chrome` for quick iteration) and confirm:
- All lines appear on the schematic
- Tapping a chip zooms to that line
- Station dots appear at correct positions

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/core/data/sao_paulo_schematic.dart
git commit -m "feat: calibrate SP schematic with real backend station IDs"
```

---

## Summary of Files

| File | Action |
|---|---|
| `lib/core/models/schematic_model.dart` | Create |
| `lib/core/models/station_arrivals_model.dart` | Create |
| `lib/core/models/line_model.dart` | Modify (+3 nullable fields) |
| `lib/core/models/city_model.dart` | Modify (+schematicId, getSchematic) |
| `lib/core/data/sao_paulo_schematic.dart` | Create |
| `lib/core/providers/signalr_provider.dart` | Modify (state includes density) |
| `lib/core/providers/transit_map_provider.dart` | Create |
| `lib/core/providers/train_estimate_provider.dart` | Create |
| `lib/core/providers/station_arrivals_provider.dart` | Create |
| `lib/core/services/api_service.dart` | Modify (+getStationArrivals) |
| `lib/features/transit_map/transit_map_screen.dart` | Create |
| `lib/features/transit_map/transit_map_painter.dart` | Create |
| `lib/features/transit_map/line_zoom_controller.dart` | Create |
| `lib/features/transit_map/train_estimator.dart` | Create |
| `lib/features/station_detail/station_detail_screen.dart` | Rewrite |
| `lib/router.dart` | Rewrite |
| `lib/features/map/map_screen.dart` | **Delete** |
| `lib/features/line_detail/line_detail_screen.dart` | **Delete** |
| `pubspec.yaml` | Modify (remove google_maps_flutter) |

# Design Spec: Animated Transit Map Experience
**Date:** 2026-04-07
**Status:** Approved

---

## Overview

Replace the current Google Maps + empty markers screen with a fully animated **official transit schematic diagram** drawn via `CustomPainter`. The diagram is interactive: users can zoom into a specific line, see real-time crowd bars per station, see estimated train position, and tap a station for full arrival + occupancy details.

---

## 1. Architecture

### Rendering Engine

The main map is a `CustomPainter` (`TransitMapPainter`) wrapped in an `InteractiveViewer`. There is no Google Maps dependency in this feature. The existing `google_maps_flutter` dependency is removed from `pubspec.yaml`, along with its API key from `AndroidManifest.xml` and `AppDelegate.swift`.

Each city's line network is encoded as a `TransitSchematic` object stored statically in `CityRegistry` (client-side only — the backend does not return schematic coordinates). The painter receives the schematic data plus live crowd state and renders everything: lines, station dots, labels, capacity bars, and the train icon.

### Data sources

| Source | What changes |
|---|---|
| `GET /api/lines` | Unchanged |
| `GET /api/lines/{code}/status` | Add `headwaySeconds: int?`, `termini: List<String>` to response; client handles missing fields as nullable |
| `GET /api/stations/{id}/crowd` | Unchanged |
| SignalR `/hubs/crowd` | Unchanged; `CrowdUpdated` event carries `stationId` + `densityLevel` + `density` (float already present) |
| New: `GET /api/stations/{id}/arrivals` | Stub returns computed fallback; real integration is future work |

### LineDetailScreen fate

`LineDetailScreen` and the route `/line/:code` are **removed**. Their functionality (station list with density) is fully replaced by the in-map line zoom view. The `router.dart` route is deleted.

---

## 2. Data Models

### `TransitSchematic` (new, client-side in `CityRegistry`)

```dart
class TransitSchematic {
  final Size canvasSize;              // e.g., Size(1000, 800) — logical px
  final List<SchematicLine> lines;
  final List<SchematicStation> stations;
}

class SchematicLine {
  final String lineCode;              // matches LineModel.code
  final List<Offset> points;          // polyline vertices in canvas coords
}

class SchematicStation {
  final int stationId;                // matches StationModel.id
  final Offset position;             // canvas coordinates
  final int capacity;                 // peak capacity for people estimate
                                      // fallback: 1200 if not specified
}
```

### `StationModel` (modified)

Remove the proposed `x`, `y`, `capacity` additions. Schematic position and capacity come from `CityRegistry.schematic`, looked up by `stationId`. `StationModel` stays lean (id, name, densityLevel, density, lat, lng).

### `LineModel` (modified)

```dart
// New nullable fields (backend may not return them for all cities yet):
final List<String>? termini;          // e.g., ['Tucuruvi', 'Jabaquara']
final int? headwaySeconds;            // average interval between trains
final List<int>? stationIds;          // ordered station IDs for this line
```

All three fields are nullable. `fromJson` uses `?.cast<...>()` with null fallbacks.

### `StationCrowdSnapshot` (new, internal)

```dart
class StationCrowdSnapshot {
  final int stationId;
  final double density;       // 0.0–1.0
  final String densityLevel;  // 'Low' | 'Medium' | 'High' | 'Packed'
  final DateTime capturedAt;
}
```

Used internally by `TrainEstimator`. Built from SignalR `CrowdUpdated` events.

---

## 3. Screen: TransitMapScreen (replaces MapScreen)

### Layout

```
┌─────────────────────────────┐
│  AppBar: city name + settings│
├─────────────────────────────┤
│  Line filter chips (scrollable)│
├─────────────────────────────┤
│                             │
│   InteractiveViewer         │
│   TransformationController  │
│   └── CustomPaint           │
│       ├── Line polylines    │
│       ├── Station dots      │
│       ├── Station labels    │
│       ├── Capacity bars     │ ← visible only in line-zoom mode
│       └── Train icon        │ ← visible only in line-zoom mode
│                             │
└─────────────────────────────┘
```

### TransformationController + Riverpod integration

`lineZoomProvider` is a `StateProvider<String?>` (null = overview, non-null = line code).

In `TransitMapScreen`, a `ref.listen(lineZoomProvider, ...)` callback triggers the imperative animation on the `TransformationController`. The `TransitMapScreen` widget holds:
- A `TransformationController` (owned by the widget, disposed on unmount)
- An `AnimationController` for the line zoom transition (owned by the widget, uses `SingleTickerProviderStateMixin`)

When `lineZoomProvider` changes from null → code: `_startZoomIn(code)`.
When `lineZoomProvider` changes from code → null: `_startZoomOut()`.
When `lineZoomProvider` changes from code1 → code2: `_startZoomOut().then((_) => _startZoomIn(code2))` — sequential, not interrupted.

### Initial state

All lines drawn at full opacity. Station dots colored by current crowd level (`Low`=green, `Medium`=amber, `High`=orange, `Packed`=red). Capacity bars hidden. Tapping a line chip sets `lineZoomProvider`.

### Error / empty states

- `transitMapProvider` loading → `AppLoading` centered over map area
- `transitMapProvider` error → `AppError` with retry button
- `transitMapProvider` returns `null` (city has no schematic yet) → banner: "Mapa esquemático em breve para esta cidade" with a fallback list view of lines from `linesProvider`. (`CityRegistry.getSchematic` returns `null`, never throws, for unknown cities.)

---

## 4. Animation: Line Zoom

### Steps (sequential, total ~1.3s)

1. **Fade other lines** (400ms, `Curves.easeIn`): `TransitMapPainter` receives `selectedLineCode`. Non-selected lines render at `opacity: 0.15`. Station dots of non-selected lines at `opacity: 0.20`.

2. **Camera zoom** (600ms, `Curves.easeInOutCubic`): Compute bounding box of all stations in selected line from `SchematicStation.position`. Add 20% padding. Animate `TransformationController` using `Matrix4Tween`.

3. **Capacity bars fill** (800ms, staggered +50ms per station, `SpringSimulation(stiffness: 180, damping: 20)`): bars animate from height=0 → `density * maxBarHeight`. Bars are drawn by `TransitMapPainter` as vertical `RRect` next to each station dot.

4. **Train icon appear + pulse** (300ms fade + scale 0.5→1.0, then continuous 1.5s pulse loop, `Curves.easeOut`): appears at estimated position.

### Line switching (line A → line B while zoomed)

```
_startZoomOut() → await (800ms reverse) → lineZoomProvider = B → _startZoomIn(B)
```

Single `AnimationController` reversed then re-run. No interruption.

### Reverse (deselect)

Tapping selected chip → `lineZoomProvider = null` → reverse steps: train icon fades, bars collapse (400ms), camera zooms out (600ms), other lines fade back in (400ms).

---

## 5. Train Position Estimation

### Real API (future)

When `GET /api/lines/{code}/trains` exists, `TrainEstimateProvider` switches to that data source automatically. Response model: `TrainPosition(stationId: int, direction: String, timestamp: DateTime)`.

### Fallback — crowd-based estimation

`TrainEstimator` maintains a rolling buffer of the last 3 `StationCrowdSnapshot` per station (updated via SignalR). Algorithm:

```
For each consecutive pair (A, B) in line.stationIds:
  recentDensityA = buffer[A].last.density
  previousDensityA = buffer[A].first.density
  recentDensityB = buffer[B].last.density

  if recentDensityA < previousDensityA && recentDensityB > buffer[B].first.density:
    → train between A and B, confidence = min(delta_a, delta_b) * 2
```

`confidence < 0.4` → train icon hidden. `confidence >= 0.4` → show with dashed border + tooltip "Posição estimada".

**SignalR → snapshot mapping:** The existing `CrowdUpdated` event already carries `density` (float). `trainEstimateProvider` listens to `signalRProvider` and builds `StationCrowdSnapshot` from each event.

---

## 6. Screen: StationDetailScreen (redesign)

### Ads / paywall gate — unchanged

The existing usage gate (`canQuery`), AdMob banner, and paywall redirect are **kept** and integrated into the new layout. The gate check happens in `initState` (same as current). The banner ad renders at the bottom of the screen (below the 3h history chart), guarded by `!kIsWeb`.

### Layout

```
┌─────────────────────────────┐
│  AppBar: name + line badge + density badge │
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │  ~620 pessoas           ││  ← count-up animation (600ms)
│  │  ████████░░  85%        ││  ← AnimatedContainer (500ms)
│  └─────────────────────────┘│
├─────────────────────────────┤
│  "Próximos trens"           │
│  ┌──────────┐ ┌──────────┐  │
│  │→ Jabaquara│ │← Tucuruvi│ │  ← Tab row if >2 directions
│  │🚆 2 min  │ │🚆 4 min  │ │
│  │🚆 8 min  │ │🚆 10 min │ │
│  │🚆 14 min │ │🚆 16 min │ │
│  └──────────┘ └──────────┘  │
├─────────────────────────────┤
│  Histórico 3h (LineChart)   │
├─────────────────────────────┤
│  [Banner ad — free users]   │
└─────────────────────────────┘
```

### Arrivals loading / error / empty states

- Loading: shimmer placeholder in each direction card (2 grey bars)
- Error fetching arrivals: show "Dados indisponíveis" inside direction card; rest of screen renders normally
- `headwaySeconds` is null: show "Consulte o app oficial" inside direction card
- `termini` is null: direction cards show "Sentido →" / "Sentido ←" as generic labels

### Entry animation

GoRouter keeps the `/station/:id` route. The custom slide-up transition is implemented via `GoRouter`'s `pageBuilder` returning a `CustomTransitionPage` with a `SlideTransition` (begin: `Offset(0, 1)`, end: `Offset.zero`, 300ms, `Curves.easeOutCubic`).

### People estimate

`estimatedPeople = (density * capacity).round()` where `capacity` comes from `CityRegistry.schematic.stations` lookup by `stationId`. If the station has no schematic entry (city not yet mapped), fallback is `1200`.

### Directions

Sourced from `LineModel.termini`. If null, falls back to generic labels. If station is an interchange (on 2+ lines), a `SegmentedButton` at top lets user pick which line to see arrivals for.

---

## 7. New Providers

| Provider | Type | Return type | Purpose |
|---|---|---|---|
| `transitMapProvider` | `FutureProvider<TransitSchematic?>` | `TransitSchematic?` | Returns `CityRegistry.getSchematic(selectedCity.id)`. Returns `null` (not throws) when city has no schematic yet — triggers "em breve" banner in §3. No network call. |
| `lineZoomProvider` | `StateProvider<String?>` | `String?` | Currently zoomed line code |
| `trainEstimateProvider(lineCode)` | `StreamProvider<TrainEstimate?>` | `TrainEstimate?` | Emits from `TrainEstimator` listening on `signalRProvider` |
| `stationArrivalsProvider(stationId)` | `FutureProvider<StationArrivals>` | `StationArrivals` | Calls `api.getStationArrivals(id)`; fallback computed client-side if backend returns 404 |

---

## 8. New / Modified Files

### New files
- `lib/features/transit_map/transit_map_screen.dart` — main screen, owns controllers
- `lib/features/transit_map/transit_map_painter.dart` — `CustomPainter`
- `lib/features/transit_map/line_zoom_controller.dart` — animation orchestration
- `lib/features/transit_map/train_estimator.dart` — crowd-based train estimation
- `lib/core/models/schematic_model.dart` — `TransitSchematic`, `SchematicLine`, `SchematicStation`
- `lib/core/models/station_arrivals_model.dart` — `StationArrivals`, `ArrivalTime`
- `lib/core/providers/transit_map_provider.dart`
- `lib/core/providers/train_estimate_provider.dart`
- `lib/core/providers/station_arrivals_provider.dart`
- `lib/core/data/sao_paulo_schematic.dart` — hard-coded SP metro schematic data

### Modified files
- `lib/features/station_detail/station_detail_screen.dart` — full redesign (keep ads/paywall)
- `lib/core/models/line_model.dart` — add nullable `termini`, `headwaySeconds`, `stationIds`
- `lib/core/models/city_model.dart` — add `schematicId: String` field; `CityRegistry` gains `getSchematic(id)`
- `lib/core/services/api_service.dart` — add `getStationArrivals(int id)`
- `lib/router.dart` — replace `/` with `TransitMapScreen`; remove `/line/:code`; update `StationDetailScreen` route to use `CustomTransitionPage`

### Removed files
- `lib/features/map/map_screen.dart`
- `lib/features/line_detail/line_detail_screen.dart`

### Dependency changes (`pubspec.yaml`)
- Remove: `google_maps_flutter`
- Remove API key from `android/app/src/main/AndroidManifest.xml` (MAPS_API_KEY meta-data)
- Remove API key from `ios/Runner/AppDelegate.swift` (GMSServices.provideAPIKey)
- Add: `flutter_svg: ^2.0.10` (optional, for future SVG asset support)

---

## 9. Animations Summary

| Element | Duration | Curve | Implementation |
|---|---|---|---|
| Other lines fade out | 400ms | easeIn | `TransitMapPainter` opacity param |
| Camera zoom to line | 600ms | easeInOutCubic | `Matrix4Tween` on `TransformationController` |
| Capacity bars fill | 800ms +50ms stagger | SpringSimulation | `CustomPainter` driven by animation value |
| Train icon appear | 300ms | easeOut | Scale 0.5→1 + fade |
| Train pulse loop | 1500ms repeat | sinusoidal | `AnimationController.repeat(reverse: true)` |
| Station detail slide up | 300ms | easeOutCubic | `CustomTransitionPage` in GoRouter |
| People count-up | 600ms | easeOut | `IntTween` |
| Progress bar fill | 500ms | easeInOut | `AnimatedContainer` height |

---

## 10. Out of Scope

- Real-time train position API integration (prepared, not implemented)
- Schematic data for cities other than São Paulo (Curitiba, Rio, etc.) — separate task
- Offline map caching
- Accessibility labels for `CustomPainter` elements — follow-up phase

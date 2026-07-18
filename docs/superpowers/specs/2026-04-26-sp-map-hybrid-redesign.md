# SP Transit Map Hybrid Redesign + Line Detail Screen

## Goal

Replace the programmatic schematic canvas for São Paulo with a hybrid image+vector approach — the official network PDF image as background, interactive vector overlay for line highlighting and station taps — and add a new LineDetailScreen accessible via a second tap on a selected line.

## Context

The current `TransitMapScreen` renders the SP network entirely via `CustomPaint` using hard-coded coordinates in `sao_paulo_schematic.dart`. The positions are approximate and don't match the official CPTM/Metro network map. The user wants "exact fidelity" to the PDF — achieved by using the official image as the background, with an interactive overlay on top.

---

## Architecture

### Hybrid rendering model

```
TransitMapScreen (body)
└── Stack
    ├── InteractiveViewer (pan/zoom, constrained: false)
    │   └── SizedBox(canvasSize)          ← sized to match image dimensions
    │       └── Stack
    │           ├── Image.asset(...)       ← official network map (background)
    │           └── CustomPaint(TransitMapPainter)  ← interactive overlay
    └── Positioned(top: 12) — line filter chips
```

The `Image.asset` renders the full official map. `TransitMapPainter` draws on top:
- A dark translucent overlay over the whole canvas when a line is selected
- The selected line's path redrawn bright on top of the overlay
- Station circles for the selected line (with capacity bars)
- Station tap hit areas for all lines (always active)
- Labels at high zoom

When no line is selected, the painter draws nothing visible — the image shows through entirely, including its printed legend.

### Coordinate calibration

`sao_paulo_schematic.dart` station positions and line points must be recalibrated so the overlay aligns with the image. The canvas size (`canvasSize`) stays at `Size(2400, 1800)` — the exported PNG is placed at that logical size. Station coordinates are updated to match the visual positions in the image. This is done once as a manual calibration task.

---

## Components

### 1. Image asset

- **File**: `mobile/assets/maps/sp_network.png`
- **Provided by**: user exports from `mapa-de-rede.pdf`
- **Recommended resolution**: 2400×1800 px minimum (match canvas size); 4800×3600 for retina
- **Declared in**: `pubspec.yaml` under `flutter.assets`

### 2. TransitMapPainter — updated

New parameter: `bool useImageBackground` (default `false` for backward compat).

Behavior when `useImageBackground: true`:
- **Skip**: background fill rect, line paths (image handles these)
- **Keep**: station circles, capacity bars, train icon, labels
- **Add**: when `selectedLineCode != null`:
  - Draw `Rect.largest` filled with `Colors.black.withOpacity(0.55)` — dark overlay
  - Redraw selected line path on top of overlay at full opacity + 1.15× stroke width
  - Draw station circles only for selected-line stations (others hidden under overlay)

Station tap hit detection is unchanged — uses `findStationAt` with the same schematic positions.

### 3. TransitMapScreen — updated

**Image layer**: inside `InteractiveViewer`, wrap content in a `Stack` — `Image.asset` at bottom, `CustomPaint` on top (same canvas size).

**Tap behavior change** — `_onLineTapped`:
- `_activeLineCode == null` → zoom in (existing)
- `_activeLineCode != lineCode` → switch line (existing)
- `_activeLineCode == lineCode` → **navigate to `/line/$lineCode`** (replaces the current zoom-out/deselect)

The "zoom out and deselect" behavior is removed for the line chips. Instead:
- Second tap on the active chip → open LineDetailScreen
- Back button on LineDetailScreen → returns to map with line still zoomed in

**`pubspec.yaml`**: add asset declaration for `assets/maps/`.

### 4. LineDetailScreen (new)

**Route**: `/line/:code`  
**File**: `mobile/lib/features/line_detail/line_detail_screen.dart`  
**Class**: `LineDetailScreen extends ConsumerWidget`, parameter `String lineCode`

**Sections** (top to bottom):

#### AppBar
- Background: `LinearGradient` using `LineColors.forLine(lineCode, brightness)`
- Title: `LineModel.name` (e.g. "Linha 3 – Vermelha")
- Subtitle: termini joined with "→" (from `LineModel.termini`); if null/empty, omit subtitle entirely
- Back: `context.pop()`

#### Status card
- Left border colored by status severity: green (normal), amber (partial), red (disrupted)
- `LineModel.currentStatus` as headline
- `LineModel.statusMessage` as body (if non-null)
- Timestamp: "Atualizado agora"

#### Info pills row (3 pills)
- **Intervalo**: `headwaySeconds ~/ 60` min — shows "–" if null
- **Estações**: `stationIds?.length ?? 0`; shows "–" if null
- **Extensão**: placeholder "– km" (not in current model; commented stub for future)

#### Alerts placeholder
```dart
// TODO: Alertas e notícias de operação — implementar depois
// Widget _buildAlerts() { ... }
```
Renders as a dashed-border card with "Em breve: alertas e notícias" text (visible but greyed out).

#### Stations list
- Header label "ESTAÇÕES"
- `ListView` of stations in line order (from `linesProvider` + `transitMapProvider`)
- Each row:
  - Colored dot (line color, larger for interchange)
  - Station name (bold for interchange)
  - Interchange badge: small colored dots for each connected line
  - Crowd bar: 40 px wide horizontal bar, color from `signalRProvider` density
- Tap on station row → `context.push('/station/$stationId')`

### 5. Router — updated

Add to `router.dart`:
```dart
GoRoute(
  path: '/line/:code',
  name: 'line_detail',
  pageBuilder: (ctx, state) => CustomTransitionPage(
    key: state.pageKey,
    child: LineDetailScreen(lineCode: state.pathParameters['code']!),
    transitionsBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 300),
  ),
),
```

---

## File Map

| Action | File |
|--------|------|
| Create | `mobile/assets/maps/sp_network.png` ← user provides |
| Modify | `mobile/pubspec.yaml` — add assets/maps/ |
| Modify | `mobile/lib/core/data/sao_paulo_schematic.dart` — recalibrate coordinates |
| Modify | `mobile/lib/features/transit_map/transit_map_painter.dart` — add `useImageBackground` |
| Modify | `mobile/lib/features/transit_map/transit_map_screen.dart` — image layer + tap behavior |
| Create | `mobile/lib/features/line_detail/line_detail_screen.dart` |
| Modify | `mobile/lib/router.dart` — add /line/:code |
| Create | `mobile/test/features/line_detail/line_detail_screen_test.dart` |
| Modify | `mobile/test/features/transit_map/transit_map_painter_test.dart` — update for new flag |

---

## Data Flow

```
linesProvider (List<LineModel>)
    ↓ lineCode → name, color, termini, headwaySeconds, stationIds
LineDetailScreen
    ↑ signalRProvider (Map<stationId, density>) → crowd bars
    ↑ transitMapProvider (TransitSchematic) → station names for list
```

---

## Error Handling

- `linesProvider` loading/error: show `AppLoading` / `AppError` (same pattern as other screens)
- Missing image asset: Flutter will throw at startup if declared in pubspec but file not present — fail fast
- `lineCode` not found in `linesProvider`: show "Linha não encontrada" empty state
- `headwaySeconds` null: show "–" in interval pill

---

## Testing

### `line_detail_screen_test.dart`
- Renders AppBar with line name and correct background color
- Shows "Operação Normal" when `currentStatus` is normal
- Shows interval pill from `headwaySeconds`
- Shows station list with correct count
- Tapping station row calls `context.push('/station/:id')`
- Shows alerts placeholder card

### `transit_map_painter_test.dart` (existing, extended)
- `useImageBackground: true` → `shouldRepaint` still works
- Dark overlay is painted when `selectedLineCode != null` and `useImageBackground: true`

### `transit_map_screen_test.dart` (existing, extended)
- Second tap on active line chip → navigation to `/line/:code`

---

## Out of Scope

- Alerts and news API integration (placeholder left in code)
- Line extension in km (not in current `LineModel`)
- Offline map caching
- Accessibility (screen reader) for map canvas

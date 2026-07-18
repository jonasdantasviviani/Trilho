# SP Map Hybrid Redesign + LineDetailScreen Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the SP transit map with a hybrid image+vector approach (official PDF map as background, interactive overlay for highlighting), and add a new LineDetailScreen accessible via second tap on a selected line.

**Architecture:** The `TransitMapScreen` renders a `Stack` inside `InteractiveViewer`: `Image.asset('assets/maps/sp_network.png')` as background, `CustomPaint(TransitMapPainter)` as interactive overlay. `TransitMapPainter` gains a `useImageBackground` flag — when true and a line is selected, it draws a dark overlay + redraws the selected line on top; when no line is selected it draws nothing (image shows through). A new `LineDetailScreen` opens on the second tap of an already-selected line chip.

**Tech Stack:** Flutter · Riverpod · GoRouter · CustomPaint · Image.asset

**Spec:** `docs/superpowers/specs/2026-04-26-sp-map-hybrid-redesign.md`

**Prerequisites:**
- Before Task 3, the user must export the PDF to `mobile/assets/maps/sp_network.png` (recommended ≥ 2400×1800 px). A placeholder file is created in Task 1 so the project compiles.
- Coordinate calibration (Task 6) happens after the real image is in place.

---

## Chunk 1: Asset setup + TransitMapPainter extension

### Task 1: Asset declaration + placeholder image

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/assets/maps/sp_network.png` (1×1 transparent PNG placeholder)

> No TDD here — this is infrastructure. Verify with `flutter pub get` and `flutter test`.

- [ ] **Step 1: Create assets/maps directory and placeholder PNG**

```bash
mkdir -p mobile/assets/maps
# Create a 1x1 transparent PNG using base64 (minimal valid PNG):
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > mobile/assets/maps/sp_network.png
```

Verify it exists: `ls -la mobile/assets/maps/sp_network.png`

- [ ] **Step 2: Declare the asset in pubspec.yaml**

In `mobile/pubspec.yaml`, find the `flutter.assets` section (currently has `- assets/images/`) and add `assets/maps/`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/maps/
```

- [ ] **Step 3: Verify the project still compiles**

```bash
cd mobile
flutter pub get
flutter test --no-pub 2>&1 | tail -5
```

Expected: all existing tests pass (166 tests, no failures).

- [ ] **Step 4: Commit**

```bash
git add mobile/pubspec.yaml mobile/assets/maps/sp_network.png
git commit -m "feat: add assets/maps/ declaration + placeholder sp_network.png"
```

---

### Task 2: TransitMapPainter — add `useImageBackground` flag

**Files:**
- Modify: `mobile/lib/features/transit_map/transit_map_painter.dart`
- Modify: `mobile/test/features/transit_map/transit_map_painter_test.dart`

The painter gains `useImageBackground: bool` (default `false`). When `true` and `selectedLineCode != null`, it draws a dark overlay over the full canvas then redraws the selected line on top. When `true` and no line selected, `paint()` returns early (image shows through). Background fill and line paths are skipped when `useImageBackground` is true.

- [ ] **Step 1: Write the failing tests**

Open `mobile/test/features/transit_map/transit_map_painter_test.dart` and add a new group after the existing `'TransitMapPainter shouldRepaint'` group:

```dart
  group('TransitMapPainter useImageBackground', () {
    const schematic = TransitSchematic(
      canvasSize: Size(100, 100),
      lines: [
        SchematicLine(
          lineCode: 'L1',
          points: [Offset(0, 0), Offset(100, 0)],
          stationIds: [],
        ),
      ],
      stations: [],
    );

    test('can be constructed with useImageBackground: true', () {
      expect(
        () => const TransitMapPainter(
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
          useImageBackground: true,
        ),
        returnsNormally,
      );
    });

    test('shouldRepaint returns true when useImageBackground changes', () {
      const p1 = TransitMapPainter(
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
        useImageBackground: false,
      );
      const p2 = TransitMapPainter(
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
        useImageBackground: true,
      );
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint returns false when useImageBackground unchanged', () {
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
        useImageBackground: true,
      );
      expect(p.shouldRepaint(p), isFalse);
    });
  });
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd mobile
flutter test test/features/transit_map/transit_map_painter_test.dart --no-pub
```

Expected: 3 new tests FAIL with `The named parameter 'useImageBackground' isn't defined`.

- [ ] **Step 3: Implement `useImageBackground` in TransitMapPainter**

In `mobile/lib/features/transit_map/transit_map_painter.dart`:

**3a. Add the field** — after `final double currentScale;`, add:

```dart
  final bool useImageBackground;  // true = PDF image is the background; painter draws overlay only
```

**3b. Update the constructor** — add `this.useImageBackground = false,` as the last parameter (with default so existing callers don't break):

```dart
  const TransitMapPainter({
    required this.schematic,
    required this.crowdState,
    required this.lineColors,
    required this.selectedLineCode,
    required this.zoomProgress,
    required this.barProgress,
    required this.trainEstimate,
    required this.trainPulse,
    required this.brightness,
    required this.currentScale,
    this.useImageBackground = false,
  });
```

**3c. Update `paint()`** — replace the beginning of the method (background fill + lines section) with:

```dart
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width  / schematic.canvasSize.width;
    final scaleY = size.height / schematic.canvasSize.height;

    if (useImageBackground) {
      // ── Image-background mode ─────────────────────────────────────────────
      if (selectedLineCode == null) return; // nothing to draw; image shows through

      // Dark overlay — fades in with zoomProgress
      final overlayOpacity = 0.55 * zoomProgress;
      if (overlayOpacity > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.black.withValues(alpha: overlayOpacity),
        );
      }

      // Redraw selected line on top of overlay
      final selectedLine = schematic.lines
          .where((l) => l.lineCode == selectedLineCode)
          .firstOrNull;
      if (selectedLine != null) {
        final rawColor = lineColors[selectedLine.lineCode] ?? Colors.grey;
        final baseColor = _isDark
            ? LineColors.forLine(selectedLine.lineCode, Brightness.dark)
            : rawColor;
        final paint = Paint()
          ..color = baseColor
          ..strokeWidth = 11.0 * scaleX
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        final path = Path();
        for (int i = 0; i < selectedLine.points.length; i++) {
          final p = Offset(
            selectedLine.points[i].dx * scaleX,
            selectedLine.points[i].dy * scaleY,
          );
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    } else {
      // ── Programmatic mode (original) ──────────────────────────────────────
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = _bgColor);

      // ── 1. Lines ──────────────────────────────────────────────────────────
      for (final line in schematic.lines) {
        final isSelected = selectedLineCode == line.lineCode;
        final opacity = selectedLineCode == null
            ? 1.0
            : isSelected ? 1.0 : 0.15 + (0.85 * (1.0 - zoomProgress));

        final rawColor = lineColors[line.lineCode] ?? Colors.grey;
        final baseColor = _isDark
            ? LineColors.forLine(line.lineCode, Brightness.dark)
            : rawColor;
        final color = baseColor.withValues(alpha: opacity);
        final isMetro = ['L1','L2','L3','L4','L5','L15'].contains(line.lineCode);
        final strokeWidth = (isMetro ? 10.0 : 8.0) * scaleX * (isSelected ? 1.15 : 1.0);

        final paint = Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final path = Path();
        for (int i = 0; i < line.points.length; i++) {
          final p = Offset(line.points[i].dx * scaleX, line.points[i].dy * scaleY);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // ── 2. Stations ───────────────────────────────────────────────────────────
```

**IMPORTANT:** Keep the rest of the existing `paint()` method unchanged (stations section, train icon, etc.). The only change is wrapping the background+lines in the `else` branch and adding the `if (useImageBackground)` branch at the top.

In the **stations section**, add a skip condition so hidden stations aren't drawn in image mode:

The painter already declares `isOnSelectedLine` inside the station loop. Add the guard **immediately after** that existing declaration (do **not** add a new declaration; do **not** delete anything):

```dart
      if (useImageBackground && selectedLineCode != null && !isOnSelectedLine) continue;
```

**3d. Update `shouldRepaint()`** — add `old.useImageBackground != useImageBackground` to the existing condition:

```dart
  @override
  bool shouldRepaint(TransitMapPainter old) =>
      old.crowdState != crowdState ||
      old.selectedLineCode != selectedLineCode ||
      old.zoomProgress != zoomProgress ||
      old.barProgress != barProgress ||
      old.trainEstimate != trainEstimate ||
      old.trainPulse != trainPulse ||
      old.lineColors != lineColors ||
      old.brightness != brightness ||
      old.currentScale != currentScale ||
      old.useImageBackground != useImageBackground;
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd mobile
flutter test test/features/transit_map/transit_map_painter_test.dart --no-pub
```

Expected: all tests PASS (existing + 3 new).

- [ ] **Step 5: Run full test suite to confirm no regression**

```bash
flutter test --no-pub 2>&1 | tail -5
```

Expected: all existing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_painter.dart \
        mobile/test/features/transit_map/transit_map_painter_test.dart
git commit -m "feat: add useImageBackground flag to TransitMapPainter"
```

---

## Chunk 2: TransitMapScreen + LineDetailScreen + Router

### Task 3: TransitMapScreen — image layer + second-tap navigation

**Files:**
- Modify: `mobile/lib/features/transit_map/transit_map_screen.dart`
- Modify: `mobile/test/features/transit_map/transit_map_screen_test.dart`

Two changes:
1. The `InteractiveViewer` child becomes a `Stack(image + overlay)`.
2. `_onLineTapped` — when the tapped line is already `_activeLineCode`, navigate to `/line/$lineCode` instead of zooming out.

- [ ] **Step 1: Write failing test for second-tap navigation**

Add to `mobile/test/features/transit_map/transit_map_screen_test.dart`:

First, add imports at the top if not already present:

```dart
import 'package:go_router/go_router.dart';
```

Then add the test at the bottom of `main()`:

```dart
  testWidgets('second tap on active line chip navigates to /line/:code', (tester) async {
    const schematic = TransitSchematic(
      canvasSize: Size(1000, 800),
      lines: [
        SchematicLine(
          lineCode: 'L1',
          points: [Offset(0, 0), Offset(1000, 0)],
          stationIds: [],
        ),
      ],
      stations: [],
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const TransitMapScreen()),
        GoRoute(
          path: '/line/:code',
          builder: (ctx, state) =>
              Scaffold(body: Text('line:${state.pathParameters["code"]}')),
        ),
        GoRoute(path: '/station/:id', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/settings', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/welcome', builder: (_, __) => const Scaffold()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transitMapProvider.overrideWith((ref) => Future.value(schematic)),
          signalRProvider.overrideWith((ref) => SignalRNotifier()),
          selectedCityProvider.overrideWith(
              (ref) => SelectedCityNotifier.skipHive()),
          // lineZoomProvider is StateProvider<String?> — defaults to null, explicit for clarity
          lineZoomProvider.overrideWith((ref) => null),
          linesProvider.overrideWith((ref) => Future.value([
                const LineModel(
                  id: 1,
                  code: 'L1',
                  name: 'Linha 1 – Azul',
                  type: 'metro',
                  colorHex: '0455A1',
                  currentStatus: 'Normal',
                ),
              ])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    // First tap — zoom in (sets _activeLineCode = 'L1')
    await tester.tap(find.text('● 1'));
    // Use pump with duration instead of pumpAndSettle to avoid hanging on
    // the repeating pulse animation started by initPulse().
    await tester.pump(const Duration(seconds: 2));

    // Second tap — should navigate to /line/L1
    await tester.tap(find.text('● 1'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('line:L1'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd mobile
flutter test test/features/transit_map/transit_map_screen_test.dart \
  --name "second tap on active line chip navigates" --no-pub
```

Expected: FAIL (currently second tap zooms out instead of navigating).

- [ ] **Step 3: Update `_onLineTapped` in TransitMapScreen**

In `mobile/lib/features/transit_map/transit_map_screen.dart`, replace the `_onLineTapped` method:

```dart
  void _onLineTapped(String lineCode, TransitSchematic schematic) async {
    if (_isSwitching) return;
    final screenSize = _bodySize;

    if (_activeLineCode == lineCode) {
      // Second tap on same line → navigate to line detail.
      // lineZoomProvider is intentionally NOT reset here — the spec says
      // "returns to map with line still zoomed in" after popping LineDetailScreen.
      if (mounted) context.push('/line/$lineCode');
    } else if (_activeLineCode != null) {
      // Switch to a different line
      setState(() => _isSwitching = true);
      await _zoomCtrl!.switchLine(lineCode, schematic, screenSize);
      if (mounted) {
        ref.read(lineZoomProvider.notifier).state = lineCode;
        setState(() {
          _activeLineCode = lineCode;
          _isSwitching = false;
        });
      }
    } else {
      // First tap — zoom in
      _ensureZoomController(schematic);
      setState(() => _isSwitching = true);
      ref.read(lineZoomProvider.notifier).state = lineCode;
      await _zoomCtrl!.zoomIn(lineCode, schematic, screenSize);
      if (mounted) {
        setState(() {
          _activeLineCode = lineCode;
          _isSwitching = false;
        });
      }
    }
  }
```

- [ ] **Step 4: Add image layer inside InteractiveViewer**

In `_buildMap`, find the `InteractiveViewer` child (currently `AnimatedBuilder → CustomPaint`). Replace it with a `Stack` wrapping the image and the overlay:

```dart
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.05,
                maxScale: 6.0,
                child: AnimatedBuilder(
                  animation: _transformCtrl,
                  builder: (ctx, _) => SizedBox(
                    width: schematic.canvasSize.width,
                    height: schematic.canvasSize.height,
                    child: Stack(
                      children: [
                        // ── Official network map image (background) ─────────
                        Positioned.fill(
                          child: Image.asset(
                            'assets/maps/sp_network.png',
                            fit: BoxFit.fill,
                            // Gracefully handles missing/placeholder image in tests
                            errorBuilder: (ctx, err, _) => ColoredBox(
                              color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                            ),
                          ),
                        ),
                        // ── Interactive overlay (highlight + stations) ──────
                        CustomPaint(
                          painter: TransitMapPainter(
                            schematic: schematic,
                            crowdState: densityMap,
                            lineColors: lineColors,
                            selectedLineCode: _activeLineCode,
                            zoomProgress: zoomProgress,
                            barProgress: barProgress,
                            trainEstimate: trainEstimate,
                            trainPulse: trainPulse,
                            brightness: brightness,
                            currentScale: _currentScale,
                            useImageBackground: true,
                          ),
                          size: schematic.canvasSize,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
```

Note: `isDark` is already a local variable in `_buildMap`. The `ColoredBox` fallback ensures the map still shows a background color when the placeholder PNG is loaded.

- [ ] **Step 5: Run all transit_map_screen tests**

```bash
cd mobile
flutter test test/features/transit_map/transit_map_screen_test.dart --no-pub
```

Expected: all tests PASS including the new navigation test.

- [ ] **Step 6: Run full suite**

```bash
flutter test --no-pub 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_screen.dart \
        mobile/test/features/transit_map/transit_map_screen_test.dart
git commit -m "feat: add image background layer + second-tap navigation to TransitMapScreen"
```

---

### Task 4: LineDetailScreen (new screen)

**Files:**
- Create: `mobile/lib/features/line_detail/line_detail_screen.dart`
- Create: `mobile/test/features/line_detail/line_detail_screen_test.dart`

- [ ] **Step 1: Create the test file first**

Create `mobile/test/features/line_detail/line_detail_screen_test.dart`:

```dart
// mobile/test/features/line_detail/line_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trilho/core/models/line_model.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/providers/lines_provider.dart';
import 'package:trilho/core/providers/signalr_provider.dart';
import 'package:trilho/core/providers/transit_map_provider.dart';
import 'package:trilho/features/line_detail/line_detail_screen.dart';

const _fakeL3 = LineModel(
  id: 3,
  code: 'L3',
  name: 'Linha 3 – Vermelha',
  type: 'metro',
  colorHex: 'EF4136',
  currentStatus: 'Operação Normal',
  statusMessage: null,
  termini: ['Palmeiras-Barra Funda', 'Corinthians-Itaquera'],
  headwaySeconds: 180,
  stationIds: [36, 37, 38],
);

Widget _buildSubject({
  List<LineModel> lines = const [_fakeL3],
  String lineCode = 'L3',
}) {
  final router = GoRouter(
    initialLocation: '/line/$lineCode',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/line/:code',
        builder: (ctx, state) =>
            LineDetailScreen(lineCode: state.pathParameters['code']!),
      ),
      GoRoute(path: '/station/:id', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      linesProvider.overrideWith((ref) => Future.value(lines)),
      signalRProvider.overrideWith((ref) => SignalRNotifier()),
      transitMapProvider.overrideWith((ref) => Future.value(null)),
      selectedCityProvider
          .overrideWith((_) => SelectedCityNotifier.skipHive()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows line name in AppBar', (tester) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();
    expect(find.text('Linha 3 – Vermelha'), findsOneWidget);
  });

  testWidgets('shows termini as subtitle in AppBar', (tester) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();
    expect(
      find.text('Palmeiras-Barra Funda → Corinthians-Itaquera'),
      findsOneWidget,
    );
  });

  testWidgets('shows status in status card', (tester) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();
    expect(find.text('Operação Normal'), findsOneWidget);
  });

  testWidgets('shows interval from headwaySeconds', (tester) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();
    expect(find.text('3 min'), findsOneWidget);
  });

  testWidgets('shows alerts placeholder', (tester) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();
    expect(find.textContaining('Alertas'), findsOneWidget);
  });

  testWidgets('shows not-found state for unknown lineCode', (tester) async {
    await tester.pumpWidget(_buildSubject(lines: const [], lineCode: 'L99'));
    await tester.pumpAndSettle();
    expect(find.text('Linha não encontrada'), findsOneWidget);
  });

  testWidgets('shows dash for null headwaySeconds', (tester) async {
    const lineNoHeadway = LineModel(
      id: 4,
      code: 'L4',
      name: 'Linha 4 – Amarela',
      type: 'metro',
      colorHex: 'FFD900',
      currentStatus: 'Normal',
      headwaySeconds: null,
    );
    await tester.pumpWidget(
      _buildSubject(lines: const [lineNoHeadway], lineCode: 'L4'),
    );
    await tester.pumpAndSettle();
    // Interval pill shows '–' when headwaySeconds is null
    expect(find.text('–'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd mobile
flutter test test/features/line_detail/line_detail_screen_test.dart --no-pub
```

Expected: FAIL — `Target of URI doesn't exist: 'package:trilho/features/line_detail/line_detail_screen.dart'`.

- [ ] **Step 3: Create the LineDetailScreen**

Create `mobile/lib/features/line_detail/line_detail_screen.dart`:

```dart
// mobile/lib/features/line_detail/line_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/line_model.dart';
import '../../core/models/schematic_model.dart';
import '../../core/providers/lines_provider.dart';
import '../../core/providers/signalr_provider.dart';
import '../../core/providers/transit_map_provider.dart';
import '../../core/utils/line_colors.dart';
import '../../core/widgets/app_colors.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_error.dart';
import '../../core/widgets/app_theme.dart';

class LineDetailScreen extends ConsumerWidget {
  final String lineCode;

  const LineDetailScreen({super.key, required this.lineCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linesAsync = ref.watch(linesProvider);
    final crowdState = ref.watch(signalRProvider);
    final schematicAsync = ref.watch(transitMapProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return linesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const AppLoading.spinner(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: const AppError(message: 'Não foi possível carregar a linha'),
      ),
      data: (lines) {
        final line = lines.where((l) => l.code == lineCode).firstOrNull;
        if (line == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => context.pop(),
              ),
              title: const Text('Linha'),
            ),
            body: const Center(child: Text('Linha não encontrada')),
          );
        }

        final lineColor = LineColors.forLine(lineCode, brightness);

        return Scaffold(
          backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
          appBar: AppBar(
            backgroundColor: lineColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Colors.white,
              ),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (line.termini != null && line.termini!.isNotEmpty)
                  Text(
                    line.termini!.join(' → '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(line, isDark),
              const SizedBox(height: 12),
              _buildInfoPills(line, isDark),
              const SizedBox(height: 12),
              _buildAlertsPlaceholder(isDark),
              const SizedBox(height: 12),
              _buildStationsSection(
                line,
                schematicAsync.valueOrNull,
                crowdState,
                context,
                isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(LineModel line, bool isDark) {
    final status = line.currentStatus.toLowerCase();
    final isNormal = status.contains('normal');
    final isPartial =
        status.contains('parcial') || status.contains('reduzida');
    final statusColor = isNormal
        ? AppColors.crowdLow
        : isPartial
            ? AppColors.crowdModerate
            : AppColors.danger;
    final bgColor =
        isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.currentStatus,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
                if (line.statusMessage != null)
                  Text(
                    line.statusMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecDark
                          : AppTheme.textSecLight,
                    ),
                  ),
                Text(
                  'Atualizado agora',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.textSecDark
                        : AppTheme.textSecLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            isNormal ? '✅' : isPartial ? '⚠️' : '🚨',
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPills(LineModel line, bool isDark) {
    final bg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textPrim =
        isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
    final textSec =
        isDark ? AppTheme.textSecDark : AppTheme.textSecLight;

    String interval = '–';
    if (line.headwaySeconds != null) {
      final mins = line.headwaySeconds! ~/ 60;
      interval = mins > 0 ? '$mins min' : '< 1 min';
    }
    final stationCount = line.stationIds?.length ?? 0;

    return Row(
      children: [
        _pill('Intervalo', interval, bg, textPrim, textSec),
        const SizedBox(width: 8),
        _pill(
          'Estações',
          stationCount > 0 ? '$stationCount' : '–',
          bg,
          textPrim,
          textSec,
        ),
        const SizedBox(width: 8),
        // Extensão not yet in LineModel — placeholder
        _pill('Extensão', '– km', bg, textPrim, textSec),
      ],
    );
  }

  Widget _pill(
    String label,
    String value,
    Color bg,
    Color textPrim,
    Color textSec,
  ) {
    return Expanded(
      child: Container(
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: textSec,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsPlaceholder(bool isDark) {
    // TODO: Alertas e notícias de operação — implementar depois
    // Widget _buildAlerts() { ... }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 16,
            color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
          ),
          const SizedBox(width: 8),
          Text(
            'Alertas e notícias — em breve',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsSection(
    LineModel line,
    TransitSchematic? schematic,
    Map<int, SignalRCrowdEntry> crowdState,
    BuildContext context,
    bool isDark,
  ) {
    if (schematic == null || line.stationIds == null) {
      return const SizedBox.shrink();
    }

    final stations = line.stationIds!
        .map((id) => schematic.stationById(id))
        .whereType<SchematicStation>()
        .toList();

    if (stations.isEmpty) return const SizedBox.shrink();

    final lineColor = LineColors.forLine(lineCode, Brightness.light);
    final bg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textPrim =
        isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
    final textSec =
        isDark ? AppTheme.textSecDark : AppTheme.textSecLight;
    final dividerColor =
        isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ESTAÇÕES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textSec,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: stations.asMap().entries.map((entry) {
              final i = entry.key;
              final station = entry.value;
              final density =
                  crowdState[station.stationId]?.density ?? 0.0;
              final isLast = i == stations.length - 1;
              final connectedLines = station.lineCodes
                  .where((c) => c != lineCode)
                  .toList();

              return InkWell(
                onTap: () =>
                    context.push('/station/${station.stationId}'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: dividerColor,
                              width: 0.8,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: station.isInterchange ? 12 : 10,
                        height: station.isInterchange ? 12 : 10,
                        decoration: BoxDecoration(
                          color: lineColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: station.isInterchange ? 2 : 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: station.isInterchange
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: textPrim,
                              ),
                            ),
                            if (connectedLines.isNotEmpty)
                              Text(
                                connectedLines.join(' · '),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textSec,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Crowd bar
                      SizedBox(
                        width: 44,
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: density.clamp(0.0, 1.0),
                            backgroundColor: dividerColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.forDensity(density),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd mobile
flutter test test/features/line_detail/line_detail_screen_test.dart --no-pub
```

Expected: all 7 tests PASS.

- [ ] **Step 5: Run full test suite**

```bash
flutter test --no-pub 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/line_detail/line_detail_screen.dart \
        mobile/test/features/line_detail/line_detail_screen_test.dart
git commit -m "feat: add LineDetailScreen with status, info pills, alerts placeholder, stations list"
```

---

### Task 5: Router — add `/line/:code` route

**Files:**
- Modify: `mobile/lib/router.dart`

> No separate test needed — navigation is already covered by the screen test in Task 3 (uses GoRouter inline). This task just wires the production router.

- [ ] **Step 1: Add the import and route to router.dart**

In `mobile/lib/router.dart`, add the import:

```dart
import 'features/line_detail/line_detail_screen.dart';
```

Then, inside `routes: [...]`, add after the `/station/:id` route:

```dart
    GoRoute(
      path: '/line/:code',
      name: 'line_detail',
      pageBuilder: (ctx, state) => CustomTransitionPage(
        key: state.pageKey,
        child: LineDetailScreen(
          lineCode: state.pathParameters['code']!,
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
```

- [ ] **Step 2: Run full test suite**

```bash
cd mobile
flutter test --no-pub 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/router.dart
git commit -m "feat: register /line/:code route for LineDetailScreen"
```

---

## Chunk 3: Coordinate calibration

### Task 6: Calibrate schematic coordinates to match the PNG

**Files:**
- Modify: `mobile/lib/core/data/sao_paulo_schematic.dart`
- Modify: `mobile/assets/maps/sp_network.png` (replace placeholder with real image)

> This task is manual — there are no automated tests for visual alignment. The goal is to make the interactive overlay (dark mask + selected line highlight + station tap zones) align with the exported PDF image.

**Prerequisites:** The user must have exported the PDF (`mapa-de-rede.pdf`, page 1) as a PNG file of at least 2400×1800 px. The canvas size stays at `Size(2400, 1800)`.

- [ ] **Step 1: Replace placeholder with real image**

Copy the exported PNG to `mobile/assets/maps/sp_network.png` (overwrite the placeholder).

**Important:** `canvasSize` in `sao_paulo_schematic.dart` is the **logical coordinate space** for the overlay painter — it is entirely independent of the PNG's pixel resolution. A higher-resolution PNG (e.g., 4800×3600) renders sharper but requires no coordinate changes. Do **not** change `canvasSize` to match the PNG pixel dimensions; that would break every station `Offset` in the file. Leave `canvasSize: Size(2400, 1800)` unchanged unless you deliberately re-map all coordinates.

- [ ] **Step 2: Run the app and visually compare**

```bash
cd mobile
flutter run
```

1. Select São Paulo
2. Tap a line chip to zoom in
3. Observe whether the dark overlay + highlighted line tracks the image underneath
4. Check that station tap zones (tapping a station dot) respond in roughly the right positions

- [ ] **Step 3: Calibrate station and line coordinates**

For each line in `sao_paulo_schematic.dart`, compare the `points` (polyline path) against the actual line trajectory visible in the PNG. Update each `Offset(x, y)` to match the visual position.

**Strategy**: Use the key interchanges as anchor points first (Luz, Sé, Brás, Palmeiras-Barra Funda, Pinheiros, Vila Prudente) since they appear on multiple lines and are easy to identify. Then adjust intermediate stations.

Example — if Luz station appears at pixel (1250, 820) in the 2400×1800 logical space:
```dart
SchematicStation(stationId: 9, name: 'Luz', position: Offset(1250, 820), ...),
```

Re-run the app after each batch of changes to verify alignment.

**Warning — duplicate station names:** Several stations share names at different IDs (e.g., "Osasco", "Suzano", "São Paulo-Morumbi" each appear under two different IDs on different lines). Always work by `stationId`, not by name, to avoid editing the wrong entry.

**Warning — off-canvas coordinates:** There are no automated bounds checks. A mistyped `Offset` will render silently off-screen. After finishing calibration, scan the file for any `dx < 0`, `dx > 2400`, `dy < 0`, or `dy > 1800` values before committing.

- [ ] **Step 4: Run full test suite to confirm calibration didn't break anything**

```bash
cd mobile
flutter test --no-pub 2>&1 | tail -5
```

Expected: all tests still pass (coordinate calibration has no automated tests — it only affects visual output).

- [ ] **Step 5: Commit**

```bash
git add mobile/assets/maps/sp_network.png \
        mobile/lib/core/data/sao_paulo_schematic.dart
git commit -m "feat: replace placeholder with official SP network map + calibrate schematic coordinates"
```

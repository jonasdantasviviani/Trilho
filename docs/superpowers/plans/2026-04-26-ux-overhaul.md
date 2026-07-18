# UX Overhaul — Bugs Funcionais + Polish + Redesign

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir três bugs funcionais (dark mode, tap em estações, tap em linha), aplicar tokens do design system no mapa e telas pós-login, e redesenhar visualmente a SubscriptionScreen.

**Architecture:** Abordagem cirúrgica — cada bug corrigido no exato arquivo onde vive. Dois `StateProvider`s novos em `app_providers.dart` centralizam estado compartilhado: `themeModeProvider` para o tema e `pendingLineSelectionProvider` para comunicação entre StationDetailScreen e TransitMapScreen. Persistência de tema via Hive (box `app_prefs` já aberto em `main()`).

**Tech Stack:** Flutter 3, Riverpod 2 (`StateProvider`), Hive Flutter (box `app_prefs`), GoRouter, flutter_test, `TransformationController.toScene()` para transformação de coordenadas.

---

## Chunk 1: Providers, Dark Mode, Painter Tokens

### Task 1: themeModeProvider + persistência no main

**Context:** `main.dart` tem `themeMode: ThemeMode.system` hardcoded. Hive `app_prefs` já está aberto antes de `runApp`. `TrilhoApp` já é `ConsumerStatefulWidget`.

**Files:**
- Modify: `mobile/lib/core/providers/app_providers.dart`
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/test/core/providers/theme_mode_provider_test.dart` (create)

- [ ] **Step 1: Escrever o teste que falha**

Criar `mobile/test/core/providers/theme_mode_provider_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/providers/app_providers.dart';

void main() {
  test('themeModeProvider default is ThemeMode.system', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('themeModeProvider can be overridden to ThemeMode.dark', () {
    final container = ProviderContainer(
      overrides: [themeModeProvider.overrideWith((ref) => ThemeMode.dark)],
    );
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('themeModeProvider state can be updated', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
```

- [ ] **Step 2: Rodar o teste e verificar que falha**

```bash
cd mobile && flutter test test/core/providers/theme_mode_provider_test.dart
```

Esperado: FAIL — `themeModeProvider` não existe ainda.

- [ ] **Step 3: Adicionar `themeModeProvider` em `app_providers.dart`**

Editar `mobile/lib/core/providers/app_providers.dart`. Adicionar no final do arquivo:

```dart
// Adicionar import no topo
import 'package:flutter/material.dart';

// Adicionar no final do arquivo:

/// Controls the app-wide theme mode. Persisted via Hive box 'app_prefs'.
/// Initialized in main() with the saved value (defaults to ThemeMode.system).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
```

- [ ] **Step 4: Rodar o teste e verificar que passa**

```bash
cd mobile && flutter test test/core/providers/theme_mode_provider_test.dart
```

Esperado: PASS (3 testes).

- [ ] **Step 5: Atualizar `main.dart` para ler Hive e wiring o provider**

Editar `mobile/lib/main.dart`. Substituir o bloco `runApp(const ProviderScope(child: TrilhoApp()));` e o método `build` de `_TrilhoAppState`:

```dart
// Em main(), substituir a linha runApp por:
  final box = Hive.box('app_prefs');
  final savedTheme = box.get('theme_mode') as String?;
  final initialTheme = savedTheme == 'dark'
      ? ThemeMode.dark
      : savedTheme == 'light'
          ? ThemeMode.light
          : ThemeMode.system;

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => initialTheme),
    ],
    child: const TrilhoApp(),
  ));
```

Adicionar import no topo de `main.dart`:
```dart
import 'core/providers/app_providers.dart';
```

Substituir o método `build` de `_TrilhoAppState`:
```dart
@override
Widget build(BuildContext context) {
  return MaterialApp.router(
    title: 'Trilho',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: router,
  );
}
```

- [ ] **Step 6: Verificar compilação**

```bash
cd mobile && flutter analyze lib/main.dart lib/core/providers/app_providers.dart
```

Esperado: sem erros.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/core/providers/app_providers.dart mobile/lib/main.dart mobile/test/core/providers/theme_mode_provider_test.dart
git commit -m "feat: add themeModeProvider with Hive persistence"
```

---

### Task 2: Dark mode switch funcional em SettingsScreen

**Context:** `settings_screen.dart` linha 74: `onChanged: (_) {}` — vazio. Adicionar persistência via `Hive.box('app_prefs').put(...)`. O `settings_screen_test.dart` já existe com dois testes.

**Files:**
- Modify: `mobile/lib/features/settings/settings_screen.dart`
- Modify: `mobile/test/features/settings/settings_screen_test.dart`

- [ ] **Step 1: Escrever o teste que falha**

Abrir `mobile/test/features/settings/settings_screen_test.dart` e adicionar ao final do `main()`:

```dart
  testWidgets('dark mode switch toggles themeModeProvider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Light mode — switch should show false (off)
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);

    // Tap the switch
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Provider should now be ThemeMode.dark
    final container = tester.element(find.byType(SettingsScreen)).read(themeModeProvider);
    expect(container, ThemeMode.dark);
  });
```

Adicionar imports no topo do test file:
```dart
import 'package:trilho/core/providers/app_providers.dart';
```

- [ ] **Step 2: Rodar e verificar que falha**

```bash
cd mobile && flutter test test/features/settings/settings_screen_test.dart
```

Esperado: FAIL — tap no switch não muda o provider.

- [ ] **Step 3: Implementar o switch funcional em `settings_screen.dart`**

Adicionar import no topo de `settings_screen.dart`:
```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers/app_providers.dart';
```

Localizar o `Switch` (dentro do `_settingRow` de dark mode, ~linha 74). O `onChanged: (_) {}` está dentro de `_card`. Substituir o widget `Switch`:

```dart
Switch(
  value: isDark,
  onChanged: (val) {
    final mode = val ? ThemeMode.dark : ThemeMode.light;
    ref.read(themeModeProvider.notifier).state = mode;
    Hive.box('app_prefs').put('theme_mode', val ? 'dark' : 'light');
  },
  activeThumbColor: isDark ? const Color(0xFF2979FF) : const Color(0xFF0455A1),
),
```

- [ ] **Step 4: Rodar e verificar que passa**

```bash
cd mobile && flutter test test/features/settings/settings_screen_test.dart
```

Esperado: PASS (3 testes).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/settings/settings_screen.dart mobile/test/features/settings/settings_screen_test.dart
git commit -m "fix: dark mode switch now toggles theme and persists via Hive"
```

---

### Task 3: TransitMapPainter — substituir cores hardcoded por AppTheme/AppColors

**Context:** `transit_map_painter.dart` tem getters privados `_bgColor`, `_labelColor`, `_tickColor`, `_ringColor`, `_nucleusColor`, `_nucleusBorderColor` e `_colorForDensity()` com hexcodes hardcoded. O `transit_map_painter_test.dart` já existe com testes de `shouldRepaint` e helpers estáticos. O `_drawTrainIcon` usa `Colors.blue.shade700`.

**Files:**
- Modify: `mobile/lib/features/transit_map/transit_map_painter.dart`
- Modify: `mobile/test/features/transit_map/transit_map_painter_test.dart`

- [ ] **Step 1: Escrever testes que falham**

Adicionar ao final do grupo `'TransitMapPainter constructor'` em `transit_map_painter_test.dart`:

```dart
  group('TransitMapPainter color tokens', () {
    const schematic = TransitSchematic(
      canvasSize: Size(100, 100), lines: [], stations: [],
    );
    const baseParams = (
      crowdState: <int, double>{},
      lineColors: <String, Color>{},
      selectedLineCode: null,
      zoomProgress: 0.0,
      barProgress: 0.0,
      trainEstimate: null,
      trainPulse: 0.0,
      currentScale: 1.0,
    );

    test('bgColor dark == AppTheme.bgDark', () {
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

    test('bgColor light == AppTheme.bgLight', () {
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
```

Adicionar import:
```dart
import 'package:trilho/core/widgets/app_theme.dart';
```

- [ ] **Step 2: Rodar e verificar que falha**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_painter_test.dart
```

Esperado: FAIL — `bgColorForTest` não existe.

- [ ] **Step 3: Substituir cores hardcoded no `transit_map_painter.dart`**

Adicionar imports no topo do arquivo:
```dart
import '../../core/widgets/app_theme.dart';
import '../../core/widgets/app_colors.dart';
```

Substituir os getters de cor (linhas 35–40):
```dart
// ANTES:
Color get _bgColor           => _isDark ? const Color(0xFF121212) : Colors.white;
Color get _labelColor        => _isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
Color get _tickColor         => _isDark ? const Color(0xFF555555) : const Color(0xFFBBBBBB);
Color get _ringColor         => _isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC);
Color get _nucleusColor      => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
Color get _nucleusBorderColor => _isDark ? const Color(0xFFDDDDDD) : const Color(0xFF444444);

// DEPOIS:
Color get _bgColor            => _isDark ? AppTheme.bgDark    : AppTheme.bgLight;
Color get _labelColor         => _isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
Color get _tickColor          => _isDark ? AppTheme.borderDark : AppTheme.borderLight;
Color get _ringColor          => _isDark ? AppTheme.borderDark : AppTheme.borderLight;
Color get _nucleusColor       => _isDark ? AppTheme.bgDark    : AppTheme.bgLight;
Color get _nucleusBorderColor => _isDark ? AppTheme.textSecDark : AppTheme.textSecLight;

@visibleForTesting
Color get bgColorForTest => _bgColor;
```

Substituir `_colorForDensity` (linhas 352–357):
```dart
// ANTES:
Color _colorForDensity(double density) {
  if (density < 0.35) return Colors.green;
  if (density < 0.60) return Colors.amber.shade700;
  if (density < 0.80) return Colors.orange;
  return Colors.red;
}

// DEPOIS:
Color _colorForDensity(double density) {
  if (density < 0.35) return AppColors.crowdLow;
  if (density < 0.60) return AppColors.crowdModerate;
  if (density < 0.80) return AppColors.crowdHigh;
  return AppColors.crowdFull;
}
```

Substituir no `_drawTrainIcon` as duas ocorrências de `Colors.blue.shade700`:
```dart
// ANTES: Colors.blue.shade700
// DEPOIS: AppTheme.primary

// ANTES: Colors.lightBlue.shade200
// DEPOIS: AppTheme.accent
```

Adicionar import `package:flutter/foundation.dart` para `@visibleForTesting` (se não presente):
```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 4: Rodar e verificar que passa**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_painter_test.dart
```

Esperado: PASS (todos os testes existentes + 2 novos).

- [ ] **Step 5: Verificar compilação**

```bash
cd mobile && flutter analyze lib/features/transit_map/transit_map_painter.dart
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_painter.dart mobile/test/features/transit_map/transit_map_painter_test.dart
git commit -m "fix: replace hardcoded colors in TransitMapPainter with AppTheme/AppColors tokens"
```

---

## Chunk 2: Interações no Mapa

### Task 4: Station tap — GestureDetector + findStationAt

**Context:** `transit_map_screen.dart` tem `InteractiveViewer` sem `GestureDetector` externo para hit-testing de estações. `_transformCtrl` é o `TransformationController` existente. `schematic.stations` é `List<SchematicStation>`, cada um com `position: Offset` em coordenadas de canvas (1:1 com cena). O tap usa `_transformCtrl.toScene()` para converter viewport → canvas. O `transit_map_screen_test.dart` já existe.

**Files:**
- Modify: `mobile/lib/features/transit_map/transit_map_screen.dart`
- Modify: `mobile/test/features/transit_map/transit_map_screen_test.dart`

- [ ] **Step 1: Escrever teste para `findStationAt`**

Abrir `mobile/test/features/transit_map/transit_map_screen_test.dart` e adicionar:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/schematic_model.dart';
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
}
```

- [ ] **Step 2: Rodar e verificar que falha**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart
```

Esperado: FAIL — `findStationAt` não existe.

- [ ] **Step 3: Implementar `findStationAt` e `GestureDetector` em `transit_map_screen.dart`**

**3a.** Adicionar import no topo de `transit_map_screen.dart`:
```dart
import '../../core/widgets/app_theme.dart';
```

**3b.** Adicionar a função top-level `findStationAt` logo antes da classe `TransitMapScreen`:

```dart
/// Finds the nearest [SchematicStation] to [point] within [radius] canvas units.
/// Returns null if no station is within radius.
SchematicStation? findStationAt(
  List<SchematicStation> stations,
  Offset point,
  double radius,
) {
  SchematicStation? closest;
  double closestDist = double.infinity;
  for (final station in stations) {
    final dist = (station.position - point).distance;
    if (dist < radius && dist < closestDist) {
      closestDist = dist;
      closest = station;
    }
  }
  return closest;
}
```

**3c.** Em `build()`, substituir linha 122–123:
```dart
// ANTES:
backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,

// DEPOIS:
backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
```

**3d.** Em `_buildMap()`, a linha com `Positioned.fill` que contém o `InteractiveViewer`: envolvê-lo com `GestureDetector`. Substituir (linhas 194–224):

```dart
// ANTES:
Positioned.fill(
  child: InteractiveViewer(
    transformationController: _transformCtrl,
    constrained: false,
    boundaryMargin: const EdgeInsets.all(double.infinity),
    minScale: 0.05,
    maxScale: 6.0,
    child: AnimatedBuilder(
      animation: _transformCtrl,
      builder: (ctx, _) => CustomPaint(
        painter: TransitMapPainter(...),
        size: schematic.canvasSize,
      ),
    ),
  ),
),

// DEPOIS:
Positioned.fill(
  child: GestureDetector(
    onTapUp: (details) {
      final scenePoint = _transformCtrl.toScene(details.localPosition);
      final radius = 24.0 / _currentScale;
      final station = findStationAt(schematic.stations, scenePoint, radius);
      if (station != null && mounted) {
        context.push('/station/${station.stationId}');
      }
    },
    child: InteractiveViewer(
      transformationController: _transformCtrl,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.05,
      maxScale: 6.0,
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
            brightness: brightness,
            currentScale: _currentScale,
          ),
          size: schematic.canvasSize,
        ),
      ),
    ),
  ),
),
```

**3e.** Substituir cores hardcoded no chip container (linhas 255–257 `_buildLineChips`):
```dart
// ANTES:
color: isDark
    ? const Color(0xE1121212)
    : const Color(0xE6FFFFFF),

// DEPOIS:
color: isDark
    ? AppTheme.bgDark.withValues(alpha: 0.88)
    : AppTheme.bgLight.withValues(alpha: 0.90),
```

**3f.** Substituir cor da borda do chip selecionado (linhas 289–292):
```dart
// ANTES:
color: isDark
    ? const Color(0xFF90CAF9)
    : Colors.black,

// DEPOIS:
color: AppTheme.accent,
```

**3g.** Em `_buildNoSchematic`, substituir `Colors.amber.shade100` e `Colors.brown`:
```dart
// ANTES:
color: Colors.amber.shade100,
// e:
style: TextStyle(color: Colors.brown),

// DEPOIS:
color: AppColors.warning.withValues(alpha: 0.15),
// e:
style: TextStyle(color: AppColors.warning),
```

Adicionar import de `AppColors`:
```dart
import '../../core/widgets/app_colors.dart';
```

- [ ] **Step 4: Rodar e verificar que passa**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart
```

Esperado: PASS (4 novos testes).

- [ ] **Step 5: Verificar compilação**

```bash
cd mobile && flutter analyze lib/features/transit_map/transit_map_screen.dart
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_screen.dart mobile/test/features/transit_map/transit_map_screen_test.dart
git commit -m "feat: station tap navigates to detail screen, fix map hardcoded colors"
```

---

### Task 5: Line tap — DirectionArrivals.lineCode + pendingLineSelectionProvider

**Context:** `DirectionArrivals` não tem `lineCode`. Precisamos adicioná-lo como campo opcional. A comunicação entre telas usa `pendingLineSelectionProvider` (novo `StateProvider<String?>`). `_onLineTapped` em `TransitMapScreen` aceita `(String lineCode, TransitSchematic schematic)`. O `station_arrivals_model_test.dart` já existe.

**Files:**
- Modify: `mobile/lib/core/models/station_arrivals_model.dart`
- Modify: `mobile/lib/core/providers/app_providers.dart`
- Modify: `mobile/lib/features/station_detail/station_detail_screen.dart`
- Modify: `mobile/lib/features/transit_map/transit_map_screen.dart`
- Modify: `mobile/test/core/models/station_arrivals_model_test.dart`
- Modify: `mobile/test/features/station_detail/station_detail_redesign_test.dart`

- [ ] **Step 1: Escrever teste para `DirectionArrivals.lineCode`**

Adicionar ao `station_arrivals_model_test.dart`, dentro do grupo `StationArrivals`:

```dart
    test('DirectionArrivals.fromJson parses optional lineCode', () {
      final json = {
        'terminus': 'Jabaquara',
        'lineCode': 'L1',
        'arrivals': [
          {'estimatedMinutes': 3, 'isEstimated': false},
        ],
      };
      final d = DirectionArrivals.fromJson(json);
      expect(d.lineCode, 'L1');
    });

    test('DirectionArrivals.fromJson lineCode is null when absent', () {
      final json = {
        'terminus': 'Jabaquara',
        'arrivals': [],
      };
      final d = DirectionArrivals.fromJson(json);
      expect(d.lineCode, isNull);
    });
```

- [ ] **Step 2: Rodar e verificar que falha**

```bash
cd mobile && flutter test test/core/models/station_arrivals_model_test.dart
```

Esperado: FAIL — `lineCode` não existe.

- [ ] **Step 3: Adicionar `lineCode` a `DirectionArrivals`**

Editar `mobile/lib/core/models/station_arrivals_model.dart`:

```dart
class DirectionArrivals {
  final String terminus;
  final List<ArrivalTime> arrivals;
  final String? lineCode; // optional — populated from API when available

  const DirectionArrivals({
    required this.terminus,
    required this.arrivals,
    this.lineCode,
  });

  factory DirectionArrivals.fromJson(Map<String, dynamic> j) =>
      DirectionArrivals(
        terminus: j['terminus'] as String,
        arrivals: (j['arrivals'] as List)
            .map((a) => ArrivalTime.fromJson(a as Map<String, dynamic>))
            .toList(),
        lineCode: j['lineCode'] as String?,
      );
}
```

- [ ] **Step 4: Rodar e verificar que passa**

```bash
cd mobile && flutter test test/core/models/station_arrivals_model_test.dart
```

Esperado: PASS (5 testes).

- [ ] **Step 5: Adicionar `pendingLineSelectionProvider` a `app_providers.dart`**

Adicionar ao final do arquivo:

```dart
/// Used to signal TransitMapScreen to select a line after navigating back from
/// StationDetailScreen. Set to a lineCode string, consumed and cleared by TransitMapScreen.
final pendingLineSelectionProvider = StateProvider<String?>((ref) => null);
```

- [ ] **Step 6: Escrever teste de provider**

Adicionar ao `theme_mode_provider_test.dart` (ou criar arquivo separado — adicionar ao existente é mais simples):

```dart
  test('pendingLineSelectionProvider default is null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(pendingLineSelectionProvider), isNull);
  });
```

- [ ] **Step 7: Rodar e verificar que passa**

```bash
cd mobile && flutter test test/core/providers/theme_mode_provider_test.dart
```

Esperado: PASS.

- [ ] **Step 8: Escrever teste para o tap na linha em StationDetailScreen**

Abrir `mobile/test/features/station_detail/station_detail_redesign_test.dart` e verificar se já tem testes. Adicionar:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/providers/app_providers.dart';
import 'package:trilho/core/models/station_arrivals_model.dart';
import 'package:trilho/core/providers/station_arrivals_provider.dart';

// Minimal mock arrivals with lineCode
final _mockArrivals = StationArrivals(
  stationId: 1,
  directions: [
    DirectionArrivals(
      terminus: 'Jabaquara',
      arrivals: [const ArrivalTime(estimatedMinutes: 3, isEstimated: false)],
      lineCode: 'L1',
    ),
  ],
);

void main() {
  testWidgets('tapping direction card sets pendingLineSelectionProvider', (tester) async {
    final container = ProviderContainer(
      overrides: [
        stationArrivalsProvider(1).overrideWith((ref) =>
            Stream.value(_mockArrivals).map((a) => a).asBroadcastStream()),
      ],
    );
    // ... widget test setup
    // Verify pendingLineSelectionProvider == 'L1' after tap
  });
}
```

> **Note:** This test requires mocking multiple providers (usage, crowd, arrivals). If mocking complexity is high, write a simpler unit test that verifies `pendingLineSelectionProvider` is set when a card with lineCode is tapped by calling the logic directly. The integration can be verified manually.

- [ ] **Step 9: Implementar o onTap nos cartões de direção em `station_detail_screen.dart`**

Adicionar imports:
```dart
import '../../core/providers/app_providers.dart';
```

Em `_buildDirectionCards`, dentro do `data: (arrivals)` branch, modificar a parte que cria o `Expanded` para cada direção. Atualmente começa em `return Expanded(child: Container(...))`. Envolver o `Container` com `GestureDetector`:

```dart
return Expanded(
  child: GestureDetector(
    onTap: dir.lineCode != null
        ? () {
            ref.read(pendingLineSelectionProvider.notifier).state = dir.lineCode;
            context.go('/');
          }
        : null,
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
          // conteúdo existente sem alteração
        ],
      ),
    ),
  ),
);
```

- [ ] **Step 10: Adicionar `ref.listen` em `TransitMapScreen.build()`**

Em `transit_map_screen.dart`, adicionar no início do método `build()` (antes do `return Scaffold`):

```dart
// Listen for line selection from StationDetailScreen
ref.listen<String?>(pendingLineSelectionProvider, (_, lineId) {
  if (lineId == null) return;
  final schematic = ref.read(transitMapProvider).valueOrNull;
  if (schematic != null) {
    _onLineTapped(lineId, schematic);
  }
  ref.read(pendingLineSelectionProvider.notifier).state = null;
});
```

Adicionar import:
```dart
import '../../core/providers/app_providers.dart';
```

- [ ] **Step 11: Verificar compilação**

```bash
cd mobile && flutter analyze lib/core/models/station_arrivals_model.dart lib/features/station_detail/station_detail_screen.dart lib/features/transit_map/transit_map_screen.dart
```

- [ ] **Step 12: Rodar todos os testes**

```bash
cd mobile && flutter test
```

Esperado: todos passam.

- [ ] **Step 13: Commit**

```bash
git add mobile/lib/core/models/station_arrivals_model.dart \
        mobile/lib/core/providers/app_providers.dart \
        mobile/lib/features/station_detail/station_detail_screen.dart \
        mobile/lib/features/transit_map/transit_map_screen.dart \
        mobile/test/core/models/station_arrivals_model_test.dart \
        mobile/test/core/providers/theme_mode_provider_test.dart
git commit -m "feat: line tap in station detail navigates back to map with line selected"
```

---

## Chunk 3: Telas Pós-login

### Task 6: EmailAuthScreen — polish visual

**Context:** `email_auth_screen.dart` usa `Theme.of(context).colorScheme` corretamente. Dois fixes pontuais: (1) scaffold bg explícito, (2) `CircularProgressIndicator` com `Colors.white` hardcoded. O `email_auth_screen_test.dart` já existe.

**Files:**
- Modify: `mobile/lib/features/auth/email_auth_screen.dart`
- Modify: `mobile/test/features/auth/email_auth_screen_test.dart`

- [ ] **Step 1: Escrever testes que falham**

Abrir `mobile/test/features/auth/email_auth_screen_test.dart` e verificar conteúdo atual. Adicionar:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/features/auth/email_auth_screen.dart';
import 'package:trilho/core/widgets/app_theme.dart';

void main() {
  testWidgets('EmailAuthScreen scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: EmailAuthScreen(),
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });

  testWidgets('EmailAuthScreen scaffold bg is AppTheme.bgLight in light mode', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: EmailAuthScreen(),
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.bgLight);
  });
}
```

- [ ] **Step 2: Rodar e verificar que falham**

```bash
cd mobile && flutter test test/features/auth/email_auth_screen_test.dart
```

Esperado: FAIL — scaffold não tem backgroundColor explícito.

- [ ] **Step 3: Aplicar fixes em `email_auth_screen.dart`**

Adicionar import:
```dart
import '../../core/widgets/app_theme.dart';
```

No método `build`, no `Scaffold` (linha 105), adicionar `backgroundColor`:
```dart
return Scaffold(
  backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
  appBar: AppBar(
```

No `CircularProgressIndicator` (linha ~196), substituir:
```dart
// ANTES:
child: CircularProgressIndicator(
  strokeWidth: 2,
  color: Colors.white,
),

// DEPOIS:
child: const CircularProgressIndicator(
  strokeWidth: 2,
  color: AppTheme.textPrimDark,
),
```

- [ ] **Step 4: Rodar e verificar que passam**

```bash
cd mobile && flutter test test/features/auth/email_auth_screen_test.dart
```

Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/auth/email_auth_screen.dart mobile/test/features/auth/email_auth_screen_test.dart
git commit -m "fix: EmailAuthScreen scaffold bg and spinner color use AppTheme tokens"
```

---

### Task 7: SubscriptionScreen — redesign visual completo

**Context:** `subscription_screen.dart` usa `Colors.green`, `Colors.red`, `Colors.grey`, `Colors.orange` hardcoded em todo o arquivo. A estrutura de abas (Plano Atual / Histórico) e toda a lógica de negócio são mantidas. Apenas a camada visual muda. O `subscription_screen_test.dart` pode não existir ainda.

**Files:**
- Modify: `mobile/lib/features/subscription/subscription_screen.dart`
- Create: `mobile/test/features/subscription/subscription_screen_test.dart`

- [ ] **Step 1: Escrever testes que falham**

Criar `mobile/test/features/subscription/subscription_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/features/subscription/subscription_screen.dart';
import 'package:trilho/core/widgets/app_theme.dart';

void main() {
  testWidgets('SubscriptionScreen scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });

  testWidgets('SubscriptionScreen scaffold bg is AppTheme.bgLight in light mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.bgLight);
  });
}
```

- [ ] **Step 2: Rodar e verificar que falham**

```bash
cd mobile && flutter test test/features/subscription/subscription_screen_test.dart
```

Esperado: FAIL — scaffold sem backgroundColor explícito.

- [ ] **Step 3: Aplicar redesign visual em `subscription_screen.dart`**

Adicionar imports:
```dart
import '../../core/widgets/app_theme.dart';
import '../../core/widgets/app_colors.dart';
```

**3a. Scaffold backgroundColor:**
```dart
// Em build(), no Scaffold:
backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
```

**3b. TabBar indicador:**
Dentro do `AppBar`, após `bottom: TabBar(...)`, adicionar `indicatorColor` e `labelColor`:
```dart
bottom: TabBar(
  controller: _tabController,
  indicatorColor: AppTheme.accent,
  labelColor: AppTheme.accent,
  unselectedLabelColor: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
  tabs: const [
    Tab(text: 'Plano Atual'),
    Tab(text: 'Histórico'),
  ],
),
```

**3c. Hero card (substitui o primeiro `Card` em `_buildCurrentPlanTab`):**
```dart
// ANTES: Card(child: Padding(... Icon(status.isActive ? Icons.check_circle : Icons.cancel, ...) ...))
// DEPOIS:
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: status.isActive
          ? [AppTheme.primary, AppTheme.accent]
          : [
              AppTheme.isDark(context) ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              AppTheme.isDark(context) ? AppTheme.surfRaisedDark : AppTheme.surfRaisedLight,
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Column(
    children: [
      Icon(
        status.isActive ? Icons.star_rounded : Icons.star_border_rounded,
        size: 40,
        color: Colors.white,
      ),
      const SizedBox(height: 12),
      Text(
        status.planName,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        status.formattedPrice,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status.isActive ? 'Assinatura Ativa' : 'Assinatura Inativa',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    ],
  ),
),
```

**3d. Segundo Card ("Detalhes") em `_buildCurrentPlanTab`:**
```dart
// Substituir Card(child: ...) por Container com AppTheme.cardDecoration:
Container(
  decoration: AppTheme.cardDecoration(context),
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Detalhes',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
          color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
        ),
      ),
      const Divider(),
      _buildDetailRow(Icons.calendar_today, 'Próxima Cobrança',
          status.isPremiumUntil != null ? status.formattedDate : '-'),
      _buildDetailRow(Icons.payment, 'Método de Pagamento', status.paymentMethod),
      _buildDetailRow(Icons.autorenew, 'Renovação Automática',
          status.autoRenew ? 'Ativada' : 'Desativada'),
    ],
  ),
),
```

**3e. Terceiro Card ("Ações") em `_buildCurrentPlanTab`:**
```dart
// Substituir Card por Container com AppTheme.cardDecoration:
Container(
  decoration: AppTheme.cardDecoration(context),
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Ações', style: Theme.of(context).textTheme.titleMedium),
      const Divider(),
      if (status.canChangePlan) ...[
        ListTile(
          leading: Icon(Icons.swap_horiz,
              color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight),
          title: const Text('Trocar Plano'),
          subtitle: const Text('Escolha outro plano'),
          trailing: Icon(Icons.chevron_right,
              color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight),
          onTap: _changePlan,
        ),
      ],
      if (status.isActive && status.canCancel) ...[
        ListTile(
          leading: Icon(Icons.cancel, color: AppColors.danger),
          title: Text('Cancelar Assinatura',
              style: TextStyle(color: AppColors.danger)),
          subtitle: Text('Válido até ${status.formattedDate}'),
          trailing: Icon(Icons.chevron_right, color: AppColors.danger),
          onTap: _cancelSubscription,
        ),
      ],
      if (!status.isActive) ...[
        ListTile(
          leading: Icon(Icons.refresh, color: AppColors.success),
          title: Text('Reativar Assinatura',
              style: TextStyle(color: AppColors.success)),
          trailing: Icon(Icons.chevron_right, color: AppColors.success),
          onTap: _reactivateSubscription,
        ),
      ],
    ],
  ),
),
```

**3f. `_buildDetailRow`:**
```dart
Widget _buildDetailRow(IconData icon, String label, String value) {
  final isDark = AppTheme.isDark(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 20,
            color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight)),
        ),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight,
            )),
      ],
    ),
  );
}
```

**3g. `_buildHistoryTab`:**
```dart
Widget _buildHistoryTab() {
  if (_history.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64,
              color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight),
          const SizedBox(height: 16),
          Text('Nenhum histórico encontrado',
              style: TextStyle(
                  color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight)),
        ],
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _history.length,
    itemBuilder: (context, index) {
      final item = _history[index];
      final isPaid = item.status == 'paid';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isPaid
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            child: Icon(
              isPaid ? Icons.check : Icons.warning,
              color: isPaid ? AppColors.success : AppColors.warning,
            ),
          ),
          title: Text(item.description),
          subtitle: Text(item.formattedDate,
              style: TextStyle(
                  color: AppTheme.isDark(context)
                      ? AppTheme.textSecDark
                      : AppTheme.textSecLight)),
          trailing: Text(
            item.formattedPrice,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.isDark(context) ? AppTheme.textPrimDark : AppTheme.textPrimLight,
            ),
          ),
        ),
      );
    },
  );
}
```

**3h. `_cancelSubscription` SnackBar:**
```dart
// ANTES: backgroundColor: result.success ? Colors.green : Colors.red
// DEPOIS:
backgroundColor: result.success ? AppColors.success : AppColors.danger,
```

**3i. `_reactivateSubscription` SnackBar:**
```dart
// Mesma substituição:
backgroundColor: result.success ? AppColors.success : AppColors.danger,
```

**3j. `_ChangePlanSheet`:**
```dart
// No build() de _ChangePlanSheet, adicionar ao Container raiz:
decoration: BoxDecoration(
  color: Theme.of(context).brightness == Brightness.dark
      ? AppTheme.bgDark
      : AppTheme.bgLight,
),

// Em _buildPlanOption, substituir borda:
border: Border.all(
  color: Theme.of(context).brightness == Brightness.dark
      ? AppTheme.borderDark
      : AppTheme.borderLight,
),

// Badge verde:
// ANTES: color: Colors.green,
// DEPOIS: color: AppColors.success,

// Texto do badge:
// ANTES: style: const TextStyle(color: Colors.white, fontSize: 12)
// DEPOIS: style: const TextStyle(color: AppTheme.textPrimDark, fontSize: 12)
```

> **Note:** `_ChangePlanSheet` não é um `Scaffold`, então o `backgroundColor` vai no `Container` pai. Adicionar imports `AppTheme` e `AppColors` à classe também.

- [ ] **Step 4: Rodar e verificar que passam**

```bash
cd mobile && flutter test test/features/subscription/subscription_screen_test.dart
```

Esperado: PASS.

- [ ] **Step 5: Rodar todos os testes**

```bash
cd mobile && flutter test
```

Esperado: PASS — todos os testes do projeto.

- [ ] **Step 6: Verificar compilação completa**

```bash
cd mobile && flutter analyze
```

Esperado: sem erros.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/subscription/subscription_screen.dart mobile/test/features/subscription/subscription_screen_test.dart
git commit -m "feat: SubscriptionScreen visual redesign with AppTheme/AppColors tokens"
```

---

## Checklist final

- [ ] Rodar `flutter test` — todos devem passar
- [ ] Rodar `flutter analyze` — sem erros
- [ ] Testar manualmente no emulador: dark mode toggle, tap em estação, tap na linha, visual do mapa, telas pós-login

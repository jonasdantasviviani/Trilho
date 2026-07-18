# City Selection Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the WelcomeScreen as a city-card grid, add `cityEmoji()` / `ComingSoonDialog` / simplified `CityPickerSheet`, and wire up city-change from Settings and the TransitMapScreen AppBar.

**Architecture:** Harden `SelectedCityNotifier` with try-catch so tests never throw HiveError; rewrite `city_picker_sheet.dart` with all new public helpers; rewrite `welcome_screen.dart` as a `ConsumerWidget` with a 2×2 card grid; insert a LOCALIZAÇÃO section in `settings_screen.dart`; add an `InkWell` AppBar title to `transit_map_screen.dart`. New test files cover the changed code; existing tests are left passing.

**Tech Stack:** Flutter/Dart · Riverpod (StateNotifierProvider) · GoRouter · Hive · flutter_test

---

## Chunk 1: Foundation

### Task 1: Harden SelectedCityNotifier

**Files:**
- Modify: `mobile/lib/core/providers/city_provider.dart`
- Create: `mobile/test/core/providers/selected_city_notifier_test.dart`

Context: `select()` and `clear()` call `Hive.box()` directly. `SelectedCityNotifier.skipHive()` bypasses the constructor but NOT these methods — any widget test that taps an available city will throw `HiveError`. The default constructor also throws in tests when a provider is watched without an override. Wrapping with `try {} catch (_) {}` is the full fix.

- [ ] **Step 1.1 – Write failing tests**

Create `mobile/test/core/providers/selected_city_notifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/city_model.dart';
import 'package:trilho/core/providers/city_provider.dart';

void main() {
  group('SelectedCityNotifier.skipHive()', () {
    test('select() updates state without throwing when Hive unavailable', () {
      final n = SelectedCityNotifier.skipHive();
      expect(() => n.select(CityRegistry.all.first), returnsNormally);
      expect(n.state?.id, equals('sao-paulo-sp'));
    });

    test('clear() resets state without throwing when Hive unavailable', () {
      final n = SelectedCityNotifier.skipHive();
      n.select(CityRegistry.all.first); // first call — will throw before fix
      expect(() => n.clear(), returnsNormally);
      expect(n.state, isNull);
    });
  });

  group('SelectedCityNotifier() default constructor', () {
    test('does not throw when Hive box is unavailable', () {
      expect(() => SelectedCityNotifier(), returnsNormally);
    });

    test('state is null when Hive is unavailable', () {
      expect(SelectedCityNotifier().state, isNull);
    });
  });
}
```

- [ ] **Step 1.2 – Run to confirm tests fail**

```bash
cd mobile && flutter test test/core/providers/selected_city_notifier_test.dart --no-pub
```

Expected: FAIL — `select()` / `clear()` throw `HiveError`; default constructor throws.

- [ ] **Step 1.3 – Implement try-catch**

Replace the body of `mobile/lib/core/providers/city_provider.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/city_model.dart';

const _kBoxName = 'app_prefs';
const _kCityKey = 'selected_city_id';

class SelectedCityNotifier extends StateNotifier<CityModel?> {
  SelectedCityNotifier() : super(null) {
    try {
      final box = Hive.box(_kBoxName);
      final savedId = box.get(_kCityKey) as String?;
      if (savedId != null) {
        state = CityRegistry.findById(savedId);
      }
    } catch (_) {}
  }

  /// For testing only — skips Hive initialization.
  SelectedCityNotifier.skipHive() : super(null);

  void select(CityModel city) {
    try {
      Hive.box(_kBoxName).put(_kCityKey, city.id);
    } catch (_) {}
    state = city;
  }

  void clear() {
    try {
      Hive.box(_kBoxName).delete(_kCityKey);
    } catch (_) {}
    state = null;
  }
}

final selectedCityProvider =
    StateNotifierProvider<SelectedCityNotifier, CityModel?>(
  (ref) => SelectedCityNotifier(),
);

final citiesByStateProvider = Provider<Map<String, List<CityModel>>>(
  (ref) => CityRegistry.byState,
);
```

- [ ] **Step 1.4 – Run to confirm tests pass**

```bash
cd mobile && flutter test test/core/providers/selected_city_notifier_test.dart --no-pub
```

Expected: PASS (4 tests).

- [ ] **Step 1.5 – Run full suite to confirm no regressions**

```bash
cd mobile && flutter test --no-pub
```

Expected: all tests pass.

- [ ] **Step 1.6 – Commit**

```bash
cd mobile && git add lib/core/providers/city_provider.dart test/core/providers/selected_city_notifier_test.dart
git commit -m "$(cat <<'EOF'
feat: harden SelectedCityNotifier with try-catch for Hive errors

select(), clear(), and the default constructor now gracefully ignore
HiveError so widget tests work without initializing Hive.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Rewrite city_picker_sheet.dart

**Files:**
- Create: `mobile/test/features/city_picker/city_picker_sheet_test.dart`
- Modify: `mobile/lib/features/city_picker/city_picker_sheet.dart`

Context: The current sheet is a `DraggableScrollableSheet` with search + `ExpansionTile` by state — never called from anywhere. The spec replaces it with: a public `cityEmoji()` helper; a public `ComingSoonDialog`; a simplified `showCityPickerSheet` (async, returns city via `Navigator.pop`, caller handles navigation); and a private `_CityPickerContent ConsumerWidget`.

- [ ] **Step 2.1 – Write failing tests**

Create `mobile/test/features/city_picker/city_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/city_model.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/features/city_picker/city_picker_sheet.dart';

void main() {
  // Pre-seed provider with São Paulo (safe after Task 1 — select() has try-catch).
  Widget buildSubject() => ProviderScope(
        overrides: [
          selectedCityProvider.overrideWith((_) {
            final n = SelectedCityNotifier.skipHive();
            n.select(CityRegistry.all.first); // São Paulo
            return n;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () => showCityPickerSheet(context, ref),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('open sheet shows check icon for currently selected city', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping unavailable city shows ComingSoonDialog', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rio de Janeiro'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('"Me avise" shows SnackBar after dismissing dialog', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rio de Janeiro'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('🔔 Me avise'));
    await tester.pump();

    expect(
      find.text('Anotado! Você será o primeiro a saber.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2.2 – Run to confirm tests fail**

```bash
cd mobile && flutter test test/features/city_picker/city_picker_sheet_test.dart --no-pub
```

Expected: FAIL — `cityEmoji`, `ComingSoonDialog`, new sheet behavior do not exist yet.

- [ ] **Step 2.3 – Rewrite city_picker_sheet.dart**

Replace the entire content of `mobile/lib/features/city_picker/city_picker_sheet.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/city_model.dart';
import '../../core/providers/city_provider.dart';
import '../../core/widgets/app_theme.dart';

// ── Public helpers ────────────────────────────────────────────────────────────

/// Returns an emoji representative of [city].
/// Used by [ComingSoonDialog], [WelcomeScreen] city cards, and [_CityPickerContent].
String cityEmoji(CityModel city) => switch (city.id) {
      'sao-paulo-sp' => '🏙️',
      'rio-de-janeiro-rj' => '🏖️',
      'curitiba-pr' => '🌲',
      'belo-horizonte-mg' => '⛰️',
      'porto-alegre-rs' => '🌿',
      _ => '🏙️',
    };

// ── ComingSoonDialog ──────────────────────────────────────────────────────────

/// Shown when the user taps a city that has no schematic yet.
class ComingSoonDialog extends StatelessWidget {
  final CityModel city;
  const ComingSoonDialog({super.key, required this.city});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${cityEmoji(city)} ${city.name}'),
      content: Text(
        'Ainda não disponível no Trilho.\n'
        'Quer ser avisado quando ${city.name} chegar?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Agora não'),
        ),
        TextButton(
          onPressed: () {
            // Capture messenger BEFORE pop to avoid context detachment.
            final messenger = ScaffoldMessenger.of(context);
            try {
              Hive.box('app_prefs').put('notify_city_${city.id}', true);
            } catch (_) {}
            Navigator.pop(context);
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Anotado! Você será o primeiro a saber.'),
              ),
            );
          },
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          child: const Text('🔔 Me avise'),
        ),
      ],
    );
  }
}

// ── showCityPickerSheet ───────────────────────────────────────────────────────

/// Opens the city-picker bottom sheet.
///
/// The sheet returns the chosen [CityModel] to this caller via
/// `Navigator.pop(city)`. Navigation is handled here using the **caller's**
/// [context] — never the sheet's context — to avoid post-pop detachment.
Future<void> showCityPickerSheet(BuildContext context, WidgetRef ref) async {
  final CityModel? selected = await showModalBottomSheet<CityModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _CityPickerContent(),
  );
  if (selected != null) {
    ref.read(selectedCityProvider.notifier).select(selected);
    if (context.mounted) context.go('/');
  }
}

// ── _CityPickerContent ────────────────────────────────────────────────────────

class _CityPickerContent extends ConsumerWidget {
  const _CityPickerContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final isDark = AppTheme.isDark(context);
    final textPrim = isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
    final textSec = isDark ? AppTheme.textSecDark : AppTheme.textSecLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Drag handle ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // ── Title ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Trocar cidade',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        // ── City list ─────────────────────────────────────────────────────────
        ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: CityRegistry.all.map((city) {
            final isSelected = city == selectedCity;
            final isAvailable = city.schematicId != null;

            Widget tile = Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: isSelected
                  ? AppTheme.cardDecoration(context).copyWith(
                      border: Border.all(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    )
                  : AppTheme.cardDecoration(context),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isSelected
                    ? null
                    : isAvailable
                        ? () => Navigator.of(context).pop(city)
                        : () => showDialog(
                              context: context,
                              builder: (_) => ComingSoonDialog(city: city),
                            ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        cityEmoji(city),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              city.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrim,
                              ),
                            ),
                            Text(
                              city.stateCode,
                              style: TextStyle(fontSize: 11, color: textSec),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
            );

            if (!isAvailable && !isSelected) {
              tile = Opacity(opacity: 0.45, child: tile);
            }

            return tile;
          }).toList(),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2.4 – Run sheet tests**

```bash
cd mobile && flutter test test/features/city_picker/city_picker_sheet_test.dart --no-pub
```

Expected: PASS (3 tests).

- [ ] **Step 2.5 – Run full suite**

```bash
cd mobile && flutter test --no-pub
```

Expected: all tests pass.

- [ ] **Step 2.6 – Commit**

```bash
cd mobile && git add lib/features/city_picker/city_picker_sheet.dart test/features/city_picker/city_picker_sheet_test.dart
git commit -m "$(cat <<'EOF'
feat: rewrite CityPickerSheet with cityEmoji, ComingSoonDialog, simplified sheet

New sheet returns CityModel? to caller; caller handles select() + go('/').
ComingSoonDialog stores local Hive flag on "Me avise" tap.
cityEmoji() is public so WelcomeScreen can import it.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 2: UI

### Task 3: Rewrite welcome_screen.dart

**Files:**
- Create: `mobile/test/features/city_picker/welcome_screen_test.dart`
- Modify: `mobile/lib/features/city_picker/welcome_screen.dart`

Context: Current WelcomeScreen uses a state `DropdownButtonFormField` + city list. Replace with a 2×2 `GridView` for the first 4 cities in `CityRegistry.all` plus a full-width row for the 5th (Porto Alegre). Available city (SP only today) has a primary-tinted border + "Disponível" badge; unavailable cities are 45% opaque with "Em breve" badge + `ComingSoonDialog` on tap. The screen uses GoRouter's `context.go('/')` — tests must supply a GoRouter.

`city_picker_token_test.dart` (existing) overrides `citiesByStateProvider` — that override is now unused but harmless; the test still passes.

- [ ] **Step 3.1 – Write failing tests**

Create `mobile/test/features/city_picker/welcome_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/features/city_picker/welcome_screen.dart';

Widget buildSubject({required ProviderContainer container, ThemeData? theme}) {
  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: theme,
      routerConfig: router,
    ),
  );
}

ProviderContainer makeContainer() => ProviderContainer(
      overrides: [
        selectedCityProvider.overrideWith(
          (_) => SelectedCityNotifier.skipHive(),
        ),
      ],
    );

void main() {
  testWidgets('Scaffold backgroundColor is bgDark in dark theme', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      buildSubject(container: container, theme: AppTheme.dark()),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });

  testWidgets('Scaffold backgroundColor is bgLight in light theme', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      buildSubject(container: container, theme: AppTheme.light()),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgLight);
  });

  testWidgets('tapping São Paulo updates selectedCityProvider', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildSubject(container: container));
    await tester.pump();

    await tester.tap(find.text('São Paulo').first);
    await tester.pump(); // single frame: provider updated, navigation starting

    expect(container.read(selectedCityProvider)?.id, 'sao-paulo-sp');
  });

  testWidgets('tapping Curitiba shows ComingSoonDialog', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildSubject(container: container));
    await tester.pump();

    await tester.tap(find.text('Curitiba').first);
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('"Me avise" shows SnackBar', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildSubject(container: container));
    await tester.pump();

    await tester.tap(find.text('Curitiba').first);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('🔔 Me avise'));
    await tester.pump();

    expect(
      find.text('Anotado! Você será o primeiro a saber.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 3.2 – Run to confirm tests fail**

```bash
cd mobile && flutter test test/features/city_picker/welcome_screen_test.dart --no-pub
```

Expected: FAIL — new layout not implemented, `cityEmoji`/`ComingSoonDialog` not imported.

- [ ] **Step 3.3 – Rewrite welcome_screen.dart**

Replace the entire content of `mobile/lib/features/city_picker/welcome_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/city_model.dart';
import '../../core/providers/city_provider.dart';
import '../../core/widgets/app_theme.dart';
import 'city_picker_sheet.dart'; // cityEmoji() + ComingSoonDialog

/// Full-screen onboarding shown when no city has been saved yet.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final cities = CityRegistry.all; // 5 cities in registry order
    final gridCities = cities.take(4).toList(); // first 4 in 2×2 grid
    final lastCity = cities[4]; // Porto Alegre — full-width row

    final textPrim = isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
    final textSec = isDark ? AppTheme.textSecDark : AppTheme.textSecLight;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildCard(
              context, ref, isDark, gridCities, lastCity, textPrim, textSec,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Container(
      height: screenHeight * 0.35,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.accent],
        ),
      ),
      child: const SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train, size: 56, color: AppTheme.textPrimDark),
            SizedBox(height: 8),
            Text(
              'TRILHO',
              style: TextStyle(
                color: AppTheme.textPrimDark,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Mobilidade em tempo real',
              style: TextStyle(
                // 0xBF = 75% opacity
                color: Color(0xBFFFFFFF),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    List<CityModel> gridCities,
    CityModel lastCity,
    Color textPrim,
    Color textSec,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Em qual cidade você está?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrim,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Você pode mudar depois nas configurações',
                style: TextStyle(fontSize: 12, color: textSec),
              ),
              const SizedBox(height: 16),
              // 2×2 grid for first 4 cities
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: gridCities
                    .map(
                      (city) => _buildCityCard(
                        context, ref, city, isDark, textPrim, textSec,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              // 5th city — full-width horizontal row
              _buildFullWidthCity(
                context, ref, lastCity, isDark, textPrim, textSec,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityCard(
    BuildContext context,
    WidgetRef ref,
    CityModel city,
    bool isDark,
    Color textPrim,
    Color textSec,
  ) {
    final isAvailable = city.schematicId != null;
    final bg = isDark ? AppTheme.surfRaisedDark : AppTheme.surfRaisedLight;
    final border = isAvailable
        ? Border.all(
            color: AppTheme.primary.withValues(alpha: 0.35),
            width: 1.5,
          )
        : Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          );
    final badgeBg = isAvailable
        ? AppTheme.primary
        : (isDark ? AppTheme.surfRaisedDark : AppTheme.surfRaisedLight);
    final badgeTextColor = isAvailable
        ? AppTheme.textPrimDark
        : (isDark ? AppTheme.textSecDark : AppTheme.textSecLight);

    Widget card = GestureDetector(
      onTap: isAvailable
          ? () {
              ref.read(selectedCityProvider.notifier).select(city);
              if (context.mounted) context.go('/');
            }
          : () => showDialog(
                context: context,
                builder: (_) => ComingSoonDialog(city: city),
              ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(cityEmoji(city), style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                city.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textPrim,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            Text(
              city.stateCode,
              style: TextStyle(fontSize: 10, color: textSec),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isAvailable ? 'Disponível' : 'Em breve',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isAvailable) {
      return Opacity(opacity: 0.45, child: card);
    }
    return card;
  }

  Widget _buildFullWidthCity(
    BuildContext context,
    WidgetRef ref,
    CityModel city,
    bool isDark,
    Color textPrim,
    Color textSec,
  ) {
    final bg = isDark ? AppTheme.surfRaisedDark : AppTheme.surfRaisedLight;
    final border = Border.all(
      color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
    );
    final badgeBg = isDark ? AppTheme.surfRaisedDark : AppTheme.surfRaisedLight;
    final badgeTextColor = isDark ? AppTheme.textSecDark : AppTheme.textSecLight;

    return Opacity(
      opacity: 0.45,
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => ComingSoonDialog(city: city),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Row(
            children: [
              Text(cityEmoji(city), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textPrim,
                      ),
                    ),
                    Text(
                      city.stateCode,
                      style: TextStyle(fontSize: 10, color: textSec),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Em breve',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3.4 – Run welcome_screen tests**

```bash
cd mobile && flutter test test/features/city_picker/welcome_screen_test.dart --no-pub
```

Expected: PASS (5 tests).

- [ ] **Step 3.5 – Run full suite**

```bash
cd mobile && flutter test --no-pub
```

Expected: all tests pass. Note: `city_picker_token_test.dart` still passes because it only checks `scaffold.backgroundColor` and its `citiesByStateProvider` override is harmless (WelcomeScreen no longer watches that provider).

- [ ] **Step 3.6 – Commit**

```bash
cd mobile && git add lib/features/city_picker/welcome_screen.dart test/features/city_picker/welcome_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: rewrite WelcomeScreen with 2x2 city-card grid layout

Replaces state dropdown + city list with a 2x2 GridView + full-width row
for the 5th city. Available cities tap → select + go('/'); unavailable
cities tap → ComingSoonDialog.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Extend SettingsScreen with LOCALIZAÇÃO section

**Files:**
- Modify: `mobile/lib/features/settings/settings_screen.dart`
- Modify: `mobile/test/features/settings/settings_screen_test.dart`

Context: `SettingsScreen` is a `ConsumerWidget` — `ref` is already available. Insert a "LOCALIZAÇÃO" section (label + card with one `_settingRow`) before the existing "APARÊNCIA" section. Tapping the row calls `showCityPickerSheet(context, ref)`. After Task 1, the default `SelectedCityNotifier()` constructor has try-catch, so the existing tests (which don't override `selectedCityProvider`) continue to pass.

- [ ] **Step 4.1 – Write failing test**

Add at the bottom of `mobile/test/features/settings/settings_screen_test.dart` (inside `main()`):

```dart
  testWidgets('shows LOCALIZAÇÃO section with city name when city is selected', (tester) async {
    final container = ProviderContainer(
      overrides: [
        selectedCityProvider.overrideWith((_) {
          final n = SelectedCityNotifier.skipHive();
          n.select(CityRegistry.all.first); // São Paulo
          return n;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('LOCALIZAÇÃO'), findsOneWidget);
    expect(find.text('Cidade'), findsOneWidget);
    expect(find.text('São Paulo, SP'), findsOneWidget);
  });
```

Also add the required imports to the test file (at the top):

```dart
import 'package:trilho/core/models/city_model.dart';
import 'package:trilho/core/providers/city_provider.dart';
```

- [ ] **Step 4.2 – Run to confirm new test fails**

```bash
cd mobile && flutter test test/features/settings/settings_screen_test.dart --no-pub
```

Expected: 3 existing tests PASS, 1 new test FAIL (LOCALIZAÇÃO not in UI yet).

- [ ] **Step 4.3 – Modify settings_screen.dart**

**a) Add imports** after the existing imports block (after `app_colors.dart`):

```dart
import '../../core/providers/city_provider.dart';
import '../city_picker/city_picker_sheet.dart';
```

**b) Add `selectedCity` watch** at the top of `build()`, after `final usageAsync = ref.watch(usageProvider);`:

```dart
    final selectedCity = ref.watch(selectedCityProvider);
```

**c) Insert LOCALIZAÇÃO section** in the `ListView` children, immediately before the line `_sectionLabel('APARÊNCIA', labelColor),`:

```dart
          // ── Localização ───────────────────────────────────────────────────
          _sectionLabel('LOCALIZAÇÃO', labelColor),
          _card(isDark, cardColor, [
            _settingRow(
              icon: '🏙️',
              iconBg: isDark
                  ? const Color(0xFF1B3A1B)
                  : const Color(0xFFF1F8E9),
              title: 'Cidade',
              subtitle: selectedCity != null
                  ? '${selectedCity.name}, ${selectedCity.stateCode}'
                  : 'Selecionar cidade',
              textPrimary: textPrimary,
              borderColor: Colors.transparent,
              trailing: Icon(Icons.chevron_right, color: labelColor),
              subtitleColor: labelColor,
              onTap: () => showCityPickerSheet(context, ref),
            ),
          ]),
          const SizedBox(height: 20),

```

- [ ] **Step 4.4 – Run settings tests**

```bash
cd mobile && flutter test test/features/settings/settings_screen_test.dart --no-pub
```

Expected: PASS (4 tests).

- [ ] **Step 4.5 – Run full suite**

```bash
cd mobile && flutter test --no-pub
```

Expected: all tests pass.

- [ ] **Step 4.6 – Commit**

```bash
cd mobile && git add lib/features/settings/settings_screen.dart test/features/settings/settings_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: add LOCALIZAÇÃO section to SettingsScreen for city change

New section appears above APARÊNCIA. Tapping the row opens
CityPickerSheet. Subtitle shows the currently selected city name.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: TransitMapScreen — tappable AppBar title

**Files:**
- Modify: `mobile/lib/features/transit_map/transit_map_screen.dart`

Context: `transit_map_screen.dart` is a `ConsumerStatefulWidget` — `ref` is available in `build()`. Simply replace `title: Text(cityName)` with an `InkWell` wrapping a `Row(Text + Icon)`. No new tests needed: the existing `transit_map_screen_test.dart` already overrides `selectedCityProvider` with `skipHive()`, so it continues to pass after the import is added.

- [ ] **Step 5.1 – Verify existing transit map tests pass (baseline)**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart --no-pub
```

Expected: PASS (all existing tests).

- [ ] **Step 5.2 – Modify transit_map_screen.dart**

**a) Add import** after the last existing import (before `transit_map_painter.dart`):

```dart
import '../city_picker/city_picker_sheet.dart';
```

**b) Replace AppBar title** — find this line in `build()`:

```dart
        title: Text(cityName),
```

Replace with:

```dart
        title: InkWell(
          onTap: () => showCityPickerSheet(context, ref),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cityName),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ],
            ),
          ),
        ),
```

- [ ] **Step 5.3 – Run transit map tests**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart --no-pub
```

Expected: PASS (all tests).

- [ ] **Step 5.4 – Run full suite**

```bash
cd mobile && flutter test --no-pub
```

Expected: all tests pass.

- [ ] **Step 5.5 – Commit**

```bash
cd mobile && git add lib/features/transit_map/transit_map_screen.dart
git commit -m "$(cat <<'EOF'
feat: make TransitMapScreen AppBar title tappable to change city

Title now shows city name + down-chevron icon. Tapping opens
CityPickerSheet so users can switch cities from the map view.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Finishing

After all 5 tasks are committed:

- [ ] **Run full test suite one final time**

```bash
cd mobile && flutter test --no-pub
```

Expected: all tests pass (no regressions).

- [ ] **Use superpowers:finishing-a-development-branch**

Present the 4 options (merge locally / create PR / keep / discard).

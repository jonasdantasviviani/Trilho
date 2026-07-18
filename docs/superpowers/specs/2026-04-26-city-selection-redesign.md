# City Selection Redesign — Design Spec

## Goal

Redesign the city-selection onboarding screen (WelcomeScreen) and add the ability to change the city after the initial selection, from two entry points: the Settings screen and the TransitMapScreen AppBar.

---

## Context

**5 cities** in `CityRegistry.all`. Availability determined by `city.schematicId != null`:

| City | State | `schematicId` | Status |
|------|-------|---------------|--------|
| São Paulo | SP | `'sao-paulo-sp'` | ✅ Disponível |
| Rio de Janeiro | RJ | `null` | 🔜 Em breve |
| Curitiba | PR | `null` | 🔜 Em breve |
| Belo Horizonte | MG | `null` | 🔜 Em breve |
| Porto Alegre | RS | `null` | 🔜 Em breve |

**`CityModel` fields used in this spec** (all exist in `city_model.dart`):
- `id: String` — e.g. `'sao-paulo-sp'`
- `name: String` — e.g. `'São Paulo'`
- `stateCode: String` — e.g. `'SP'`
- `schematicId: String?` — `null` means no schematic

**`selectedCityProvider`**: `StateNotifierProvider<SelectedCityNotifier, CityModel?>` — nullable. `null` on first launch.
`SelectedCityNotifier.skipHive()` exists in `city_provider.dart` — bypasses Hive, for tests.

**Hive `app_prefs` box**: opened in `main()` before `runApp` — always available at runtime.

**`_settingRow` helper** in `settings_screen.dart` signature:
```dart
Widget _settingRow({
  required String icon,       // emoji String, e.g. '🏙️'
  required Color iconBg,
  required String title,
  required String? subtitle,  // nullable — already supported
  required Color textPrimary,
  required Color borderColor,
  required Widget trailing,
  Color subtitleColor = const Color(0xFF888888),
  VoidCallback? onTap,
})
```
No changes to this helper needed.

**`AppTheme.cardDecoration(context)`**: static method in `app_theme.dart` → `BoxDecoration` with surface color, border, shadow.

**`TransitMapScreen`**: already `ConsumerStatefulWidget` — `ref` available in `build()`.

---

## Architecture

### Files modified

| File | Change |
|------|--------|
| `lib/features/city_picker/welcome_screen.dart` | Full rewrite — grid layout |
| `lib/features/city_picker/city_picker_sheet.dart` | Full rewrite — simplified sheet + `ComingSoonDialog` + `cityEmoji()` |
| `lib/features/settings/settings_screen.dart` | Add "LOCALIZAÇÃO" section above "APARÊNCIA" |
| `lib/features/transit_map/transit_map_screen.dart` | AppBar title → `InkWell` with chevron; add import |

### New test files

| File | Purpose |
|------|---------|
| `test/features/city_picker/welcome_screen_test.dart` | Widget tests for WelcomeScreen |
| `test/features/city_picker/city_picker_sheet_test.dart` | Widget tests for CityPickerSheet |

### Unchanged

`lib/core/providers/city_provider.dart`, `lib/router.dart`

---

## Component Designs

### 1. WelcomeScreen

Full-screen route. Router redirects here when no city saved.

**Layout:**
- Top ~35%: gradient header (`AppTheme.primary` → `AppTheme.accent`), `Icons.train` size 56, `"TRILHO"` wordmark (bold, letter-spacing), tagline `"Mobilidade em tempo real"`.
- Bottom ~65%: surface card (`AppTheme.surfaceDark` / `AppTheme.surfaceLight`), `BorderRadius.vertical(top: Radius.circular(24))`, title `"Em qual cidade você está?"`, subtitle `"Você pode mudar depois nas configurações"`.
- Wrapped in `SingleChildScrollView` for small screens.

**City grid (inside surface card):**
- `GridView` `crossAxisCount: 2`, `shrinkWrap: true`, `physics: NeverScrollableScrollPhysics()`, first 4 cities from `CityRegistry.all`.
- 5th city (Porto Alegre) below grid as full-width horizontal `Container` (emoji + name + state code + badge in a `Row`).

**Available city card** (`city.schematicId != null` — only São Paulo today):
- Full opacity.
- `Border.all(color: AppTheme.primary.withValues(alpha: 0.35))`.
- Badge `"Disponível"`: `AppTheme.primary` bg, white text.
- `onTap`:
  ```dart
  ref.read(selectedCityProvider.notifier).select(city);
  if (context.mounted) context.go('/');
  ```
  **No `Navigator.pop`** — WelcomeScreen is a full-screen route, not a sheet.

**Unavailable city card** (`city.schematicId == null`):
- Opacity `0.45`, standard border (`AppTheme.borderDark` / `AppTheme.borderLight`).
- Badge `"Em breve"`: `AppTheme.surfRaisedDark` / `AppTheme.surfRaisedLight` bg, `AppTheme.textSecDark` / `AppTheme.textSecLight` text.
- `onTap`:
  ```dart
  showDialog(context: context, builder: (_) => ComingSoonDialog(city: city));
  ```

---

### 2. `cityEmoji()` helper

**Public top-level function** in `city_picker_sheet.dart`. Used by `ComingSoonDialog`, by `WelcomeScreen` city cards, and by `_CityPickerContent`. `welcome_screen.dart` imports `city_picker_sheet.dart` to access both `ComingSoonDialog` and `cityEmoji`.

```dart
String cityEmoji(CityModel city) => switch (city.id) {
  'sao-paulo-sp'         => '🏙️',
  'rio-de-janeiro-rj'    => '🏖️',
  'curitiba-pr'          => '🌲',
  'belo-horizonte-mg'    => '⛰️',
  'porto-alegre-rs'      => '🌿',
  _                      => '🏙️',
};
```

---

### 3. `ComingSoonDialog`

**Public class** in `city_picker_sheet.dart`.

```dart
class ComingSoonDialog extends StatelessWidget {
  final CityModel city;
  const ComingSoonDialog({super.key, required this.city});
}
```

`AlertDialog`:
- `title`: `Text('${cityEmoji(city)} ${city.name}')`.
- `content`: `Text('Ainda não disponível no Trilho.\nQuer ser avisado quando ${city.name} chegar?')`.
- `"Agora não"` → `Navigator.pop(context)`.
- `"🔔 Me avise"` (primary foreground color):
  ```dart
  // Capture messenger BEFORE Navigator.pop to avoid context detachment
  final messenger = ScaffoldMessenger.of(context);
  try {
    Hive.box('app_prefs').put('notify_city_${city.id}', true);
  } catch (_) {}  // silently ignore — box always open in production
  Navigator.pop(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Anotado! Você será o primeiro a saber.')),
  );
  ```

**No backend.** Local Hive flag only.

---

### 4. `CityPickerSheet` (rewrite of `city_picker_sheet.dart`)

**Public API (unchanged from current):**
```dart
Future<void> showCityPickerSheet(BuildContext context, WidgetRef ref)
```

**Navigation pattern:** the sheet returns the selected `CityModel` to the caller via `Navigator.of(sheetCtx).pop(city)`. The caller handles the Riverpod update and navigation using its **own context** — this avoids any post-pop context detachment issue.

```dart
Future<void> showCityPickerSheet(BuildContext context, WidgetRef ref) async {
  final CityModel? selected = await showModalBottomSheet<CityModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => _CityPickerContent(),
  );
  if (selected != null) {
    ref.read(selectedCityProvider.notifier).select(selected);
    if (context.mounted) context.go('/');
  }
}
```

`_CityPickerContent` is a plain `StatelessWidget` (it reads the provider via the passed `WidgetRef` or by using `Consumer` inside). The sheet's context (`sheetCtx`) is used **only** for pops — navigation uses the caller's `context`.

**`_CityPickerContent`** layout (private `StatelessWidget` or `ConsumerWidget` inside the file):
- Drag handle: 40×4 px `Container`, centered, 8 px vertical padding, `AppTheme.borderDark` / `AppTheme.borderLight`.
- Title `"Trocar cidade"` (`textTheme.titleMedium`), 16 px padding.
- `Divider`.
- `ListView(padding: EdgeInsets.all(16), shrinkWrap: true)` — one city per row.

**City row card** (`Container` with `AppTheme.cardDecoration(context)`, `margin: EdgeInsets.only(bottom: 8)`):
- Row: `Text(cityEmoji(city), style: TextStyle(fontSize: 24))`, `Column(name + stateCode)`, trailing widget.
- **Currently selected** (`city == ref.watch(selectedCityProvider)` or via `Consumer`): border `AppTheme.primary`, trailing `Icon(Icons.check_circle, color: AppTheme.primary)`, `onTap: null` (no re-selection).
- **Available, not selected**: standard decoration, `onTap: () => Navigator.of(context).pop(city)`.
- **Unavailable** (`city.schematicId == null`, opacity 0.45): `onTap: () => showDialog(context: context, builder: (_) => ComingSoonDialog(city: city))`.

---

### 5. SettingsScreen — "LOCALIZAÇÃO" section

`SettingsScreen` is a `ConsumerWidget` — `ref` already available. Add at the top of `build()`:
```dart
final selectedCity = ref.watch(selectedCityProvider);
```

Insert before the `_sectionLabel('APARÊNCIA', ...)` call:
```dart
_sectionLabel('LOCALIZAÇÃO', labelColor),
_card(isDark, cardColor, [
  _settingRow(
    icon: '🏙️',
    iconBg: isDark ? const Color(0xFF1B3A1B) : const Color(0xFFF1F8E9),
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

Add imports:
```dart
import '../../core/providers/city_provider.dart';
import '../city_picker/city_picker_sheet.dart';
```

---

### 6. TransitMapScreen — tappable AppBar title

Replace `title: Text(cityName)` with:
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

`cityName = ref.watch(selectedCityProvider)?.name ?? 'Trilho'` — unchanged.  
Add import: `import '../city_picker/city_picker_sheet.dart';`

---

## Data Flow

```
WelcomeScreen — available city tap:
  ref.read(selectedCityProvider.notifier).select(city)
  if (context.mounted) context.go('/')    // WelcomeScreen's own context — always safe

CityPickerSheet — available city tap:
  Navigator.of(sheetCtx).pop(city)        // sheet pops with result
  ↑ showCityPickerSheet receives the result:
    ref.read(selectedCityProvider.notifier).select(city)
    if (context.mounted) context.go('/')  // CALLER's context — safe (caller still mounted)

Both — unavailable city tap:
  showDialog → ComingSoonDialog
  "Me avise" → capture messenger → try Hive.put → pop → messenger.showSnackBar
  "Agora não" → pop
```

---

## Tests

### `welcome_screen_test.dart`

**Setup:** `UncontrolledProviderScope` wrapping the screen. `ProviderContainer` with:
```dart
selectedCityProvider.overrideWith((_) => SelectedCityNotifier.skipHive())
```
Wrap in `MaterialApp` with a minimal `GoRouter` that has a `/` route (so `context.go('/')` doesn't throw):
```dart
final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const Scaffold()),
  GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
]);
```

1. **Scaffold bg dark** — `Scaffold.backgroundColor == AppTheme.bgDark`.
2. **Scaffold bg light** — `Scaffold.backgroundColor == AppTheme.bgLight`.
3. **São Paulo tap updates provider** — tap São Paulo card; `await tester.pump()` (single frame); assert `container.read(selectedCityProvider)?.id == 'sao-paulo-sp'` *before* `pumpAndSettle` (which would complete navigation).
4. **Curitiba tap shows dialog** — tap Curitiba card; `await tester.pump()`; `find.byType(AlertDialog)` `findsOneWidget`.
5. **"Me avise" shows SnackBar** — after dialog opens, tap `"🔔 Me avise"`; `await tester.pump()`; `find.text('Anotado! Você será o primeiro a saber.')` `findsOneWidget`.

### `city_picker_sheet_test.dart`

**Setup:** `ProviderScope` with `selectedCityProvider` pre-seeded to São Paulo. Wrapped in `MaterialApp` + `Scaffold` + `ElevatedButton` whose `onPressed` calls `showCityPickerSheet(context, ref)`.

1. **Open sheet → checkmark present** — tap button to open sheet; `await tester.pumpAndSettle()`; `find.byIcon(Icons.check_circle)` `findsOneWidget`.
2. **Tap Rio shows dialog** — open sheet; tap Rio de Janeiro row; `await tester.pump()`; `find.byType(AlertDialog)` `findsOneWidget`.
3. **"Me avise" shows SnackBar** — from dialog, tap `"🔔 Me avise"`; `await tester.pump()`; `find.text('Anotado! Você será o primeiro a saber.')` `findsOneWidget`.

---

## Out of Scope

- Backend notification delivery (Hive flag only).
- Search/filter in city picker.
- State grouping.
- Adding new cities to `CityRegistry`.
- Animated transitions.

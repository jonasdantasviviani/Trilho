# UX Polish — Design Spec

**Date:** 2026-03-30
**Milestone:** 3 — UX Polish
**Scope:** Shared state-widget infrastructure + application to all screens

---

## Goal

Replace every silent failure, raw-exception text, and abrupt state transition in the Trilho mobile app with consistent loading, error, and empty states, plus smooth animated transitions between them.

---

## Approach

Layer-by-layer:

1. Build shared widget infrastructure once (`core/widgets/`)
2. Apply to all screens

No screen is redesigned. Visual language stays the same. Only state-handling is improved.

---

## Section 1 — Shared Infrastructure

### New files

**`mobile/lib/core/widgets/app_loading.dart`**

Two named constructors:

- `AppLoading.spinner()` — centered `CircularProgressIndicator` using theme primary color
- `AppLoading.skeleton({required double height, double? width})` — a shimmer box using the `shimmer` package (`Shimmer.fromColors`) with theme surface/surfaceVariant colors

Usage:
```dart
AppLoading.spinner()
AppLoading.skeleton(height: 56)
```

**`mobile/lib/core/widgets/app_error.dart`**

Displays a centered column: icon (`Icons.error_outline`, theme error color) + friendly message + optional retry button.

Constructor:
```dart
AppError({
  required String message,
  VoidCallback? onRetry,
})
```

Never exposes raw exception strings to the user.

**`mobile/lib/core/widgets/app_empty.dart`**

Displays a centered column: icon (caller-provided) + title + optional subtitle.

Constructor:
```dart
AppEmpty({
  required IconData icon,
  required String title,
  String? subtitle,
})
```

**`mobile/lib/core/widgets/app_theme_constants.dart`**

```dart
const Duration kAnimFast   = Duration(milliseconds: 200);
const Duration kAnimNormal = Duration(milliseconds: 350);

Widget fadeSwitch(Widget child) => AnimatedSwitcher(
  duration: kAnimNormal,
  child: child,
  transitionBuilder: (child, animation) =>
      FadeTransition(opacity: animation, child: child),
);
```

### Dependency

Add to `mobile/pubspec.yaml`:
```yaml
shimmer: ^3.0.0
```

---

## Section 2 — Screen-by-Screen Application

### MapScreen (`features/map/map_screen.dart`)

- **Loading:** `AppLoading.skeleton(height: double.infinity)` while map tiles load
- **Location error:** `AppError(message: 'Não foi possível obter sua localização', onRetry: ...)`
- **Transition:** `AnimatedSwitcher` (kAnimNormal) between skeleton → map

### LineDetailScreen (`features/line_detail/line_detail_screen.dart`)

- **Loading:** list of `AppLoading.skeleton(height: 56)` (~5 items)
- **Error:** `AppError(message: 'Não foi possível carregar as estações', onRetry: () => ref.invalidate(...))`
- **Empty:** `AppEmpty(icon: Icons.directions_transit, title: 'Nenhuma estação encontrada')`
- **Transition:** `AnimatedSwitcher` with fade between all three states

### StationDetailScreen (`features/station_detail/station_detail_screen.dart`)

- **Loading:** skeleton for occupancy indicator circle + 2 text lines
- **Error:** `AppError` replacing raw `Text('Erro: $e')` strings
- **Transition:** `AnimatedSwitcher` on occupancy indicator when data refreshes

### SettingsScreen (`features/settings/settings_screen.dart`)

- **Notification toggle error:** `AppError` inline (replaces silent `SizedBox.shrink()`)
- **Premium status transition:** `AnimatedSwitcher` (kAnimNormal) between free/premium UI

### PaywallScreen (`features/paywall/paywall_screen.dart`)

- **Purchase confirmation:** `AnimatedSwitcher` with `ScaleTransition` on success icon (✓) after payment confirmed — replaces abrupt content swap
- **Loading state:** inline progress indicator on purchase button (already partial; make consistent with `AppLoading.spinner()` style)

### SubscriptionScreen / inline subscription state

- **Verifying subscription:** `AppLoading.spinner()` while checking RevenueCat
- **Verification error:** `AppError(message: 'Não foi possível verificar sua assinatura', onRetry: ...)`

---

## Error Handling Rules

1. Never show raw exception text to the user (`'Erro: $e'` → `AppError`)
2. Always offer a retry where recovery is possible (network errors, API failures)
3. Silent failures (`SizedBox.shrink()`) are forbidden — use `AppError` without retry for non-recoverable states
4. Empty states are first-class — a screen with no data is never indistinguishable from loading

---

## Animation Rules

1. All state transitions use `AnimatedSwitcher` with `kAnimNormal` (350ms) by default
2. Success/confirmation animations use `ScaleTransition` (scale up from 0 → 1)
3. No `AnimatedSwitcher` for in-place data refreshes (e.g., occupancy number updating) — those update directly
4. Never animate layout shifts; only fade/scale widget replacements

---

## Out of Scope

- Redesigning any screen's visual layout
- Adding new features or data
- Changing color palette, typography, or spacing
- Onboarding animations or splash screens

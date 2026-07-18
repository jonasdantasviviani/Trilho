# Trilho — UI Documentation

**Version:** 1.0
**Last updated:** 2026-03-21
**Platform:** Flutter (Android & iOS)
**Audience:** Developers, designers, QA engineers

---

## Table of Contents

1. [Overview](#1-overview)
2. [Design Tokens](#2-design-tokens)
3. [Navigation Architecture](#3-navigation-architecture)
4. [Screen-by-Screen Reference](#4-screen-by-screen-reference)
   - 4.1 [LoginScreen](#41-loginscreen)
   - 4.2 [WelcomeScreen](#42-welcomescreen)
   - 4.3 [MapScreen](#43-mapscreen)
   - 4.4 [CityPickerSheet](#44-citypickersheet)
   - 4.5 [SettingsScreen](#45-settingsscreen)
5. [Reusable Components](#5-reusable-components)
   - 5.1 [CityChip](#51-citychip)
6. [Accessibility Guide](#6-accessibility-guide)
7. [Theming](#7-theming)

---

## 1. Overview

**Trilho** is a real-time public transit crowding app for Brazil. It aggregates line-level crowding reports from commuters and displays them on an interactive map, helping riders make informed decisions before boarding.

### Design Philosophy

| Pillar | Approach |
|---|---|
| Design system | Material 3 (Material You) — dynamic color roles, expressive shapes |
| Locale | Brazilian Portuguese (`pt_BR`) throughout all copy |
| Business model | Freemium — anonymous and authenticated free tiers, premium paywall |
| Platforms | Android-first; iOS parity with platform-specific affordances (Apple Sign-In) |
| Accessibility | Full VoiceOver/TalkBack support via Flutter `Semantics` API |

### Key User Journey

1. User opens the app for the first time.
2. Authenticates (social login or anonymous).
3. Selects their city (onboarding wizard or persistent city picker).
4. Views the map with colored line chips showing real-time crowding.
5. Taps a line/station for detail and can report crowding (subject to usage limits).

---

## 2. Design Tokens

### 2.1 Color

The entire color system derives from a single Material 3 seed:

```dart
Color seedColor = Color(0xFF1565C0); // Deep Blue
```

Material 3 generates a full tonal palette (primary, secondary, tertiary, error, neutral, neutral-variant) for both light and dark schemes. Never hard-code hex values outside the theme; always reference `ColorScheme` roles.

**Key color roles used in the UI:**

| Role | Usage |
|---|---|
| `primary` | Hero gradient start, active chips, filled buttons, selected state icons |
| `primaryContainer` | Hero gradient end |
| `surface` | Card backgrounds, bottom sheet background |
| `surfaceContainerHighest` | Search field fill |
| `onSurface` | Body text, icons on surface |
| `onPrimary` | Text/icons on primary-colored surfaces |
| `outline` | Chip borders, OutlinedButton borders |
| `error` | Validation errors |

**Gradient (hero sections):**

```dart
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    colorScheme.primary,
    colorScheme.primaryContainer,
  ],
)
```

**Derived chip colors (line chips on map):**

Each transit line exposes a hex color code from the API. The chip background is applied at **12% opacity** of that color; the border uses the full color at full opacity.

**State avatar colors (CityPickerSheet):**

State abbreviation avatars use a color derived deterministically from a hash of the state code string. This ensures consistent coloring without a lookup table.

### 2.2 Typography

All styles come from Material 3's default type scale. No custom font family is specified — the platform default (Roboto on Android, SF Pro on iOS) is used.

| Style | Usage |
|---|---|
| `displaySmall` | "Trilho" hero title on WelcomeScreen |
| `headlineSmall` | Section heading inside cards ("Entrar", "Em qual cidade você está?") |
| `titleLarge` | Bottom sheet header ("Escolha sua cidade"), settings list headings |
| `titleMedium` | Login card subtitle |
| `bodyMedium` | General body text, hero subtitle on WelcomeScreen |
| `bodySmall` | Secondary labels (e.g., "Funcionalidades limitadas" on anonymous button) |
| `labelMedium` | Chip labels, city/state count subtitles |

**LoginScreen hero title** is styled manually (not via theme):

```dart
TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)
```

**LoginScreen hero subtitle:**

```dart
TextStyle(fontSize: 14, color: Colors.white70)
```

### 2.3 Spacing System

All values are in logical pixels (dp).

| Token name (conceptual) | Value | Usage |
|---|---|---|
| `screenPaddingH` | 24 | Horizontal padding on all screen card content |
| `sectionTopPadding` | 28 | Padding above a major section heading |
| `itemSpacingSmall` | 12 | Gap between social buttons, chip separator |
| `itemSpacingMedium` | 16 | Gap between form fields |
| `itemSpacingSectionLarge` | 24 | Gap between major content sections |
| `heroHeightLogin` | 45% of screen height | Gradient hero on LoginScreen |
| `heroHeightWelcome` | 40% of screen height | Gradient hero on WelcomeScreen |
| `lineChipListHeight` | 52 | Fixed height of horizontal line chip list on MapScreen |
| `lineChipHPadding` | 12 | Horizontal padding inside line chip list |
| `lineChipVPadding` | 6 | Vertical padding inside line chip list |
| `socialButtonHeight` | 52 | Height of social login OutlinedButtons |
| `anonymousButtonVPadding` | 14 | Vertical padding of anonymous TextButton |
| `dragHandleWidth` | 40 | Width of bottom sheet drag handle |
| `dragHandleHeight` | 4 | Height of bottom sheet drag handle |
| `cityListIndent` | 72 | Left indent for city ListTiles inside ExpansionTile |

### 2.4 Border Radii

| Component | Radius |
|---|---|
| Login card top corners | 28 px |
| Welcome card top corners | 24 px |
| Bottom sheet top corners | 16 px |
| Social login buttons | 12 px |
| Text inputs | 12 px |
| Anonymous/TextButton | 12 px |
| Line chips (ActionChip) | default (stadium) |
| Drag handle | 2 px |

### 2.5 Shadows / Elevation

**Login card:**

```dart
BoxShadow(
  blurRadius: 16,
  offset: Offset(0, -4),
  color: Colors.black.withOpacity(0.12),
)
```

No custom shadows on other surfaces — elevation is handled by Material 3 tonal elevation automatically.

---

## 3. Navigation Architecture

### 3.1 Flow Diagram

```
App Launch
    |
    +-- Not authenticated ---------> /login (LoginScreen)
    |                                     |
    |                                     | sign-in success
    |                                     v
    +-- Authenticated, no city ------> /welcome (WelcomeScreen)
    |                                     |
    |                                     | city selected
    |                                     v
    +-- Authenticated + city ---------> / (MapScreen)
                                          |
                        +-----------------+-----------------+
                        |                 |                 |
                  tap line chip      tap station     tap settings
                        |                 |                 |
                 /line/:code       /station/:id        /settings
              (LineDetailScreen) (StationDetailScreen) (SettingsScreen)
                                                            |
                                                     tap upgrade
                                                            |
                                                       /paywall
                                                   (PaywallScreen)
```

### 3.2 Route Table

| Route | Screen | Guard |
|---|---|---|
| `/` | `MapScreen` | Requires auth + city |
| `/login` | `LoginScreen` | Public |
| `/welcome` | `WelcomeScreen` | Requires auth, no city |
| `/line/:code` | `LineDetailScreen` | Requires auth + city |
| `/station/:id` | `StationDetailScreen` | Requires auth + city |
| `/paywall` | `PaywallScreen` | Requires auth |
| `/settings` | `SettingsScreen` | Requires auth |

Router: **go_router**. Redirect logic reads `authServiceProvider` and `selectedCityProvider` to determine the appropriate starting route.

### 3.3 City Picker Access Points

The city picker is accessible from two places:

1. **WelcomeScreen** — inline DropdownButtonFormField + ListView (onboarding flow).
2. **MapScreen** — tapping `CityChip` in the AppBar opens `CityPickerSheet` as a modal bottom sheet from any screen where the user is already authenticated.

---

## 4. Screen-by-Screen Reference

### 4.1 LoginScreen

**File:** `mobile/lib/features/auth/login_screen.dart`
**Route:** `/login`
**Purpose:** Authenticate the user before accessing the app. Supports social login and anonymous access.

#### Layout

The screen is divided into two stacked regions with no scroll:

```
┌────────────────────────────────┐
│                                │ ← gradient hero (45% height)
│    [train icon 80px]           │
│    Trilho  (36px bold)         │
│    subtitle (14px, white70)    │
│                                │
├────────────────────────────────┤  ← top-left/right radius 28px
│                                │
│  Entrar  (headlineSmall)       │ ← surface card (55% height)
│  subtitle (titleMedium)        │
│                                │
│  [Google button   52px]        │
│  [Apple button    52px] ← iOS  │
│  [Facebook button 52px]        │
│                                │
│  ────── ou ──────              │
│                                │
│  Continuar sem conta           │
│  Funcionalidades limitadas     │
│                                │
└────────────────────────────────┘
```

#### Key Measurements

| Element | Value |
|---|---|
| Hero height | 45% of screen height |
| Card top corner radius | 28 px |
| Train icon size | 80 px, white |
| Social button height | 52 px |
| Social button icon size | 28 px |
| Social button border radius | 12 px |
| Social button border width | 1 px (`outline` color) |
| Gap between social buttons | 12 px |
| Divider side padding | 24 px |
| Anonymous button vertical padding | 14 px |
| Anonymous button border radius | 12 px |
| Card horizontal content padding | 24 px |

#### Social Login Buttons

Each `OutlinedButton` follows this pattern:

```
[Icon 28px]  [Label text]
```

While the auth call is in-flight, the icon is replaced by a `CircularProgressIndicator` (size 20 px, stroke 2 px). The button remains tappable area but the loading state signals action in progress.

**Platform-specific:** The Apple Sign-In button is only rendered on iOS, gated by a platform check at build time.

#### Anonymous Button

Two-line `TextButton`. Line 1 is the primary call-to-action ("Continuar sem conta"). Line 2, in `bodySmall` + secondary color, reads "Funcionalidades limitadas", informing users they will have reduced access.

#### Accessibility

- Hero region wrapped in `Semantics(header: true, label: 'Trilho, login')` with children inside `ExcludeSemantics`.
- Each social button: `Semantics(label: 'Entrar com Google', button: true, enabled: !isLoading)`.
- Anonymous button: `Semantics(label: 'Continuar sem conta. Funcionalidades limitadas', button: true)`.
- Loading indicator: `Semantics(liveRegion: true)`.

---

### 4.2 WelcomeScreen

**File:** `mobile/lib/features/city_picker/welcome_screen.dart`
**Route:** `/welcome`
**Purpose:** First-launch onboarding. Prompts the user to choose their city before reaching the map.

#### Layout

```
┌────────────────────────────────┐
│                                │ ← gradient hero (40% height)
│    [train icon 72px]           │
│    Trilho  (displaySmall)      │
│    subtitle (bodyMedium 70%w)  │
│                                │
├────────────────────────────────┤  ← top-left/right radius 24px
│                                │
│  Em qual cidade você está?     │ ← surface card (60% height)
│  (headlineSmall)               │
│  subtitle (bodyMedium)         │
│                                │
│  ┌──────────────────────────┐  │
│  │ 🗺 Selecionar estado  ▼  │  │ ← DropdownButtonFormField
│  └──────────────────────────┘  │
│                                │
│  [Animated list of cities]     │ ← AnimatedSwitcher 200ms
│    📍 São Paulo      >         │
│    📍 Campinas       >         │
│    ...                         │
│                                │
└────────────────────────────────┘
```

#### Key Measurements

| Element | Value |
|---|---|
| Hero height | 40% of screen height |
| Card top corner radius | 24 px |
| Train icon size | 72 px, white |
| Dropdown border radius | 12 px |
| Dropdown prefix icon | `map_outlined` |
| City list tile leading icon | `location_on` |
| City list tile trailing icon | `chevron_right` |
| List animation duration | 200 ms |

#### State Behavior

1. **Initial state:** Dropdown shows "Selecionar estado" placeholder. City list is empty.
2. **State selected:** Dropdown reflects state name. City list animates in (200 ms crossfade) showing cities for that state.
3. **City tapped:** Updates `selectedCityProvider`, navigates to `/`.

#### Accessibility

- Hero: `Semantics(header: true)` + `ExcludeSemantics` on children.
- Dropdown: standard form field semantics (label auto-provided by `InputDecoration`).
- City tiles: default `ListTile` semantics; trailing chevron inside `ExcludeSemantics`.

---

### 4.3 MapScreen

**File:** `mobile/lib/features/map/map_screen.dart`
**Route:** `/` (home)
**Purpose:** Primary screen. Shows an interactive map with transit line chips indicating crowding levels.

#### Layout

```
┌────────────────────────────────┐
│ AppBar: [CityChip]   [⚙ icon] │ ← settings tooltip: 'Configurações'
├────────────────────────────────┤
│ [Line 1] [Line 2] [⚠Line 3]  │ ← horizontal chip list (52px height)
├────────────────────────────────┤
│                                │
│         Google Map             │ ← Expanded, fills remaining height
│                                │
│                                │
└────────────────────────────────┘
```

#### AppBar

- **Title:** `CityChip` widget (see [Section 5.1](#51-citychip)).
- **Actions:** Single `IconButton` with `Icons.settings`, tooltip `'Configurações'`, navigates to `/settings`.

#### Line Chip List

A horizontally scrollable `ListView.separated` with fixed height 52 px, horizontal padding 12 px, and vertical padding 6 px between the AppBar and the map.

Each chip is an `ActionChip` with:

| Property | Value |
|---|---|
| Background color | Line color at 12% opacity |
| Side border | `BorderSide(color: lineColor, width: 1.5)` |
| Label | Line name/code |
| Avatar | Warning icon (`warning_amber_rounded`) when status != Normal; hidden otherwise |
| On tap | Navigates to `/line/:code` |

Separator between chips: `SizedBox(width: 8)`.

#### States

| State | UI |
|---|---|
| Loading | `Center(child: CircularProgressIndicator())` fills the map area |
| Error | `Column` with `Icons.wifi_off`, error message text, `TextButton('Tentar novamente')` |
| Success | Map + chip list as described above |

#### Accessibility

- Settings button: `Tooltip(message: 'Configurações')`.
- Line chips: default `ActionChip` semantics with label text.
- Warning icon on chips: `ExcludeSemantics` (status communicated via label or separate live region).
- Loading indicator: `Semantics(liveRegion: true)`.

---

### 4.4 CityPickerSheet

**File:** `mobile/lib/features/city_picker/city_picker_sheet.dart`
**Purpose:** Full-featured city search and selection, available from MapScreen via `CityChip` tap.

#### Presentation

Shown as a modal bottom sheet using `DraggableScrollableSheet`:

| Property | Value |
|---|---|
| Initial size | 75% of screen height |
| Min size | 40% of screen height |
| Max size | 95% of screen height |
| Top corner radius | 16 px |

#### Layout

```
┌────────────────────────────────┐
│         ──── (drag handle)     │ ← 40×4px, borderRadius 2, 40% opacity
│  Escolha sua cidade            │ ← titleLarge bold
│ ┌──────────────────────────┐   │
│ │ 🔍 Buscar cidade...    ✕ │   │ ← filled TextField
│ └──────────────────────────┘   │
├────────────────────────────────┤
│ ▶ São Paulo           (N cid.) │ ← ExpansionTile (collapsed)
│ ▼ Rio de Janeiro      (N cid.) │ ← ExpansionTile (expanded)
│     📍 Rio de Janeiro  ✓       │   ← ListTile (selected, indent 72px)
│     📍 Niterói                 │
│ ▶ Minas Gerais        (N cid.) │
│ ...                            │
└────────────────────────────────┘
```

#### Search Field

- Style: `filled` with `surfaceContainerHighest` fill color, no border in any state.
- Prefix: `Icons.search`.
- Suffix: `IconButton(Icons.clear)` with tooltip `'Limpar busca'`; only visible when the search text is non-empty.
- Behavior: filters both state ExpansionTiles and city ListTiles in real-time as user types.

#### State Groups (ExpansionTile)

Each Brazilian state is represented by an `ExpansionTile`:

| Element | Detail |
|---|---|
| Leading | `CircleAvatar` — background color derived from state code hash, text is the 2-letter state abbreviation |
| Title | Full state name |
| Subtitle | City count, e.g., "3 cidades" |

#### City Tiles (ListTile inside ExpansionTile)

| Element | Detail |
|---|---|
| Left indent | 72 px |
| Leading | `Icons.location_on` |
| Title | City name |
| Trailing | `Icons.check_circle` (primary color) when city is the currently selected city; absent otherwise |

Tapping a city tile writes to `selectedCityProvider` and closes the sheet.

#### Accessibility

- Drag handle: `ExcludeSemantics`.
- Header: `Semantics(header: true)`.
- Search field: label provided via `InputDecoration.hintText`; clear button tooltip `'Limpar busca'`.
- State avatars: `ExcludeSemantics` (decorative color grouping).
- Selected city tile: trailing check icon in `ExcludeSemantics`; selected state communicated via `Semantics(selected: true)` on the `ListTile`.

---

### 4.5 SettingsScreen

**File:** `mobile/lib/features/settings/settings_screen.dart`
**Route:** `/settings`
**Purpose:** Displays account/plan status and provides access to privacy policy and app information.

#### Layout

```
┌────────────────────────────────┐
│ AppBar: Configurações          │
├────────────────────────────────┤
│                                │
│ ⭐ Plano Premium               │ ← ListTile (or "Plano Gratuito")
│    X consultas realizadas      │   subtitle shows usage count
│                                │
│  [Fazer upgrade]               │ ← only shown for free users
│                                │
│ ─────────────────────────────  │ ← Divider
│                                │
│ 🔒 Privacidade                 │ ← opens AlertDialog
│                                │
│ ℹ Sobre o Trilho               │ ← calls showAboutDialog()
│                                │
└────────────────────────────────┘
```

#### Plan Status Tile

- **Icon:** `Icons.star_rounded` (gold/amber color for premium, grey for free).
- **Title:** "Plano Premium" or "Plano Gratuito".
- **Subtitle:** Usage count string, e.g., "47 consultas realizadas".

#### Upgrade Tile

Only rendered when the user is on the free plan. Uses `Icons.upgrade` as leading icon. Tapping navigates to `/paywall`.

#### Privacy Dialog

`AlertDialog` with the app's privacy policy text. Contains a single "Fechar" action button.

#### About Dialog

Standard Flutter `showAboutDialog()` call — shows app name, version, and licenses.

#### Accessibility

- All `ListTile` entries use their built-in semantics.
- Icons: decorative, inside `ExcludeSemantics`.
- Dialog actions have default button semantics.

---

## 5. Reusable Components

### 5.1 CityChip

**File:** `mobile/lib/core/widgets/city_chip.dart`
**Used in:** `MapScreen` AppBar title slot.

#### Purpose

A persistent, tappable chip in the AppBar that always shows the user's currently selected city. Tapping opens the `CityPickerSheet` from any map-state screen.

#### States

| State | Label | Icon |
|---|---|---|
| No city selected | `"Selecionar cidade"` | `Icons.add_location_alt` |
| City selected | `"${stateCode} · ${cityName}"` (e.g., `"SP · São Paulo"`) | `Icons.location_city` |

#### Widget Anatomy

```dart
Semantics(
  label: '<full accessible label>',
  button: true,
  child: ExcludeSemantics(
    child: ActionChip(
      label: Text(label),
      avatar: Icon(icon),
      onPressed: () => showModalBottomSheet(...), // CityPickerSheet
    ),
  ),
)
```

#### Accessibility Labels

| State | Semantics label |
|---|---|
| No city | `"Selecionar cidade, botão"` |
| City selected | `"Cidade selecionada: São Paulo, SP. Toque para alterar."` |

The outer `Semantics` provides the full, human-readable label. The inner `ExcludeSemantics` suppresses the raw chip label and icon from the accessibility tree, preventing double-reading.

#### Behavior

- The chip uses `ActionChip.onPressed` to trigger the bottom sheet.
- `selectedCityProvider` drives the displayed label; the widget rebuilds automatically via `ConsumerWidget` / `ref.watch`.
- No explicit loading state — the city picker sheet handles its own loading.

---

## 6. Accessibility Guide

### 6.1 General Semantics Patterns

Trilho follows a consistent Semantics layering strategy:

#### Pattern A — Hero / Decorative Sections

Decorative illustrations, gradient backgrounds, and their child widgets are excluded from the a11y tree. A single parent `Semantics` node describes the section.

```dart
Semantics(
  header: true,
  label: 'Trilho — aplicativo de mobilidade urbana',
  child: ExcludeSemantics(
    child: heroContent,
  ),
)
```

#### Pattern B — Interactive Buttons with Custom Layout

Buttons whose visual design combines multiple widgets (icon + text) use `Semantics` at the outer container and `ExcludeSemantics` on children:

```dart
Semantics(
  label: 'Entrar com Google',
  button: true,
  enabled: !isLoading,
  child: ExcludeSemantics(
    child: OutlinedButton(/* icon + text */),
  ),
)
```

#### Pattern C — Section Headings

Non-AppBar text that acts as a visual section header uses `header: true`:

```dart
Semantics(
  header: true,
  child: Text('Em qual cidade você está?', style: headlineSmall),
)
```

#### Pattern D — Live Regions

Asynchronous state changes (loading indicators, error messages) are wrapped with `liveRegion: true` so screen readers announce the change automatically:

```dart
Semantics(
  liveRegion: true,
  child: CircularProgressIndicator(),
)
```

### 6.2 Tooltips on Icon Buttons

Every standalone `IconButton` carries a `Tooltip` for long-press accessibility:

| Button | Tooltip |
|---|---|
| Settings (MapScreen AppBar) | `'Configurações'` |
| Clear search (CityPickerSheet) | `'Limpar busca'` |

### 6.3 Labels Strategy

| Element type | Strategy |
|---|---|
| Social login buttons | Full action phrase: "Entrar com Google" |
| Anonymous button | Combined primary + secondary text: "Continuar sem conta. Funcionalidades limitadas." |
| CityChip (no city) | "Selecionar cidade, botão" |
| CityChip (city selected) | "Cidade selecionada: {name}, {stateCode}. Toque para alterar." |
| City ListTile (selected) | `Semantics(selected: true)` on tile |
| Decorative icons | Wrapped in `ExcludeSemantics` |
| Section headings | `Semantics(header: true)` |

### 6.4 VoiceOver / TalkBack Test Checklist

Use this checklist when testing each screen with a screen reader:

#### LoginScreen
- [ ] Hero region announced as a single heading, not individual widgets.
- [ ] "Entrar com Google" button is announced with its full label.
- [ ] Apple button absent on Android (no phantom element).
- [ ] Loading state triggers a live region announcement.
- [ ] Anonymous button announces both lines as one label.
- [ ] Tab order: Hero → "Entrar" heading → social buttons (top to bottom) → divider (skipped) → anonymous button.

#### WelcomeScreen
- [ ] Hero announced as heading.
- [ ] Dropdown announces its current value and role.
- [ ] City list items announced with name and correct trailing action.
- [ ] Animated list switch does not confuse the focus system.

#### MapScreen
- [ ] CityChip announced as a button with full city label.
- [ ] Settings button announced with tooltip text.
- [ ] Line chips announced with line name; warning status communicated.
- [ ] Loading indicator triggers live region.
- [ ] Error state: wifi_off icon is decorative, error message and retry button are readable.

#### CityPickerSheet
- [ ] Sheet announced as a dialog/panel on open.
- [ ] Search field focuses automatically (if implemented).
- [ ] Clear button tooltip readable; button hidden from tree when field is empty.
- [ ] State avatars decorative (not announced).
- [ ] Selected city tile announced as "selected".
- [ ] ExpansionTile expand/collapse state is communicated.

#### SettingsScreen
- [ ] Plan status tile announces both title and subtitle.
- [ ] Upgrade tile only appears and is announced for free users.
- [ ] Privacy dialog close button reachable.
- [ ] About dialog license list navigable.

---

## 7. Theming

### 7.1 Theme Setup

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF1565C0),
    brightness: Brightness.light, // or Brightness.dark
  ),
)
```

Both light and dark themes are generated with the same seed. The `brightness` parameter is toggled based on the system setting. Trilho does not expose a manual theme toggle in the UI (follows system preference).

### 7.2 Light vs. Dark Mode

| Surface | Light | Dark |
|---|---|---|
| App background | White / `surface` | Dark grey / `surface` (dark) |
| Hero gradient | `primary` → `primaryContainer` (blue range) | Same roles — appear darker but retain blue hue |
| Cards / bottom sheet | White `surface` | Elevated dark `surface` |
| Chip backgrounds | Line color at 12% opacity | Same — line color at 12% opacity |
| Text on surface | Near-black `onSurface` | Near-white `onSurface` |
| Text on hero | `Colors.white` / `Colors.white70` (hardcoded — always white regardless of mode) |

> **Note:** The hero gradient text uses hardcoded `Colors.white` and `Colors.white70` because the gradient is always dark enough to guarantee contrast. This is intentional and does not need theming.

### 7.3 Where the Seed Color Appears

| Location | Color role |
|---|---|
| Hero gradient (all screens) | `primary` + `primaryContainer` |
| Active/selected state (chips, icons) | `primary` |
| Filled primary buttons (if any) | `primary` background, `onPrimary` text |
| OutlinedButton borders | `outline` (derived from seed) |
| Search field fill | `surfaceContainerHighest` |
| Check circle (selected city) | `primary` |
| Focus rings, ripples | `primary` with opacity |

### 7.4 Custom Component Theming

No component-level `ThemeData` overrides (e.g., `ChipThemeData`, `ButtonThemeData`) are defined beyond the global `ColorScheme`. Components rely on Material 3 defaults for shape, padding, and color derivation.

If shape or padding overrides are needed for a specific component in the future, add them to the `ThemeData` constructor in the app's theme file rather than inline in widget code.

---

*This document is generated from the Trilho codebase as of version 1.0. For questions, open an issue or contact the mobile team.*

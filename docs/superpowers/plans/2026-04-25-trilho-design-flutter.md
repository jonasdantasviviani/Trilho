# Trilho Flutter Design System Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved Trilho design system spec to the Flutter app — updating AppTheme tokens and removing hardcoded colors from all screens.

**Architecture:** Single source of truth in `app_theme.dart` (ThemeData) + `app_colors.dart` (semantic/crowd colors). All screens read from `Theme.of(context)` or `AppColors`; no hardcoded hex values anywhere.

**Tech Stack:** Flutter, Material 3, google_fonts (Inter), flutter_riverpod

**Spec reference:** `docs/superpowers/specs/2026-04-25-trilho-design-system.md`

---

## Chunk 1: Theme tokens + color constants

### Task 1: Update `app_theme.dart` with spec tokens

**Files:**
- Modify: `mobile/lib/core/widgets/app_theme.dart`
- Modify: `mobile/test/core/widgets/app_theme_test.dart`

- [ ] **Step 1: Update the failing tests first**

Replace `mobile/test/core/widgets/app_theme_test.dart` with tests that assert the new spec values:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trilho/core/widgets/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('darkTheme scaffold bg is #0A0A14', (tester) async {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0A14));
    await tester.pumpAndSettle();
  });

  testWidgets('lightTheme scaffold bg is #F5F5F7', (tester) async {
    final theme = AppTheme.light();
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F5F7));
    await tester.pumpAndSettle();
  });

  testWidgets('darkTheme primary is #0055FF', (tester) async {
    final theme = AppTheme.dark();
    expect(theme.colorScheme.primary, const Color(0xFF0055FF));
    await tester.pumpAndSettle();
  });

  testWidgets('darkTheme secondary is #00C8FF', (tester) async {
    final theme = AppTheme.dark();
    expect(theme.colorScheme.secondary, const Color(0xFF00C8FF));
    await tester.pumpAndSettle();
  });

  testWidgets('lightTheme primary is #0055FF', (tester) async {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, const Color(0xFF0055FF));
    await tester.pumpAndSettle();
  });

  testWidgets('bodyMedium fontFamily is Inter (both modes)', (tester) async {
    expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily,  contains('Inter'));
    expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, contains('Inter'));
    await tester.pumpAndSettle();
  });

  testWidgets('cardDecoration dark bg is #13131F (surface)', (tester) async {
    late BoxDecoration decoration;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(builder: (ctx) {
          decoration = AppTheme.cardDecoration(ctx);
          return const SizedBox();
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(decoration.color, const Color(0xFF13131F));
  });

  testWidgets('cardDecoration light bg is #FFFFFF', (tester) async {
    late BoxDecoration decoration;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(builder: (ctx) {
          decoration = AppTheme.cardDecoration(ctx);
          return const SizedBox();
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(decoration.color, const Color(0xFFFFFFFF));
  });
}
```

- [ ] **Step 2: Run test to confirm failures**

```
cd mobile && flutter test test/core/widgets/app_theme_test.dart
```

Expected: 3–4 failures (bg values changed, primary changed).

- [ ] **Step 3: Rewrite `app_theme.dart`**

Replace the full file content:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary  = Color(0xFF0055FF); // --color-primary
  static const Color accent   = Color(0xFF00C8FF); // --color-accent

  // ── Dark tokens ───────────────────────────────────────────────────────────
  static const Color bgDark          = Color(0xFF0A0A14); // --color-bg
  static const Color surfaceDark     = Color(0xFF13131F); // --color-surface
  static const Color surfRaisedDark  = Color(0xFF1C1C2E); // --color-surface-raised
  static const Color borderDark      = Color(0xFF2A2A3A); // --color-border
  static const Color textPrimDark    = Color(0xFFFFFFFF); // --color-text-primary
  static const Color textSecDark     = Color(0xFF8888AA); // --color-text-secondary
  static const Color textDisDark     = Color(0xFF444455); // --color-text-disabled

  // ── Light tokens ──────────────────────────────────────────────────────────
  static const Color bgLight         = Color(0xFFF5F5F7); // --color-bg
  static const Color surfaceLight    = Color(0xFFFFFFFF); // --color-surface
  static const Color surfRaisedLight = Color(0xFFEFEFEF); // --color-surface-raised
  static const Color borderLight     = Color(0xFFE0E0E8); // --color-border
  static const Color textPrimLight   = Color(0xFF0A0A14); // --color-text-primary
  static const Color textSecLight    = Color(0xFF555566); // --color-text-secondary
  static const Color textDisLight    = Color(0xFFAAAABC); // --color-text-disabled

  // ── Text themes ───────────────────────────────────────────────────────────
  static TextTheme _textTheme(Color textColor, Color secondaryColor) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5),
      displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5),
      titleLarge:   GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.3),
      titleMedium:  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
      bodyLarge:    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
      bodyMedium:   GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: textColor),
      bodySmall:    GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: secondaryColor),
      labelSmall:   GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: secondaryColor, letterSpacing: 1.0),
    );
  }

  // ── Light ─────────────────────────────────────────────────────────────────
  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary:    primary,
      secondary:  accent,
      surface:    surfaceLight,
      onSurface:  textPrimLight,
    );
    return ThemeData(
      useMaterial3:          true,
      colorScheme:           cs,
      scaffoldBackgroundColor: bgLight,
      textTheme:             _textTheme(textPrimLight, textSecLight),
      dividerColor:          borderLight,
      cardTheme: CardThemeData(
        color:     surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:    bgLight,
        surfaceTintColor:   Colors.transparent,
        elevation:          0,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimLight),
        iconTheme:          const IconThemeData(color: textPrimLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: textSecLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Dark ──────────────────────────────────────────────────────────────────
  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary:    primary,
      secondary:  accent,
      surface:    surfaceDark,
      onSurface:  textPrimDark,
    );
    return ThemeData(
      useMaterial3:           true,
      colorScheme:            cs,
      scaffoldBackgroundColor: bgDark,
      textTheme:              _textTheme(textPrimDark, textSecDark),
      dividerColor:           borderDark,
      cardTheme: CardThemeData(
        color:     surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  bgDark,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimDark),
        iconTheme:        const IconThemeData(color: textPrimDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: surfRaisedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: textSecDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static BoxDecoration cardDecoration(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? surfaceDark : surfaceLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: dark ? borderDark : borderLight),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.30 : 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration surfaceRaisedDecoration(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? surfRaisedDark : surfRaisedLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: dark ? borderDark : borderLight),
    );
  }
}
```

- [ ] **Step 4: Run tests — expect pass**

```
cd mobile && flutter test test/core/widgets/app_theme_test.dart
```

Expected: all 8 pass.

- [ ] **Step 5: Commit**

```
git add mobile/lib/core/widgets/app_theme.dart mobile/test/core/widgets/app_theme_test.dart
git commit -m "feat(flutter): update AppTheme to spec design tokens"
```

---

### Task 2: Create `app_colors.dart` — semantic + crowd colors

**Files:**
- Create: `mobile/lib/core/widgets/app_colors.dart`
- Create: `mobile/test/core/widgets/app_colors_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/widgets/app_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_colors.dart';

void main() {
  group('AppColors.forDensity', () {
    test('density 0.05 → crowdEmpty', () {
      expect(AppColors.forDensity(0.05), AppColors.crowdEmpty);
    });
    test('density 0.25 → crowdLow', () {
      expect(AppColors.forDensity(0.25), AppColors.crowdLow);
    });
    test('density 0.50 → crowdModerate', () {
      expect(AppColors.forDensity(0.50), AppColors.crowdModerate);
    });
    test('density 0.70 → crowdHigh', () {
      expect(AppColors.forDensity(0.70), AppColors.crowdHigh);
    });
    test('density 1.00 → crowdFull', () {
      expect(AppColors.forDensity(1.00), AppColors.crowdFull);
    });
  });

  test('crowd label Vazio for density 0.0', () {
    expect(AppColors.crowdLabel(0.0), 'Vazio');
  });
  test('crowd label Moderado for density 0.55', () {
    expect(AppColors.crowdLabel(0.55), 'Moderado');
  });
  test('crowd label Lotado for density 1.0', () {
    expect(AppColors.crowdLabel(1.0), 'Lotado');
  });
}
```

- [ ] **Step 2: Run to confirm failure**

```
cd mobile && flutter test test/core/widgets/app_colors_test.dart
```

Expected: compilation error (file not found).

- [ ] **Step 3: Create `app_colors.dart`**

```dart
// mobile/lib/core/widgets/app_colors.dart
import 'package:flutter/material.dart';

/// Static semantic and crowd-density color constants.
/// Use these wherever Theme.of(context) is not available
/// (e.g., CustomPainter, static helpers).
class AppColors {
  AppColors._();

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22CC88);
  static const Color warning = Color(0xFFFFB800);
  static const Color danger  = Color(0xFFFF4455);

  // ── Crowd density ─────────────────────────────────────────────────────────
  static const Color crowdEmpty    = Color(0xFF22CC88);
  static const Color crowdLow      = Color(0xFF88DD44);
  static const Color crowdModerate = Color(0xFFFFB800);
  static const Color crowdHigh     = Color(0xFFFF7722);
  static const Color crowdFull     = Color(0xFFFF4455);

  /// Returns the crowd color for [density] in [0, 1].
  static Color forDensity(double density) {
    if (density < 0.20) return crowdEmpty;
    if (density < 0.40) return crowdLow;
    if (density < 0.60) return crowdModerate;
    if (density < 0.80) return crowdHigh;
    return crowdFull;
  }

  /// Returns a Portuguese label for [density] in [0, 1].
  static String crowdLabel(double density) {
    if (density < 0.20) return 'Vazio';
    if (density < 0.40) return 'Baixo';
    if (density < 0.60) return 'Moderado';
    if (density < 0.80) return 'Alto';
    return 'Lotado';
  }
}
```

- [ ] **Step 4: Run tests — expect pass**

```
cd mobile && flutter test test/core/widgets/app_colors_test.dart
```

Expected: 8 pass.

- [ ] **Step 5: Commit**

```
git add mobile/lib/core/widgets/app_colors.dart mobile/test/core/widgets/app_colors_test.dart
git commit -m "feat(flutter): add AppColors with semantic and crowd density helpers"
```

---

## Chunk 2: Screen redesigns

### Task 3: Redesign `login_screen.dart`

Apply the spec: dark hero with SVG network-node logo, gradient CTA button, token-based field borders.

**Files:**
- Modify: `mobile/lib/features/auth/login_screen.dart`
- Modify: `mobile/test/features/auth/login_screen_test.dart`

- [ ] **Step 1: Update/write widget test for new design**

Open `mobile/test/features/auth/login_screen_test.dart`. Replace or add:

```dart
// Existing test setup must include:
// - ProviderScope wrapping
// - GoRouter stub
// - Firebase stub (or mock)

testWidgets('LoginScreen shows TRILHO wordmark', (tester) async {
  await tester.pumpWidget(buildLoginScreen());
  await tester.pumpAndSettle();
  expect(find.text('TRILHO'), findsOneWidget);
});

testWidgets('LoginScreen shows slogan text', (tester) async {
  await tester.pumpWidget(buildLoginScreen());
  await tester.pumpAndSettle();
  expect(find.text('Mobilidade em tempo real'), findsOneWidget);
});

testWidgets('LoginScreen shows Entrar button', (tester) async {
  await tester.pumpWidget(buildLoginScreen());
  await tester.pumpAndSettle();
  expect(find.text('Entrar'), findsOneWidget);
});

testWidgets('LoginScreen shows Continuar sem conta button', (tester) async {
  await tester.pumpWidget(buildLoginScreen());
  await tester.pumpAndSettle();
  expect(find.text('Continuar sem conta'), findsOneWidget);
});
```

- [ ] **Step 2: Run to confirm the new tests fail**

```
cd mobile && flutter test test/features/auth/login_screen_test.dart
```

Expected: the 4 new tests FAIL (text 'TRILHO', 'Mobilidade em tempo real', 'Entrar', 'Continuar sem conta' not found). Do NOT proceed to Step 3 until you see failures.

- [ ] **Step 3: Redesign the login screen scaffold**

In `login_screen.dart`, replace the `build` method's `Scaffold` body. The new design:

```dart
@override
Widget build(BuildContext context) {
  final isDark = AppTheme.isDark(context);

  return Scaffold(
    backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 60),
            // ── Logo ────────────────────────────────────────────────────────
            _buildLogo(isDark),
            const SizedBox(height: 48),
            // ── Email field ─────────────────────────────────────────────────
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight),
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 14),
            // ── Password field ──────────────────────────────────────────────
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              style: TextStyle(color: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight),
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/login/email'),
                child: Text('Esqueceu?',
                    style: TextStyle(color: AppTheme.accent, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 16),
            // ── Primary CTA ─────────────────────────────────────────────────
            _loadingEmail
                ? const Center(child: CircularProgressIndicator())
                : _GradientButton(
                    label: 'Entrar',
                    onTap: _signInWithEmail,
                  ),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(child: Divider(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: TextStyle(
                  color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
                  fontSize: 12,
                )),
              ),
              Expanded(child: Divider(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
            ]),
            const SizedBox(height: 20),
            // ── Social ──────────────────────────────────────────────────────
            _SocialButton(
              label: 'Continuar com Google',
              loading: _loadingGoogle,
              icon: Icons.g_mobiledata,
              onTap: _signInWithGoogle,
            ),
            const SizedBox(height: 10),
            _SocialButton(
              label: 'Continuar com Apple',
              loading: _loadingApple,
              icon: Icons.apple,
              onTap: _signInWithApple,
            ),
            const SizedBox(height: 28),
            // ── Anonymous ───────────────────────────────────────────────────
            OutlinedButton(
              onPressed: _loadingAnonymous ? null : _signInAnonymously,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                foregroundColor: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loadingAnonymous
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Continuar sem conta', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}

Widget _buildLogo(bool isDark) {
  return Column(
    children: [
      // Network node icon
      SizedBox(
        width: 56, height: 56,
        child: CustomPaint(painter: _LogoIconPainter()),
      ),
      const SizedBox(height: 12),
      Text(
        'TRILHO',
        style: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w800,
          color: AppTheme.accent, letterSpacing: 3,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Mobilidade em tempo real',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
        ),
      ),
    ],
  );
}
```

Add private widgets at the bottom of the file:

```dart
// ── _GradientButton ──────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── _SocialButton ────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final bool loading;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialButton({required this.label, required this.loading, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
        foregroundColor: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── _LogoIconPainter ─────────────────────────────────────────────────────────
class _LogoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cyanPaint = Paint()..color = AppTheme.accent..style = PaintingStyle.fill;
    final bluePaint = Paint()..color = AppTheme.primary..style = PaintingStyle.fill;
    final cyanLine  = Paint()..color = AppTheme.accent..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final blueLine  = Paint()..color = AppTheme.primary..strokeWidth = 2..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Horizontal rail: left node — line — right node
    canvas.drawCircle(Offset(cx - 16, cy), 5, cyanPaint);
    canvas.drawCircle(Offset(cx + 16, cy), 5, cyanPaint);
    canvas.drawLine(Offset(cx - 11, cy), Offset(cx + 11, cy), cyanLine);

    // Vertical branch: top node — line — center — line — bottom node
    canvas.drawCircle(Offset(cx, cy - 14), 4, bluePaint);
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy - 5), blueLine);
    canvas.drawCircle(Offset(cx, cy + 14), 4, bluePaint);
    canvas.drawLine(Offset(cx, cy + 5), Offset(cx, cy + 10), blueLine);
  }

  @override
  bool shouldRepaint(_LogoIconPainter old) => false;
}
```

Also add `import 'package:google_fonts/google_fonts.dart';` if not already present, and
`import '../../core/widgets/app_theme.dart';`.

- [ ] **Step 4: Run tests — expect pass**

```
cd mobile && flutter test test/features/auth/login_screen_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit**

```
git add mobile/lib/features/auth/login_screen.dart mobile/test/features/auth/login_screen_test.dart
git commit -m "feat(flutter): redesign LoginScreen with spec tokens and logo"
```

---

### Task 4: Refactor `settings_screen.dart` — remove hardcoded colors

**Files:**
- Modify: `mobile/lib/features/settings/settings_screen.dart`
- Modify: `mobile/test/features/settings/settings_screen_test.dart`

- [ ] **Step 1: Add a test for token-based theming**

In `mobile/test/features/settings/settings_screen_test.dart`, add:

```dart
testWidgets('SettingsScreen scaffold bg matches AppTheme.bgDark in dark mode', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
  expect(scaffold.backgroundColor, AppTheme.bgDark);
});
```

- [ ] **Step 2: Run to confirm failure**

```
cd mobile && flutter test test/features/settings/settings_screen_test.dart
```

- [ ] **Step 3: Replace hardcoded colors in `settings_screen.dart`**

At the top of `build()`, replace the 6 hardcoded color variables:

```dart
// REMOVE these lines:
// final bgColor     = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
// final cardColor   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
// final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
// final labelColor  = isDark ? const Color(0xFF555555) : const Color(0xFF888888);
// final textPrimary = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
// final textRed     = isDark ? const Color(0xFFEF5350) : const Color(0xFFEF4136);

// REPLACE with:
final bgColor     = isDark ? AppTheme.bgDark       : AppTheme.bgLight;
final cardColor   = isDark ? AppTheme.surfaceDark   : AppTheme.surfaceLight;
final borderColor = isDark ? AppTheme.borderDark    : AppTheme.borderLight;
final labelColor  = isDark ? AppTheme.textSecDark   : AppTheme.textSecLight;
final textPrimary = isDark ? AppTheme.textPrimDark  : AppTheme.textPrimLight;
final textRed     = AppColors.danger;
```

Add import at top if missing:
```dart
import '../../core/widgets/app_theme.dart';
import '../../core/widgets/app_colors.dart';
```

- [ ] **Step 4: Run test — expect pass**

```
cd mobile && flutter test test/features/settings/settings_screen_test.dart
```

- [ ] **Step 5: Commit**

```
git add mobile/lib/features/settings/settings_screen.dart mobile/test/features/settings/settings_screen_test.dart
git commit -m "feat(flutter): settings_screen uses AppTheme tokens instead of hardcoded colors"
```

---

### Task 5: Apply tokens to `station_detail_screen.dart`

**Files:**
- Modify: `mobile/lib/features/station_detail/station_detail_screen.dart`
- Modify: `mobile/lib/features/station_detail/crowd_chart.dart`
- Modify: `mobile/test/features/station_detail/station_detail_redesign_test.dart`

- [ ] **Step 1: Identify hardcoded colors in station_detail_screen.dart**

Search for raw `Color(0x…)` or named color references:
```
grep -n "Color(0x" mobile/lib/features/station_detail/station_detail_screen.dart
grep -n "Color(0x" mobile/lib/features/station_detail/crowd_chart.dart
```

- [ ] **Step 2: Add failing test for scaffold background**

Open `mobile/test/features/station_detail/station_detail_redesign_test.dart`. Add the helper and test below. The helper overrides the providers that `StationDetailScreen` needs to avoid real network calls:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/core/providers/crowd_provider.dart';
import 'package:trilho/core/providers/station_arrivals_provider.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/providers/usage_provider.dart';
import 'package:trilho/features/station_detail/station_detail_screen.dart';

Widget buildStationDetailDark({required int stationId}) {
  return ProviderScope(
    overrides: [
      // Override async providers with empty/idle states so widget renders without network
      crowdProvider.overrideWith((ref) => Stream.value({})),
      stationArrivalsProvider(stationId).overrideWith((ref) => Future.value(null)),
      selectedCityProvider.overrideWith((ref) => null),
      usageProvider.overrideWith((ref) => Future.value(
        UsageModel(isPremium: false, queryCount: 0, lastReset: DateTime.now()),
      )),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: StationDetailScreen(stationId: stationId),
    ),
  );
}

// Add inside the existing main():
testWidgets('StationDetailScreen scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
  await tester.pumpWidget(buildStationDetailDark(stationId: 1));
  await tester.pump(); // single pump to get scaffold rendered before async work
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  expect(scaffold.backgroundColor, AppTheme.bgDark);
});
```

Run to confirm failure:
```
cd mobile && flutter test test/features/station_detail/station_detail_redesign_test.dart
```
Expected: test FAILS (scaffold bg is `Color(0xFF121212)` not `Color(0xFF0A0A14)`).

- [ ] **Step 3: Replace hardcoded crowd/bg colors**

Any hardcoded `Color(0xFF22CC88)`, `Color(0xFFFFB800)` etc. in crowd_chart.dart → replace with `AppColors.forDensity(density)`.

Any hardcoded scaffold bg → `AppTheme.bgDark` / `AppTheme.bgLight`.

- [ ] **Step 4: Run tests**

```
cd mobile && flutter test test/features/station_detail/
```

- [ ] **Step 5: Commit**

```
git add mobile/lib/features/station_detail/ mobile/test/features/station_detail/
git commit -m "feat(flutter): station_detail uses AppTheme + AppColors tokens"
```

---

### Task 6: Apply tokens to `paywall_screen.dart`

**Files:**
- Modify: `mobile/lib/features/paywall/paywall_screen.dart`
- Create: `mobile/test/features/paywall/paywall_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/features/paywall/paywall_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/core/providers/usage_provider.dart';
import 'package:trilho/features/paywall/paywall_screen.dart';

Widget buildPaywallDark() {
  return ProviderScope(
    overrides: [
      usageProvider.overrideWith((ref) => Future.value(
        UsageModel(isPremium: false, queryCount: 0, lastReset: DateTime.now()),
      )),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const PaywallScreen(),
    ),
  );
}

void main() {
  testWidgets('PaywallScreen scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
    await tester.pumpWidget(buildPaywallDark());
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });
}
```

Run to confirm failure:
```
cd mobile && flutter test test/features/paywall/paywall_screen_test.dart
```
Expected: FAIL (scaffold bg is not `Color(0xFF0A0A14)`).

- [ ] **Step 2: Scan for hardcoded colors**

```
grep -n "Color(0x\|Colors\." mobile/lib/features/paywall/paywall_screen.dart | head -30
```

- [ ] **Step 3: Replace all hardcoded bg/text/border colors**

Pattern to follow:
- Background → `AppTheme.bgDark` / `AppTheme.bgLight` based on brightness
- Surface cards → `AppTheme.surfaceDark` / `AppTheme.surfaceLight`
- Primary CTA → `AppTheme.primary`
- Benefit bullets → `AppTheme.accent`
- Danger/cancel text → `AppColors.danger`

Add imports:
```dart
import '../../core/widgets/app_theme.dart';
import '../../core/widgets/app_colors.dart';
```

- [ ] **Step 4: Run test — expect pass**

```
cd mobile && flutter test test/features/paywall/paywall_screen_test.dart
```

- [ ] **Step 5: Commit**

```
git add mobile/lib/features/paywall/paywall_screen.dart mobile/test/features/paywall/paywall_screen_test.dart
git commit -m "feat(flutter): paywall_screen uses AppTheme tokens"
```

---

### Task 7: Apply tokens to city_picker + welcome screens

**Files:**
- Modify: `mobile/lib/features/city_picker/welcome_screen.dart`
- Modify: `mobile/lib/features/city_picker/city_picker_sheet.dart`
- Create: `mobile/test/features/city_picker/city_picker_token_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/features/city_picker/city_picker_token_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/features/city_picker/welcome_screen.dart';

Widget buildWelcomeDark() {
  return ProviderScope(
    overrides: [
      citiesProvider.overrideWith((ref) => Future.value([])),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const WelcomeScreen(),
    ),
  );
}

void main() {
  testWidgets('WelcomeScreen scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
    await tester.pumpWidget(buildWelcomeDark());
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });
}
```

Run to confirm failure:
```
cd mobile && flutter test test/features/city_picker/city_picker_token_test.dart
```
Expected: FAIL.

- [ ] **Step 2: Scan both files**

```
grep -n "Color(0x\|Colors\." mobile/lib/features/city_picker/welcome_screen.dart
grep -n "Color(0x\|Colors\." mobile/lib/features/city_picker/city_picker_sheet.dart
```

- [ ] **Step 3: Replace hardcoded colors following Task 4–6 pattern**

- [ ] **Step 4: Run tests — expect pass**

```
cd mobile && flutter test test/features/city_picker/city_picker_token_test.dart
```

- [ ] **Step 5: Commit**

```
git add mobile/lib/features/city_picker/ mobile/test/features/city_picker/
git commit -m "feat(flutter): city_picker screens use AppTheme tokens"
```

---

### Task 8: Final build verification

- [ ] **Step 1: Run full Flutter test suite**

```
cd mobile && flutter test
```

Expected: 0 failures.

- [ ] **Step 2: Build debug APK to confirm no compilation errors**

```
cd mobile && flutter build apk --debug --no-pub
```

Expected: Build successful (APK path printed).

- [ ] **Step 3: Final commit if any leftover tweaks**

```
git add -p
git commit -m "chore(flutter): design system token cleanup"
```

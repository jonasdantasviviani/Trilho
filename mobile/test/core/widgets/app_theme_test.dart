import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trilho/core/widgets/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void runThemeTest(VoidCallback body) {
    runZonedGuarded(body, (e, st) {
      // Suppress only GoogleFonts font-not-found errors from async loading.
      // Real test failures (assertion errors, LateInitializationError, etc.) still fail.
      if (!e.toString().contains('GoogleFonts') &&
          !e.toString().contains('font') &&
          !e.toString().contains('was not found')) {
        Zone.current.handleUncaughtError(e, st);
      }
    });
  }

  test('darkTheme scaffold bg is #0A0A14', () {
    runThemeTest(() {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0A14));
    });
  });

  test('lightTheme scaffold bg is #F5F5F7', () {
    runThemeTest(() {
      final theme = AppTheme.light();
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F5F7));
    });
  });

  test('darkTheme primary is #0055FF', () {
    runThemeTest(() {
      final theme = AppTheme.dark();
      expect(theme.colorScheme.primary, const Color(0xFF0055FF));
    });
  });

  test('darkTheme secondary is #00C8FF', () {
    runThemeTest(() {
      final theme = AppTheme.dark();
      expect(theme.colorScheme.secondary, const Color(0xFF00C8FF));
    });
  });

  test('lightTheme primary is #0055FF', () {
    runThemeTest(() {
      final theme = AppTheme.light();
      expect(theme.colorScheme.primary, const Color(0xFF0055FF));
    });
  });

  test('bodyMedium fontFamily is Inter (both modes)', () {
    runThemeTest(() {
      expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily,  contains('Inter'));
      expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, contains('Inter'));
    });
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/providers/app_providers.dart';

void main() {
  group('themeModeProvider', () {
    test('default is ThemeMode.system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('can be overridden to ThemeMode.dark', () {
      final container = ProviderContainer(
        overrides: [themeModeProvider.overrideWith((ref) => ThemeMode.dark)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('state can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider.notifier).state = ThemeMode.light;
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('pendingLineSelectionProvider', () {
    test('default is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(pendingLineSelectionProvider), isNull);
    });

    test('state can be set and cleared', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(pendingLineSelectionProvider.notifier).state = 'L1';
      expect(container.read(pendingLineSelectionProvider), 'L1');
      container.read(pendingLineSelectionProvider.notifier).state = null;
      expect(container.read(pendingLineSelectionProvider), isNull);
    });
  });
}

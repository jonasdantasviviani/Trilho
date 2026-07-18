import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trilho/core/models/city_model.dart';
import 'package:trilho/core/providers/app_providers.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/features/settings/settings_screen.dart';
import 'package:trilho/core/widgets/app_theme.dart';

void main() {
  testWidgets('SettingsScreen shows APARÊNCIA and CONTA sections', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    expect(find.text('APARÊNCIA'), findsOneWidget);
    expect(find.text('CONTA'), findsOneWidget);
    expect(find.text('Modo escuro'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

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

  testWidgets('dark mode switch toggles themeModeProvider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Light mode initially — switch shows off
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);

    // Tap the switch
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Provider should now be ThemeMode.dark
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

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
}

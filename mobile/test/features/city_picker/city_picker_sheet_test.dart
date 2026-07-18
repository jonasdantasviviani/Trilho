import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/city_model.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/features/city_picker/city_picker_sheet.dart';

void main() {
  // Pre-seed provider with São Paulo (safe — select() has try-catch after Task 1).
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/features/city_picker/welcome_screen.dart';

Widget buildWelcomeDark() {
  return ProviderScope(
    overrides: [
      // citiesByStateProvider is a synchronous Provider<Map>
      citiesByStateProvider.overrideWithValue(const {}),
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

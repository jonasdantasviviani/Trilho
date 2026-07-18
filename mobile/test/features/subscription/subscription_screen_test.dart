import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/features/subscription/subscription_screen.dart';

void main() {
  testWidgets('SubscriptionScreen scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });

  testWidgets('SubscriptionScreen scaffold bg is AppTheme.bgLight in light mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.bgLight);
  });
}

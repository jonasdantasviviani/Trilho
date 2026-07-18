import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_empty.dart';

void main() {
  group('AppEmpty', () {
    testWidgets('shows the icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(icon: Icons.train, title: 'Sem dados'),
          ),
        ),
      );
      expect(find.byIcon(Icons.train), findsOneWidget);
    });

    testWidgets('shows the title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(icon: Icons.train, title: 'Nenhuma estação'),
          ),
        ),
      );
      expect(find.text('Nenhuma estação'), findsOneWidget);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(
              icon: Icons.train,
              title: 'Sem dados',
              subtitle: 'Tente outra cidade',
            ),
          ),
        ),
      );
      expect(find.text('Tente outra cidade'), findsOneWidget);
    });

    testWidgets('does not show subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(icon: Icons.train, title: 'Sem dados'),
          ),
        ),
      );
      // Only one text widget: the title
      expect(find.byType(Text), findsOneWidget);
    });
  });
}

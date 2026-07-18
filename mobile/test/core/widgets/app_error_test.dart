import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_error.dart';

void main() {
  group('AppError', () {
    testWidgets('shows the error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppError(message: 'Não foi possível carregar'),
          ),
        ),
      );
      expect(find.text('Não foi possível carregar'), findsOneWidget);
    });

    testWidgets('shows error icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppError(message: 'Erro')),
        ),
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppError(message: 'Erro', onRetry: () {}),
          ),
        ),
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('does not show retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppError(message: 'Erro')),
        ),
      );
      expect(find.text('Tentar novamente'), findsNothing);
    });

    testWidgets('calls onRetry when retry button is tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppError(message: 'Erro', onRetry: () => called = true),
          ),
        ),
      );
      await tester.tap(find.text('Tentar novamente'));
      expect(called, isTrue);
    });
  });
}

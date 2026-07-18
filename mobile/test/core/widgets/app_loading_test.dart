import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:trilho/core/widgets/app_loading.dart';

void main() {
  group('AppLoading.spinner', () {
    testWidgets('shows a CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLoading.spinner())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('centers the spinner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLoading.spinner())),
      );
      expect(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('has Semantics label for screen readers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLoading.spinner())),
      );
      expect(
        tester.getSemantics(find.byType(CircularProgressIndicator)),
        matchesSemantics(label: 'Carregando...', isLiveRegion: true),
      );
    });
  });

  group('AppLoading.skeleton', () {
    testWidgets('shows a Shimmer widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLoading.skeleton(height: 56)),
        ),
      );
      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('renders a container with the given height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AppLoading.skeleton(height: 80),
            ),
          ),
        ),
      );
      final size = tester.getSize(
        find.descendant(of: find.byType(Shimmer), matching: find.byType(Container)),
      );
      expect(size.height, 80);
    });
  });
}

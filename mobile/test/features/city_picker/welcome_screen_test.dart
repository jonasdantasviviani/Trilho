import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/features/city_picker/welcome_screen.dart';

Widget buildSubject({required ProviderContainer container, ThemeData? theme}) {
  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: theme,
      routerConfig: router,
    ),
  );
}

ProviderContainer makeContainer() => ProviderContainer(
      overrides: [
        selectedCityProvider.overrideWith(
          (_) => SelectedCityNotifier.skipHive(),
        ),
      ],
    );

void main() {
  testWidgets('Scaffold backgroundColor is bgDark in dark theme', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      buildSubject(container: container, theme: AppTheme.dark()),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });

  testWidgets('Scaffold backgroundColor is bgLight in light theme', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      buildSubject(container: container, theme: AppTheme.light()),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgLight);
  });

  testWidgets('tapping São Paulo updates selectedCityProvider', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildSubject(container: container));
    await tester.pump();

    await tester.tap(find.text('São Paulo').first);
    await tester.pump(); // single frame: provider updated, navigation starting

    expect(container.read(selectedCityProvider).id, 'sao-paulo-sp');
  });

  testWidgets('tapping Curitiba shows ComingSoonDialog', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildSubject(container: container));
    await tester.pump();

    await tester.tap(find.text('Curitiba').first);
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('"Me avise" shows SnackBar', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildSubject(container: container));
    await tester.pump();

    await tester.tap(find.text('Curitiba').first);
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

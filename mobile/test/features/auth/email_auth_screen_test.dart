import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/providers/app_providers.dart';
import 'package:trilho/core/services/api_service.dart';
import 'package:trilho/core/services/auth_service.dart';
import 'package:trilho/core/services/geofencing_service.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/features/auth/email_auth_screen.dart';

// ---------------------------------------------------------------------------
// Minimal fakes — no Firebase calls are made in unit tests
// ---------------------------------------------------------------------------

class _FakeApiService extends Fake implements ApiService {}

class _FakeAuthService extends Fake implements AuthService {}

class _FakeGeofencingService extends Fake implements GeofencingService {}

// ---------------------------------------------------------------------------
// Helper: wrap screen with ProviderScope overrides
// ---------------------------------------------------------------------------

Widget _buildScreen({ThemeData? theme}) {
  return ProviderScope(
    overrides: [
      apiServiceProvider.overrideWithValue(_FakeApiService()),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      geofencingServiceProvider.overrideWithValue(_FakeGeofencingService()),
    ],
    child: MaterialApp(
      theme: theme,
      home: const EmailAuthScreen(),
    ),
  );
}

void main() {
  group('EmailAuthScreen scaffold bg', () {
    testWidgets('scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
      await tester.pumpWidget(_buildScreen(theme: AppTheme.dark()));
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppTheme.bgDark);
    });

    testWidgets('scaffold bg is AppTheme.bgLight in light mode', (tester) async {
      await tester.pumpWidget(_buildScreen(theme: AppTheme.light()));
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppTheme.bgLight);
    });
  });

  group('EmailAuthScreen — sign-in mode (default)', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(_buildScreen());

      expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
    });

    testWidgets('renders "Entrar" submit button', (tester) async {
      await tester.pumpWidget(_buildScreen());

      // The FilledButton in sign-in mode shows "Entrar"
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    });

    testWidgets('shows error when email is empty on submit', (tester) async {
      await tester.pumpWidget(_buildScreen());

      // Tap submit without filling any field
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.text('Informe o e-mail'), findsOneWidget);
    });

    testWidgets('shows error when password is empty on submit', (tester) async {
      await tester.pumpWidget(_buildScreen());

      // Fill a valid email but leave password blank
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'test@example.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.text('Informe a senha'), findsOneWidget);
    });
  });

  group('EmailAuthScreen — sign-up mode toggle', () {
    testWidgets('toggle button switches to sign-up mode', (tester) async {
      await tester.pumpWidget(_buildScreen());

      // Initially in sign-in mode
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);

      // Tap the toggle TextButton
      await tester.tap(find.text('Não tem conta? Criar conta'));
      await tester.pump();

      // Now in sign-up mode
      expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);
    });

    testWidgets('short password shows error in sign-up mode', (tester) async {
      await tester.pumpWidget(_buildScreen());

      // Switch to sign-up mode
      await tester.tap(find.text('Não tem conta? Criar conta'));
      await tester.pump();

      // Enter valid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'test@example.com',
      );

      // Enter short password (< 6 chars)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        '123',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pump();

      expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    });
  });
}

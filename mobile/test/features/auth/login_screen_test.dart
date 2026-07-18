import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/providers/app_providers.dart';
import 'package:trilho/core/services/api_service.dart';
import 'package:trilho/core/services/auth_service.dart';
import 'package:trilho/core/services/geofencing_service.dart';
import 'package:trilho/features/auth/login_screen.dart';

class _FakeApiService extends Fake implements ApiService {}
class _FakeAuthService extends Fake implements AuthService {}
class _FakeGeofencingService extends Fake implements GeofencingService {}

Widget buildLoginScreen() {
  return ProviderScope(
    overrides: [
      apiServiceProvider.overrideWithValue(_FakeApiService()),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      geofencingServiceProvider.overrideWithValue(_FakeGeofencingService()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: const LoginScreen(),
    ),
  );
}

void main() {
  testWidgets('LoginScreen shows TRILHO wordmark', (tester) async {
    await tester.pumpWidget(buildLoginScreen());
    await tester.pumpAndSettle();
    expect(find.text('TRILHO'), findsOneWidget);
  });

  testWidgets('LoginScreen shows slogan text', (tester) async {
    await tester.pumpWidget(buildLoginScreen());
    await tester.pumpAndSettle();
    expect(find.text('Mobilidade em tempo real'), findsOneWidget);
  });

  testWidgets('LoginScreen shows Entrar button', (tester) async {
    await tester.pumpWidget(buildLoginScreen());
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('LoginScreen shows Continuar sem conta button', (tester) async {
    await tester.pumpWidget(buildLoginScreen());
    await tester.pumpAndSettle();
    expect(find.text('Continuar sem conta'), findsOneWidget);
  });
}

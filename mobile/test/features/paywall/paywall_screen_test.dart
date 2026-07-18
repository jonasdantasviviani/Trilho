import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/core/models/usage_model.dart';
import 'package:trilho/core/providers/usage_provider.dart' show usageProvider, canQueryProvider;
import 'package:trilho/core/services/payment_service.dart';
import 'package:trilho/features/paywall/paywall_screen.dart';

class _FakePaymentService extends Fake implements PaymentService {
  @override
  bool get isPremium => false;

  @override
  Future<PaymentResult> purchase({
    required String email,
    required String name,
    String? taxId,
  }) async =>
      PaymentResult(success: false, message: 'fake');

  @override
  Future<PaymentResult> restore() async =>
      PaymentResult(success: false, message: 'fake');

  @override
  Future<bool> checkAndWaitForPayment(String billingId) async => false;
}

Widget buildPaywallDark() {
  return ProviderScope(
    overrides: [
      usageProvider.overrideWith(
        (ref) => Future.value(
          const UsageModel(
            queriesUsed: 0,
            queriesLimit: 5,
            isPremium: false,
            isAnonymous: true,
          ),
        ),
      ),
      paymentServiceProvider.overrideWithValue(_FakePaymentService()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const PaywallScreen(),
    ),
  );
}

void main() {
  testWidgets('PaywallScreen scaffold bg is AppTheme.bgDark in dark mode',
      (tester) async {
    await tester.pumpWidget(buildPaywallDark());
    await tester.pump();
    final scaffold =
        tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });
}

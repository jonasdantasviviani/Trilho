import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/services/abacate_pay_service.dart';

void main() {
  group('BillingResult', () {
    BillingResult makeResult(String status) => BillingResult(
          billingId: 'b1',
          url: 'http://x',
          amount: 990,
          status: status,
          isDevMode: false,
        );

    test('isPending_whenStatusPENDING_returnsTrue', () {
      expect(makeResult('PENDING').isPending, isTrue);
    });

    test('isPaid_whenStatusPAID_returnsTrue', () {
      expect(makeResult('PAID').isPaid, isTrue);
    });

    test('isPaid_whenStatusCONFIRMED_returnsTrue', () {
      expect(makeResult('CONFIRMED').isPaid, isTrue);
    });

    test('isCancelled_whenStatusCANCELLED_returnsTrue', () {
      expect(makeResult('CANCELLED').isCancelled, isTrue);
    });

    test('isCancelled_whenStatusCANCELED_returnsTrue', () {
      expect(makeResult('CANCELED').isCancelled, isTrue);
    });
  });

  group('BillingStatus', () {
    BillingStatus makeStatus(String status) => BillingStatus(
          billingId: 'b1',
          status: status,
          amount: 990,
          isDevMode: false,
        );

    test('isPending_whenStatusPENDING_returnsTrue', () {
      expect(makeStatus('PENDING').isPending, isTrue);
    });

    test('isPaid_whenStatusPAID_returnsTrue', () {
      expect(makeStatus('PAID').isPaid, isTrue);
    });

    test('isCancelled_whenStatusCANCELLED_returnsTrue', () {
      expect(makeStatus('CANCELLED').isCancelled, isTrue);
    });
  });
}

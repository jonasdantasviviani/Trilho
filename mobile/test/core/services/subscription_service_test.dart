import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/services/subscription_service.dart';

void main() {
  group('SubscriptionStatus', () {
    group('fromJson', () {
      test('fromJson_withFullData_parsesAllFields', () {
        final json = {
          'isActive': true,
          'planName': 'Premium Anual',
          'priceInCents': 1990,
          'currency': 'USD',
          'paymentMethod': 'CREDIT_CARD',
          'autoRenew': false,
          'canCancel': false,
          'canChangePlan': false,
          'isPremiumUntil': '2026-12-31T00:00:00Z',
          'nextBillingDate': '2026-12-31T00:00:00Z',
        };

        final status = SubscriptionStatus.fromJson(json);

        expect(status.isActive, isTrue);
        expect(status.planName, equals('Premium Anual'));
        expect(status.priceInCents, equals(1990));
        expect(status.currency, equals('USD'));
        expect(status.paymentMethod, equals('CREDIT_CARD'));
        expect(status.autoRenew, isFalse);
        expect(status.canCancel, isFalse);
        expect(status.canChangePlan, isFalse);
        expect(status.isPremiumUntil, isNotNull);
        expect(status.nextBillingDate, isNotNull);
      });

      test('fromJson_withMissingOptionals_usesDefaults', () {
        final json = <String, dynamic>{};

        final status = SubscriptionStatus.fromJson(json);

        expect(status.isActive, isFalse);
        expect(status.planName, equals('Premium Mensal'));
        expect(status.priceInCents, equals(990));
        expect(status.currency, equals('BRL'));
        expect(status.paymentMethod, equals('PIX/CARD'));
        expect(status.autoRenew, isTrue);
        expect(status.canCancel, isTrue);
        expect(status.canChangePlan, isTrue);
        expect(status.isPremiumUntil, isNull);
        expect(status.nextBillingDate, isNull);
      });

      test('fromJson_withIsPremiumUntil_parsesDate', () {
        final json = {
          'isActive': true,
          'planName': 'Premium Mensal',
          'priceInCents': 990,
          'isPremiumUntil': '2026-06-01T00:00:00Z',
        };

        final status = SubscriptionStatus.fromJson(json);

        expect(status.isPremiumUntil, isNotNull);
        expect(status.isPremiumUntil!.year, equals(2026));
        expect(status.isPremiumUntil!.month, equals(6));
        expect(status.isPremiumUntil!.day, equals(1));
      });
    });

    group('formattedPrice', () {
      test('formattedPrice_990cents_returnsR\$9_90', () {
        final status = SubscriptionStatus(
          isActive: true,
          planName: 'Premium Mensal',
          priceInCents: 990,
        );

        expect(status.formattedPrice, equals('R\$ 9.90'));
      });
    });

    group('formattedDate', () {
      test('formattedDate_withDate_returnsDDMMYYYY', () {
        final status = SubscriptionStatus(
          isActive: true,
          planName: 'Premium Mensal',
          priceInCents: 990,
          isPremiumUntil: DateTime(2026, 6, 1),
        );

        expect(status.formattedDate, equals('01/06/2026'));
      });

      test('formattedDate_withoutDate_returnsDash', () {
        final status = SubscriptionStatus(
          isActive: false,
          planName: 'Premium Mensal',
          priceInCents: 990,
          isPremiumUntil: null,
        );

        expect(status.formattedDate, equals('-'));
      });
    });
  });

  group('SubscriptionHistoryItem', () {
    group('fromJson', () {
      test('fromJson_parsesAllFields', () {
        final json = {
          'id': 'abc-123',
          'date': '2026-03-15T10:30:00Z',
          'amount': 1990,
          'status': 'paid',
          'description': 'Premium Mensal',
          'paymentMethod': 'PIX',
        };

        final item = SubscriptionHistoryItem.fromJson(json);

        expect(item.id, equals('abc-123'));
        expect(item.date.year, equals(2026));
        expect(item.date.month, equals(3));
        expect(item.date.day, equals(15));
        expect(item.amount, equals(1990));
        expect(item.status, equals('paid'));
        expect(item.description, equals('Premium Mensal'));
        expect(item.paymentMethod, equals('PIX'));
      });

      test('fromJson_usesDefaultsForMissingFields', () {
        final json = {
          'date': '2026-01-01T00:00:00Z',
        };

        final item = SubscriptionHistoryItem.fromJson(json);

        expect(item.id, equals(''));
        expect(item.amount, equals(0));
        expect(item.status, equals(''));
        expect(item.description, equals(''));
        expect(item.paymentMethod, equals(''));
      });
    });

    group('formattedPrice', () {
      test('formattedPrice_1990cents_returnsR\$19_90', () {
        final item = SubscriptionHistoryItem(
          id: '1',
          date: DateTime(2026, 1, 1),
          amount: 1990,
          status: 'paid',
          description: 'Premium Anual',
          paymentMethod: 'PIX',
        );

        expect(item.formattedPrice, equals('R\$ 19.90'));
      });
    });

    group('formattedDate', () {
      test('formattedDate_returnsCorrectFormat', () {
        final item = SubscriptionHistoryItem(
          id: '1',
          date: DateTime(2026, 3, 5),
          amount: 990,
          status: 'paid',
          description: 'Premium Mensal',
          paymentMethod: 'CARD',
        );

        expect(item.formattedDate, equals('05/03/2026'));
      });
    });
  });
}

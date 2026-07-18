import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/city_model.dart';
import 'package:trilho/core/providers/city_provider.dart';

void main() {
  group('SelectedCityNotifier.skipHive()', () {
    test('select() updates state without throwing when Hive unavailable', () {
      final n = SelectedCityNotifier.skipHive();
      expect(() => n.select(CityRegistry.all.first), returnsNormally);
      expect(n.state?.id, equals('sao-paulo-sp'));
    });

    test('clear() resets state without throwing when Hive unavailable', () {
      final n = SelectedCityNotifier.skipHive();
      n.select(CityRegistry.all.first); // first call — will throw before fix
      expect(() => n.clear(), returnsNormally);
      expect(n.state, isNull);
    });
  });

  group('SelectedCityNotifier() default constructor', () {
    test('does not throw when Hive box is unavailable', () {
      expect(() => SelectedCityNotifier(), returnsNormally);
    });

    test('state is null when Hive is unavailable', () {
      expect(SelectedCityNotifier().state, isNull);
    });
  });
}

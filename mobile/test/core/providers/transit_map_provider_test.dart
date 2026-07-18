// mobile/test/core/providers/transit_map_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/providers/transit_map_provider.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/models/city_model.dart';

// Test-only notifier that skips Hive.
class _SeedCityNotifier extends SelectedCityNotifier {
  final CityModel? _seed;
  _SeedCityNotifier(this._seed) : super.skipHive();

  @override
  CityModel? get state => _seed;
}

void main() {
  test('transitMapProvider returns schematic for São Paulo', () async {
    final spCity = CityRegistry.findById('sao-paulo-sp');
    final container = ProviderContainer(
      overrides: [
        selectedCityProvider.overrideWith((_) => _SeedCityNotifier(spCity)),
      ],
    );
    addTearDown(container.dispose);

    final schematic = await container.read(transitMapProvider.future);
    expect(schematic, isNotNull);
    expect(schematic!.stations, isNotEmpty);
  });

  test('transitMapProvider returns null for city without schematic', () async {
    final cwbCity = CityRegistry.findById('curitiba-pr');
    final container = ProviderContainer(
      overrides: [
        selectedCityProvider.overrideWith((_) => _SeedCityNotifier(cwbCity)),
      ],
    );
    addTearDown(container.dispose);

    final schematic = await container.read(transitMapProvider.future);
    expect(schematic, isNull);
  });

  test('lineZoomProvider starts as null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(lineZoomProvider), isNull);
  });
}

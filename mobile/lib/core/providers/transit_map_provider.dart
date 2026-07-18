// mobile/lib/core/providers/transit_map_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../models/schematic_model.dart';

// lineZoomProvider: null = overview mode, non-null = line code being zoomed.
final lineZoomProvider = StateProvider<String?>((ref) => null);

final transitMapProvider = FutureProvider<TransitSchematic?>((ref) async {
  return CityRegistry.getSchematic('sao-paulo-sp'); // returns null, never throws
});

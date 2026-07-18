import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';

// São Paulo is the only supported city.
final selectedCityProvider = Provider<CityModel>(
  (_) => CityRegistry.all.first,
);

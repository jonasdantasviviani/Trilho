import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/crowd_model.dart';
import 'app_providers.dart';

final crowdProvider = FutureProvider.family<CrowdModel, int>((ref, stationId) async {
  final api = ref.read(apiServiceProvider);
  return api.getStationCrowd(stationId);
});

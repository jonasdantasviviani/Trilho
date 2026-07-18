// mobile/lib/core/providers/station_arrivals_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station_arrivals_model.dart';
import 'app_providers.dart';

/// Returns arrival predictions for [stationId].
/// Always returns a valid StationArrivals — falls back to unavailable() on any error.
/// Arrivals are headway-estimated (not real-time GTFS-RT) so degraded gracefully.
final stationArrivalsProvider =
    FutureProvider.family<StationArrivals, int>((ref, stationId) async {
  final api = ref.watch(apiServiceProvider);

  try {
    return await api.getStationArrivals(stationId);
  } catch (_) {
    // Non-fatal: arrivals section shows "Dados indisponíveis" instead of crashing.
    return StationArrivals.unavailable(stationId: stationId);
  }
});

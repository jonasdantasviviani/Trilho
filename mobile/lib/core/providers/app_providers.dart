import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/geofencing_service.dart';
import '../services/usage_tracker.dart';

final apiServiceProvider  = Provider<ApiService>((ref)  => ApiService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final usageTrackerProvider = Provider<UsageTracker>((ref) => UsageTracker());
final geofencingServiceProvider = Provider<GeofencingService>((ref) {
  final api = ref.watch(apiServiceProvider);
  return GeofencingService(apiService: api);
});

/// Controls the app-wide theme mode. Persisted via Hive box 'app_prefs'.
/// Initialized in main() with the saved value (defaults to ThemeMode.system).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Used to signal TransitMapScreen to select a line after navigating back from
/// StationDetailScreen. Set to a lineCode string, consumed and cleared by TransitMapScreen.
final pendingLineSelectionProvider = StateProvider<String?>((ref) => null);

/// GPS coordinates for all stations, keyed by station ID.
/// Fetched once per session from /api/stations and used by the map to
/// convert GPS train positions into schematic (canvas) coordinates.
/// Only includes stations that have valid (non-zero) coordinates.
final stationsGpsProvider =
    FutureProvider<Map<int, ({double lat, double lng})>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final stations = await api.getStations();
  return <int, ({double lat, double lng})>{
    for (final s in stations)
      if (s.lat != 0.0 || s.lng != 0.0) s.id: (lat: s.lat, lng: s.lng),
  };
});

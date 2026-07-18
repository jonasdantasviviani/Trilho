import 'package:flutter/foundation.dart';
import 'package:geofence_service/geofence_service.dart';
import '../models/station_model.dart';
import 'api_service.dart';
import 'usage_tracker.dart';

/// Flutter-side geofence radius (meters).
/// Larger than backend's 200 m to account for GPS jitter in background (spec RN-04).
const double _kRadius = 300.0;

class GeofencingService {
  final ApiService apiService;
  final bool skipNativeInit; // true in unit tests to avoid native platform calls

  bool _initialized = false; // guard against repeated init on cold start

  GeofencingService({
    required this.apiService,
    this.skipNativeInit = false,
  });

  /// Load stations from API, create geofences, and start listening.
  /// Silently does nothing if permission is denied or stations list is empty.
  Future<void> initialize(List<StationModel> stations) async {
    if (skipNativeInit || _initialized) return;

    // Only stations with both coordinates populated are valid (RN-04).
    // A station with lat=0.0 AND lng=0.0 is the StationModel default sentinel.
    final validStations =
        stations.where((s) => s.lat != 0.0 && s.lng != 0.0).toList();
    if (validStations.isEmpty) return;

    final geofences = validStations
        .map((s) => Geofence(
              id: 'station_${s.id}',
              latitude: s.lat,
              longitude: s.lng,
              radius: [GeofenceRadius(id: 'r_${s.id}', length: _kRadius)],
            ))
        .toList();

    // IMPORTANT: Call setup() here (not as inline field) to avoid native calls during tests.
    // setup() returns the instance (fluent API), so we can chain it.
    final gfService = GeofenceService.instance.setup(
      interval: 5000,
      accuracy: 100,
      loiteringDelayMs: 60000,
      statusChangeDelayMs: 10000,
      useActivityRecognition: false,
      allowMockLocations: false,
      printDevLog: false,
      geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
    );

    gfService.addGeofenceStatusChangeListener(_onStatusChanged);

    try {
      await gfService.start(geofences);
      _initialized = true;
    } catch (e) {
      _onError(e);
    }
  }

  /// Called when geofence status changes. Only acts on ENTER.
  Future<void> _onStatusChanged(
    Geofence geofence,
    GeofenceRadius radius,
    GeofenceStatus status,
    Location location,
  ) async {
    // GeofenceStatus is an uppercase enum: ENTER, EXIT, DWELL
    final entering = status == GeofenceStatus.ENTER;
    await testOnStatusChanged(
      lat: location.latitude,
      lng: location.longitude,
      isEnter: entering,
    );
  }

  /// Exposed for testing — simulates a status change event.
  @visibleForTesting
  Future<void> testOnStatusChanged({
    required double lat,
    required double lng,
    required bool isEnter,
  }) async {
    if (!isEnter) return; // spec RN-06: only ENTER events trigger pings
    await handleEnter(lat: lat, lng: lng);
  }

  /// Exposed for testing — fires a ping for the given coordinates.
  @visibleForTesting
  Future<void> handleEnter({required double lat, required double lng}) async {
    try {
      final response = await apiService.postPing(lat: lat, lng: lng);
      // Only track locally if the backend accepted the ping (not rejected by anti-fraud).
      if (response != null && response['rejected'] != true) {
        await UsageTracker().recordPing();
      }
    } catch (e) {
      _onError(e); // silent — crowdsourcing pings are best-effort (spec RN-12)
    }
  }

  void _onError(dynamic error) {
    debugPrint('[GeofencingService] error: $error'); // silent in production (spec RN-11)
  }
}

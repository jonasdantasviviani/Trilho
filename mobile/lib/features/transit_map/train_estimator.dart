// mobile/lib/features/transit_map/train_estimator.dart
import 'dart:math';

class TrainEstimate {
  final List<int> betweenStationIds; // [stationA, stationB]
  final double confidence;           // 0.0–1.0
  final bool isEstimated;            // false = real GPS, true = crowd-based
  /// Lerp factor for drawing: 0.0 = at stationA, 1.0 = at stationB.
  /// Crowd estimates always use 0.5 (midpoint). GPS estimates compute exact t.
  final double t;

  const TrainEstimate({
    required this.betweenStationIds,
    required this.confidence,
    this.isEstimated = true,
    this.t = 0.5,
  });

  /// Creates a GPS-based [TrainEstimate] for a vehicle at ([lat], [lng]) on a
  /// line defined by [stationIds]. [stationGps] maps stationId → GPS coords.
  ///
  /// Finds the nearest station, determines which adjacent segment the vehicle
  /// is on, and computes [t] as the projection ratio along that segment.
  /// Returns null if no valid GPS coordinates are found in [stationGps].
  static TrainEstimate? fromGps({
    required double lat,
    required double lng,
    required List<int> stationIds,
    required Map<int, ({double lat, double lng})> stationGps,
  }) {
    double minDist = double.infinity;
    int nearestIdx = -1;

    for (int i = 0; i < stationIds.length; i++) {
      final gps = stationGps[stationIds[i]];
      if (gps == null) continue;
      final d = _haversine(lat, lng, gps.lat, gps.lng);
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }

    if (nearestIdx < 0) return null;

    final dPrev = nearestIdx > 0
        ? _haversineById(lat, lng, stationIds[nearestIdx - 1], stationGps)
        : double.infinity;
    final dNext = nearestIdx < stationIds.length - 1
        ? _haversineById(lat, lng, stationIds[nearestIdx + 1], stationGps)
        : double.infinity;

    if (dPrev == double.infinity && dNext == double.infinity) return null;

    final int idA, idB;
    final double t;

    if (dPrev < dNext && nearestIdx > 0) {
      // Vehicle is between (nearestIdx-1) and nearest → nearest is segment end
      idA = stationIds[nearestIdx - 1];
      idB = stationIds[nearestIdx];
      // t: 0 = at A, 1 = at B; train near A → small dPrev → small t
      t = dPrev / (dPrev + minDist);
    } else if (nearestIdx < stationIds.length - 1) {
      // Vehicle is between nearest and (nearestIdx+1) → nearest is segment start
      idA = stationIds[nearestIdx];
      idB = stationIds[nearestIdx + 1];
      t = minDist / (minDist + dNext);
    } else {
      return null;
    }

    return TrainEstimate(
      betweenStationIds: [idA, idB],
      confidence: 1.0,
      isEstimated: false,
      t: t.clamp(0.0, 1.0),
    );
  }

  // ── Haversine helpers ──────────────────────────────────────────────────────

  static double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in metres
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLam = (lng2 - lng1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLam / 2) * sin(dLam / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _haversineById(
    double lat,
    double lng,
    int id,
    Map<int, ({double lat, double lng})> gps,
  ) {
    final g = gps[id];
    if (g == null) return double.infinity;
    return _haversine(lat, lng, g.lat, g.lng);
  }
}

class TrainEstimator {
  final List<int> stationIds;
  final int bufferSize;

  // stationId → list of recent density values (newest last)
  final Map<int, List<double>> _buffer = {};

  TrainEstimator({required this.stationIds, this.bufferSize = 3});

  void addSnapshot({required int stationId, required double density}) {
    _buffer.putIfAbsent(stationId, () => []).add(density);
    if (_buffer[stationId]!.length > bufferSize) {
      _buffer[stationId]!.removeAt(0);
    }
  }

  /// Returns best estimate or null if confidence < 0.4.
  TrainEstimate? estimate() {
    TrainEstimate? best;

    for (int i = 0; i < stationIds.length - 1; i++) {
      final idA = stationIds[i];
      final idB = stationIds[i + 1];
      final bufA = _buffer[idA];
      final bufB = _buffer[idB];

      if (bufA == null || bufA.length < 2) continue;
      if (bufB == null || bufB.length < 2) continue;

      final deltaA = bufA.first - bufA.last; // positive = decreasing
      final deltaB = bufB.last - bufB.first; // positive = increasing

      if (deltaA > 0 && deltaB > 0) {
        final confidence = (deltaA < deltaB ? deltaA : deltaB) * 2;
        if (confidence >= 0.4) {
          if (best == null || confidence > best.confidence) {
            best = TrainEstimate(
              betweenStationIds: [idA, idB],
              confidence: confidence.clamp(0.0, 1.0),
            );
          }
        }
      }
    }

    return best;
  }

  int bufferLengthForStation(int id) => _buffer[id]?.length ?? 0;
}

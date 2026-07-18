// mobile/test/features/transit_map/train_estimator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/features/transit_map/train_estimator.dart';

void main() {
  group('TrainEstimator', () {
    late TrainEstimator estimator;

    setUp(() {
      estimator = TrainEstimator(stationIds: [1, 2, 3, 4]);
    });

    test('returns null when buffer has fewer than 2 snapshots per station', () {
      estimator.addSnapshot(stationId: 1, density: 0.8);
      estimator.addSnapshot(stationId: 2, density: 0.3);
      expect(estimator.estimate(), isNull);
    });

    test('returns estimate when density decreases at A and increases at B', () {
      // Station 2: density decreasing (train just left)
      estimator.addSnapshot(stationId: 2, density: 0.9);
      estimator.addSnapshot(stationId: 2, density: 0.7);
      estimator.addSnapshot(stationId: 2, density: 0.5);
      // Station 3: density increasing (train approaching)
      estimator.addSnapshot(stationId: 3, density: 0.2);
      estimator.addSnapshot(stationId: 3, density: 0.4);
      estimator.addSnapshot(stationId: 3, density: 0.6);

      final result = estimator.estimate();
      expect(result, isNotNull);
      expect(result!.betweenStationIds, [2, 3]);
      expect(result.confidence, greaterThanOrEqualTo(0.4));
    });

    test('returns null when confidence < 0.4', () {
      // Small density changes — low confidence
      estimator.addSnapshot(stationId: 1, density: 0.5);
      estimator.addSnapshot(stationId: 1, density: 0.48);
      estimator.addSnapshot(stationId: 2, density: 0.5);
      estimator.addSnapshot(stationId: 2, density: 0.52);

      final result = estimator.estimate();
      expect(result, isNull);
    });

    test('buffer caps at 3 snapshots per station (oldest dropped)', () {
      for (int i = 0; i < 5; i++) {
        estimator.addSnapshot(stationId: 1, density: i * 0.1);
      }
      expect(estimator.bufferLengthForStation(1), 3);
    });
  });
}

// mobile/lib/core/providers/train_estimate_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/signalr_provider.dart';
import '../../features/transit_map/train_estimator.dart';

/// Family key: ordered stationIds list from LineModel.stationIds.
///
/// IMPORTANT: Riverpod uses reference equality for List keys.
/// Always pass `lineModel.stationIds!` (a stable reference from the provider),
/// never an inline list literal. Use `trainEstimateProvider(line.stationIds!)`.
final trainEstimateProvider = StreamProvider.family<TrainEstimate?, List<int>>(
  (ref, stationIds) async* {
    final estimator = TrainEstimator(stationIds: stationIds);

    // Use ref.read to get the stream — NOT ref.watch.
    // ref.watch inside a StreamProvider body would restart the stream
    // (and reset the estimator buffer) on every SignalR update.
    await for (final crowdState in ref.read(signalRProvider.notifier).stream) {
      for (final entry in crowdState.entries) {
        estimator.addSnapshot(stationId: entry.key, density: entry.value.density);
      }
      yield estimator.estimate();
    }
  },
);

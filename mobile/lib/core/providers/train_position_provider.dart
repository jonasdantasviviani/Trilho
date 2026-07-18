// mobile/lib/core/providers/train_position_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/train_position_model.dart';
import 'app_providers.dart';

/// Polls GET /api/trains/positions every 30 seconds.
/// Emits an empty list on network error so the provider stays alive
/// and the UI falls back gracefully to crowd-based estimates.
final trainPositionProvider =
    StreamProvider<List<TrainPositionModel>>((ref) async* {
  final api = ref.read(apiServiceProvider);
  while (true) {
    try {
      yield await api.getTrainPositions();
    } catch (_) {
      yield const [];
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

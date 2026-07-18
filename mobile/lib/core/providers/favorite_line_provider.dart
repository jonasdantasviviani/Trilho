import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kPrefsBox = 'app_prefs';
const _kFavoriteLineKey = 'favorite_line_code';

/// Persists the user's single favorite transit line code in Hive.
/// null means no line is favorited.
class FavoriteLineNotifier extends StateNotifier<String?> {
  FavoriteLineNotifier() : super(_loadInitial());

  static String? _loadInitial() {
    try {
      final box = Hive.box(_kPrefsBox);
      final val = box.get(_kFavoriteLineKey) as String?;
      return val?.isEmpty == true ? null : val;
    } catch (_) {
      return null;
    }
  }

  /// Toggles the given [lineCode] as favorite.
  /// If it is already the favorite, it is unset.
  Future<void> toggle(String lineCode) async {
    final next = state == lineCode ? null : lineCode;
    state = next;
    try {
      final box = Hive.box(_kPrefsBox);
      if (next == null) {
        await box.delete(_kFavoriteLineKey);
      } else {
        await box.put(_kFavoriteLineKey, next);
      }
    } catch (_) {}
  }

  bool isFavorite(String lineCode) => state == lineCode;
}

final favoriteLineProvider =
    StateNotifierProvider<FavoriteLineNotifier, String?>(
  (ref) => FavoriteLineNotifier(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/line_model.dart';
import 'app_providers.dart';

final linesProvider = FutureProvider<List<LineModel>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getLines();
});

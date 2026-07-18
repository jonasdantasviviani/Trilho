import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_health_model.dart';
import 'app_providers.dart';

/// Busca GET /api/health/services (público, sem autenticação).
/// Sempre resolve — em caso de erro de rede, [ServiceHealthFetch.connectionError]
/// contém a mensagem para exibição no painel de detalhes.
final serviceHealthProvider =
    FutureProvider.autoDispose<ServiceHealthFetch>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getServiceHealth();
});

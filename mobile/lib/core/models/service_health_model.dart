/// Envelope retornado pelo provider após tentativa de GET /api/health/services.
/// Quando a API está inacessível, [result] é null e [connectionError] contém
/// a mensagem da exceção para exibir no painel de detalhes.
class ServiceHealthFetch {
  final ServiceHealthResult? result;
  final String? connectionError;

  const ServiceHealthFetch({this.result, this.connectionError});

  bool get isApiOnline => result != null;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Status de saúde de um serviço externo retornado por GET /api/health/services.
class ServiceHealth {
  final String source;
  final String status; // "Healthy" | "Degraded" | "Down" | "Unknown"
  final String ageLabel;
  final double ageSeconds;
  final String? lastError;

  const ServiceHealth({
    required this.source,
    required this.status,
    required this.ageLabel,
    required this.ageSeconds,
    this.lastError,
  });

  factory ServiceHealth.fromJson(Map<String, dynamic> j) => ServiceHealth(
        source:     j['source']     as String? ?? '',
        status:     j['status']     as String? ?? 'Unknown',
        ageLabel:   j['ageLabel']   as String? ?? 'N/A',
        ageSeconds: (j['ageSeconds'] as num?)?.toDouble() ?? -1,
        lastError:  j['lastError']  as String?,
      );

  bool get isHealthy  => status == 'Healthy';
  bool get isDegraded => status == 'Degraded';
  bool get isDown     => status == 'Down';
  bool get isUnknown  => status == 'Unknown';
}

/// Envelope retornado por GET /api/health/services.
class ServiceHealthResult {
  final String api;          // "ok" quando a API está acessível
  final DateTime checkedAt;
  final List<ServiceHealth> sources;

  const ServiceHealthResult({
    required this.api,
    required this.checkedAt,
    required this.sources,
  });

  factory ServiceHealthResult.fromJson(Map<String, dynamic> j) =>
      ServiceHealthResult(
        api:       j['api']       as String? ?? 'unknown',
        checkedAt: DateTime.tryParse(j['checkedAt'] as String? ?? '') ??
            DateTime.now(),
        sources: (j['sources'] as List? ?? [])
            .map((e) => ServiceHealth.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

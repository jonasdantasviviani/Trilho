import 'package:dio/dio.dart';
import '../constants.dart';

class AbacatePayService {
  late final Dio _dio;

  AbacatePayService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Creates a PIX charge via /api/payments/create-billing.
  /// Returns [PixChargeResult] with the QR code data to show in-app.
  Future<PixChargeResult> createPixCharge({
    required String email,
    required String name,
    String? taxId,
    required int priceInCents,
    String? description,
  }) async {
    final resp = await _dio.post('/api/payments/create-billing', data: {
      'email': email,
      'name': name,
      if (taxId != null) 'taxId': taxId,
      'priceInCents': priceInCents,
      if (description != null) 'description': description,
    });

    final data = resp.data as Map<String, dynamic>;
    return PixChargeResult.fromJson(data);
  }

  /// Polls /api/payments/billing/{pixId} for payment status.
  Future<PixStatus?> checkPaymentStatus(String pixId) async {
    try {
      final resp = await _dio.get('/api/payments/billing/$pixId');
      final data = resp.data as Map<String, dynamic>;
      return PixStatus.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class PixChargeResult {
  final String pixId;

  /// PIX copia-e-cola string (EMV/BR Code format).
  final String brCode;

  /// QR code as base64-encoded PNG. Display with Image.memory(base64Decode(..)).
  final String brCodeBase64;

  final int amount;
  final String status;
  final String? expiresAt;
  final bool isDevMode;

  const PixChargeResult({
    required this.pixId,
    required this.brCode,
    required this.brCodeBase64,
    required this.amount,
    required this.status,
    this.expiresAt,
    required this.isDevMode,
  });

  factory PixChargeResult.fromJson(Map<String, dynamic> j) => PixChargeResult(
        pixId:        j['pixId'] as String? ?? '',
        brCode:       j['brCode'] as String? ?? '',
        brCodeBase64: j['brCodeBase64'] as String? ?? '',
        amount:       (j['amount'] as num?)?.toInt() ?? 0,
        status:       j['status'] as String? ?? 'PENDING',
        expiresAt:    j['expiresAt'] as String?,
        isDevMode:    j['devMode'] as bool? ?? false,
      );

  bool get isPending   => status == 'PENDING';
  bool get isPaid      => status == 'PAID' || status == 'CONFIRMED' || status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED' || status == 'CANCELED' || status == 'EXPIRED';
}

class PixStatus {
  final String pixId;
  final String status;
  final int amount;
  final bool isDevMode;

  const PixStatus({
    required this.pixId,
    required this.status,
    required this.amount,
    required this.isDevMode,
  });

  factory PixStatus.fromJson(Map<String, dynamic> j) => PixStatus(
        pixId:     j['pixId'] as String? ?? '',
        status:    j['status'] as String? ?? '',
        amount:    (j['amount'] as num?)?.toInt() ?? 0,
        isDevMode: j['devMode'] as bool? ?? false,
      );

  bool get isPaid      => status == 'PAID' || status == 'CONFIRMED' || status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED' || status == 'CANCELED' || status == 'EXPIRED';
}

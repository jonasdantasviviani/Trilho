import 'package:dio/dio.dart';
import '../constants.dart';
import 'auth_service.dart';

class SubscriptionService {
  late final Dio _dio;
  final AuthService _auth = AuthService();

  SubscriptionService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  Future<void> _setToken() async {
    final token = await _auth.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<SubscriptionStatus> getStatus() async {
    await _setToken();
    try {
      final resp = await _dio.get('/api/subscription/status');
      return SubscriptionStatus.fromJson(resp.data);
    } catch (e) {
      return SubscriptionStatus(
        isActive: false,
        planName: 'Premium Mensal',
        priceInCents: 990,
      );
    }
  }

  Future<SubscriptionResult> cancel() async {
    await _setToken();
    try {
      final resp = await _dio.post('/api/subscription/cancel');
      return SubscriptionResult(
        success: true,
        message: resp.data['message'] ?? 'Assinatura cancelada',
        accessUntil: resp.data['accessUntil'],
      );
    } catch (e) {
      return SubscriptionResult(
        success: false,
        message: 'Erro ao cancelar assinatura',
      );
    }
  }

  Future<SubscriptionResult> reactivate() async {
    await _setToken();
    try {
      final resp = await _dio.post('/api/subscription/reactivate');
      return SubscriptionResult(
        success: true,
        message: resp.data['message'] ?? 'Assinatura reativada',
      );
    } catch (e) {
      return SubscriptionResult(
        success: false,
        message: 'Erro ao reativar assinatura',
      );
    }
  }

  Future<ChangePlanResult> changePlan(String planType) async {
    await _setToken();
    try {
      final resp = await _dio.post('/api/subscription/change-plan', data: {
        'planType': planType,
      });
      return ChangePlanResult(
        success: true,
        planName: resp.data['planName'],
        price: resp.data['price'],
        billingId: resp.data['billingId'],
        url: resp.data['url'],
      );
    } catch (e) {
      return ChangePlanResult(success: false);
    }
  }

  Future<List<SubscriptionHistoryItem>> getHistory() async {
    await _setToken();
    try {
      final resp = await _dio.get('/api/subscription/history');
      final items = (resp.data['subscriptions'] as List)
          .map((item) => SubscriptionHistoryItem.fromJson(item))
          .toList();
      return items;
    } catch (e) {
      return [];
    }
  }
}

class SubscriptionStatus {
  final bool isActive;
  final DateTime? isPremiumUntil;
  final String planName;
  final int priceInCents;
  final String currency;
  final String paymentMethod;
  final bool autoRenew;
  final bool canCancel;
  final bool canChangePlan;
  final DateTime? nextBillingDate;

  SubscriptionStatus({
    required this.isActive,
    this.isPremiumUntil,
    required this.planName,
    required this.priceInCents,
    this.currency = 'BRL',
    this.paymentMethod = 'PIX/CARD',
    this.autoRenew = true,
    this.canCancel = true,
    this.canChangePlan = true,
    this.nextBillingDate,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['isActive'] ?? false,
      isPremiumUntil: json['isPremiumUntil'] != null
          ? DateTime.parse(json['isPremiumUntil'])
          : null,
      planName: json['planName'] ?? 'Premium Mensal',
      priceInCents: json['priceInCents'] ?? 990,
      currency: json['currency'] ?? 'BRL',
      paymentMethod: json['paymentMethod'] ?? 'PIX/CARD',
      autoRenew: json['autoRenew'] ?? true,
      canCancel: json['canCancel'] ?? true,
      canChangePlan: json['canChangePlan'] ?? true,
      nextBillingDate: json['nextBillingDate'] != null
          ? DateTime.parse(json['nextBillingDate'])
          : null,
    );
  }

  String get formattedPrice {
    return 'R\$ ${(priceInCents / 100).toStringAsFixed(2)}';
  }

  String get formattedDate {
    if (isPremiumUntil == null) return '-';
    return '${isPremiumUntil!.day.toString().padLeft(2, '0')}/${isPremiumUntil!.month.toString().padLeft(2, '0')}/${isPremiumUntil!.year}';
  }
}

class SubscriptionResult {
  final bool success;
  final String message;
  final DateTime? accessUntil;

  SubscriptionResult({
    required this.success,
    required this.message,
    this.accessUntil,
  });
}

class ChangePlanResult {
  final bool success;
  final String? planName;
  final int? price;
  final String? billingId;
  final String? url;

  ChangePlanResult({
    required this.success,
    this.planName,
    this.price,
    this.billingId,
    this.url,
  });
}

class SubscriptionHistoryItem {
  final String id;
  final DateTime date;
  final int amount;
  final String status;
  final String description;
  final String paymentMethod;

  SubscriptionHistoryItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.status,
    required this.description,
    required this.paymentMethod,
  });

  factory SubscriptionHistoryItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionHistoryItem(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date']),
      amount: json['amount'] ?? 0,
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      paymentMethod: json['paymentMethod'] ?? '',
    );
  }

  String get formattedPrice {
    return 'R\$ ${(amount / 100).toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../constants.dart';
import 'abacate_pay_service.dart';
import 'auth_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final AbacatePayService _abacatePay = AbacatePayService();
  final AuthService _auth = AuthService();
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    // Pass our backend userId to RevenueCat so the server-to-server webhook
    // can identify which user to update (Purchases.logIn links the RC customer
    // to our UUID, which arrives in webhook payload as app_user_id).
    final userId = await _auth.getUserId();
    await RevenueCatService.initialize(userId: userId);
    _isPremium = RevenueCatService.isPremium;
  }

  Future<void> refreshStatus() async {
    await RevenueCatService.refresh();
    _isPremium = RevenueCatService.isPremium;
  }

  Future<PaymentResult> purchase({
    required String email,
    required String name,
    String? taxId,
  }) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      return _purchaseWithRevenueCat();
    }
    return _purchaseWithAbacatePay(email: email, name: name, taxId: taxId);
  }

  Future<PaymentResult> _purchaseWithRevenueCat() async {
    try {
      final success = await RevenueCatService.purchase();
      _isPremium = success;
      return PaymentResult(
        success: success,
        message: success ? 'Assinatura ativada!' : 'Compra cancelada.',
      );
    } catch (e) {
      debugPrint('RevenueCat purchase failed: $e');
      return PaymentResult(
        success: false,
        message: 'Não foi possível concluir a compra. Tente novamente.',
      );
    }
  }

  Future<PaymentResult> _purchaseWithAbacatePay({
    required String email,
    required String name,
    String? taxId,
  }) async {
    try {
      final token = await _auth.getToken();
      if (token == null) {
        return PaymentResult(
          success: false,
          message: 'Usuário não autenticado.',
        );
      }

      _abacatePay.setToken(token);

      final result = await _abacatePay.createPixCharge(
        email: email,
        name: name,
        taxId: taxId,
        priceInCents: 990,
        description: 'Trilho Premium Mensal — R\$9,90',
      );

      // Dev mode: premium already activated server-side
      if (result.isDevMode) {
        _isPremium = true;
        return PaymentResult(
          success: true,
          message: 'Modo dev: Premium ativado!',
          devMode: true,
        );
      }

      // Copy PIX copia-e-cola to clipboard as convenience
      if (result.brCode.isNotEmpty) {
        try {
          await Clipboard.setData(ClipboardData(text: result.brCode));
        } catch (_) {}
      }

      return PaymentResult(
        success: true,
        message: 'PIX gerado! Escaneie o QR code ou use o copia-e-cola.',
        pixId:        result.pixId,
        brCode:       result.brCode,
        brCodeBase64: result.brCodeBase64,
        expiresAt:    result.expiresAt,
      );
    } catch (e) {
      debugPrint('AbacatePay purchase failed: $e');
      return PaymentResult(
        success: false,
        message: 'Não foi possível processar o pagamento. Tente novamente.',
      );
    }
  }

  /// Polls the payment status of [pixId] until paid, cancelled, or timeout.
  /// Returns true if the payment was confirmed.
  Future<bool> waitForPayment(String pixId) async {
    const maxAttempts = 60; // 5 min @ 5s intervals
    const interval = Duration(seconds: 5);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);

      final status = await _abacatePay.checkPaymentStatus(pixId);
      if (status == null) continue;

      if (status.isPaid) {
        _isPremium = true;
        return true;
      }
      if (status.isCancelled) return false;
    }
    return false;
  }

  Future<PaymentResult> restore() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      final success = await RevenueCatService.restore();
      _isPremium = success;
      return PaymentResult(
        success: success,
        message: success ? 'Compras restauradas!' : 'Nenhuma compra encontrada.',
      );
    }
    return PaymentResult(
      success: _isPremium,
      message: 'Restaurar não disponível nesta plataforma.',
    );
  }
}

// ── PaymentResult ─────────────────────────────────────────────────────────────

class PaymentResult {
  final bool success;
  final String message;

  /// PIX charge ID — use with [PaymentService.waitForPayment].
  final String? pixId;

  /// PIX copia-e-cola text (EMV BR Code format).
  final String? brCode;

  /// QR code image as base64-encoded PNG.
  /// Decode with dart:convert [base64Decode] and display with [Image.memory].
  final String? brCodeBase64;

  final String? expiresAt;
  final bool devMode;

  PaymentResult({
    required this.success,
    required this.message,
    this.pixId,
    this.brCode,
    this.brCodeBase64,
    this.expiresAt,
    this.devMode = false,
  });

  bool get hasPix => brCode != null && brCode!.isNotEmpty;
}

// ── RevenueCat (iOS/Android) ──────────────────────────────────────────────────

class RevenueCatService {
  static bool _isPremium = false;
  static bool get isPremium => _isPremium;

  static Future<void> initialize({String? userId}) async {
    if (kIsWeb) return;
    try {
      await Purchases.setLogLevel(LogLevel.warn);
      final config = PurchasesConfiguration(
        Platform.isIOS
            ? AppConstants.revenuecatApiKeyIos
            : AppConstants.revenuecatApiKeyAndroid,
      );
      await Purchases.configure(config);
      // Link this RevenueCat customer to our backend user UUID.
      // The UUID will appear as app_user_id in server-to-server webhook events,
      // allowing the backend to update the correct user record automatically.
      if (userId != null) {
        await Purchases.logIn(userId);
        debugPrint('[RevenueCat] Linked customer to userId $userId');
      }
      await refresh();
    } catch (e) {
      debugPrint('RevenueCat init failed: $e');
    }
  }

  static Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _isPremium =
          info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
    } catch (e) {
      debugPrint('RevenueCat refresh failed: $e');
    }
  }

  static Future<bool> purchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages.firstOrNull;
      if (pkg == null) return false;
      final info = await Purchases.purchasePackage(pkg);
      _isPremium =
          info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
      return _isPremium;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  static Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      _isPremium =
          info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
      return _isPremium;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}

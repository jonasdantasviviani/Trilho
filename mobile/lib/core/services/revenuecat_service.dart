import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../constants.dart';

class RevenueCatService {
  static bool _isPremium = false;
  static bool get isPremium => _isPremium;

  static Future<void> initialize() async {
    if (kIsWeb) return; // purchases_flutter has no web implementation
    await Purchases.setLogLevel(LogLevel.warn);
    final config = PurchasesConfiguration(
      Platform.isIOS
          ? AppConstants.revenuecatApiKeyIos
          : AppConstants.revenuecatApiKeyAndroid,
    );
    await Purchases.configure(config);
    await _refreshStatus();
  }

  static Future<void> _refreshStatus() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _isPremium = info.entitlements.active
          .containsKey(AppConstants.premiumEntitlement);
    } catch (e) {
      debugPrint('RevenueCat status refresh failed: $e');
    }
  }

  static Future<bool> purchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages.firstOrNull;
      if (pkg == null) return false;
      final info = await Purchases.purchasePackage(pkg);
      _isPremium = info.entitlements.active
          .containsKey(AppConstants.premiumEntitlement);
      return _isPremium;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  static Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      _isPremium = info.entitlements.active
          .containsKey(AppConstants.premiumEntitlement);
      return _isPremium;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}

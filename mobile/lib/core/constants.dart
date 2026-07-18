import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// On web (Chrome) use localhost; on Android emulator use 10.0.2.2;
  /// override both with the API_BASE_URL compile-time variable if set.
  static String get apiBaseUrl {
    if (_apiBaseUrlEnv.isNotEmpty) return _apiBaseUrlEnv;
    if (kIsWeb) return 'http://localhost:5000';
    return 'http://10.0.2.2:5000'; // Android emulator → host localhost
  }

  static String get signalrHubUrl => '$apiBaseUrl/hubs/crowd';

  // AdMob test IDs (replace with real IDs from AdMob console)
  static const String admobBannerAndroid     = 'ca-app-pub-3940256099942544/6300978111';
  static const String admobBannerIos         = 'ca-app-pub-3940256099942544/2934735716';
  static const String admobInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String admobInterstitialIos     = 'ca-app-pub-3940256099942544/4411468910';

  // RevenueCat (replace with real keys from RevenueCat dashboard)
  static const String revenuecatApiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_KEY';
  static const String revenuecatApiKeyIos     = 'YOUR_REVENUECAT_IOS_KEY';
  static const String premiumEntitlement      = 'premium';
  static const String premiumProductId        = 'trilho_premium_monthly';

  // Registered (gratuito) users have unlimited basic queries + ads.
  // Anonymous users have a daily limit (see UsageTracker.anonymousLimit).
  static const int anonymousQueryLimit = 10; // per day, resets daily
}

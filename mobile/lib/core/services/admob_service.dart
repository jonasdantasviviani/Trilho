import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants.dart';

class AdMobService {
  static Future<void> initialize() async {
    if (kIsWeb) return; // google_mobile_ads has no web implementation
    await MobileAds.instance.initialize();
    loadInterstitial(); // preload for anonymous users
  }

  static String get bannerAdUnitId =>
      (!kIsWeb && Platform.isIOS) ? AppConstants.admobBannerIos : AppConstants.admobBannerAndroid;

  static String get interstitialAdUnitId =>
      (!kIsWeb && Platform.isIOS)
          ? AppConstants.admobInterstitialIos
          : AppConstants.admobInterstitialAndroid;

  static InterstitialAd? _interstitialAd;

  static Future<void> loadInterstitial() async {
    if (kIsWeb) return;
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial failed to load: ${err.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Shows an interstitial ad for anonymous users making a query.
  /// Loads a new ad silently if none is cached; shows if ready.
  static Future<void> showAnonymousQueryAd() async {
    if (_interstitialAd != null) {
      await showInterstitial();
    } else {
      // Load for next time; don't block the current query
      loadInterstitial();
    }
  }

  static Future<void> showInterstitial() async {
    if (kIsWeb) return;
    if (_interstitialAd == null) {
      await loadInterstitial();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial(); // pre-load next
      },
    );
    await _interstitialAd!.show();
  }
}

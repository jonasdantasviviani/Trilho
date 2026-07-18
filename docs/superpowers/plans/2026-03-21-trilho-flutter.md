# Trilho Flutter App Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Flutter 3.x app for Trilho — real-time public transit crowding viewer with map, line/station detail, freemium gate, AdMob, and RevenueCat.

**Architecture:** Riverpod for state, go_router for navigation, SignalR for real-time updates, Hive for local usage tracking, AdMob banner + interstitial for free tier, RevenueCat for premium subscription.

**Tech Stack:** Flutter 3.x, Riverpod 2.5, go_router 13, google_maps_flutter 2.6, signalr_netcore 1.3, hive_flutter, purchases_flutter (RevenueCat), google_mobile_ads, fl_chart, dio.

**Working directory:** `C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/mobile`

---

## Chunk 1: Scaffold & Models

### Task 1: pubspec.yaml & Project Structure

**Files:**
- Create: `mobile/pubspec.yaml`
- Create: `mobile/lib/main.dart`
- Create: `mobile/lib/core/constants.dart`
- Create: `mobile/android/app/src/main/AndroidManifest.xml` (update)

- [ ] **Step 1: Create Flutter project** (skip if already exists)

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit
flutter create mobile --org com.trilho --project-name trilho --platforms android,ios
```

- [ ] **Step 2: Write pubspec.yaml**

`mobile/pubspec.yaml`:
```yaml
name: trilho
description: Trilho — lotação em tempo real do transporte público
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^13.2.0
  google_maps_flutter: ^2.6.1
  geolocator: ^11.0.0
  geofence_service: ^5.0.0
  signalr_netcore: ^1.3.6
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0
  purchases_flutter: ^6.25.0
  google_mobile_ads: ^5.1.0
  fl_chart: ^0.68.0
  cached_network_image: ^3.3.1
  dio: ^5.4.3+1
  intl: ^0.19.0
  path_provider: ^2.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.9
  flutter_lints: ^3.0.0
  mockito: ^5.4.4

flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

- [ ] **Step 3: Create assets folder**

```bash
mkdir -p C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/mobile/assets/images
```

- [ ] **Step 4: Install dependencies**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/mobile
flutter pub get
```

- [ ] **Step 5: Create constants**

`mobile/lib/core/constants.dart`:
```dart
class AppConstants {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000', // Android emulator → localhost
  );
  static const String signalrHubUrl = '$apiBaseUrl/hubs/crowd';

  // AdMob IDs (replace with real IDs from AdMob console)
  static const String admobBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';   // test ID
  static const String admobBannerIos     = 'ca-app-pub-3940256099942544/2934735716';   // test ID
  static const String admobInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712'; // test ID
  static const String admobInterstitialIos     = 'ca-app-pub-3940256099942544/4411468910'; // test ID

  // RevenueCat
  static const String revenuecatApiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_KEY';
  static const String revenuecatApiKeyIos     = 'YOUR_REVENUECAT_IOS_KEY';
  static const String premiumEntitlement = 'premium';
  static const String premiumProductId   = 'trilho_premium_monthly';

  static const int freeQueryLimit = 3;
}
```

---

### Task 2: Models

**Files:**
- Create: `mobile/lib/core/models/line_model.dart`
- Create: `mobile/lib/core/models/station_model.dart`
- Create: `mobile/lib/core/models/crowd_model.dart`
- Create: `mobile/lib/core/models/usage_model.dart`

- [ ] **Step 1: Create models**

`mobile/lib/core/models/line_model.dart`:
```dart
class LineModel {
  final int id;
  final String code;
  final String name;
  final String type;
  final String colorHex;
  final String currentStatus;
  final String? statusMessage;

  const LineModel({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.colorHex,
    required this.currentStatus,
    this.statusMessage,
  });

  factory LineModel.fromJson(Map<String, dynamic> j) => LineModel(
        id: j['id'] as int,
        code: j['code'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        colorHex: j['colorHex'] as String,
        currentStatus: j['currentStatus'] as String,
        statusMessage: j['statusMessage'] as String?,
      );

  // Parse "#RRGGBB" or "RRGGBB"
  int get colorValue => int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16);
}
```

`mobile/lib/core/models/station_model.dart`:
```dart
class StationModel {
  final int id;
  final String name;
  final String densityLevel; // Low | Medium | High | Packed
  final double density;      // 0.0–1.0

  const StationModel({
    required this.id,
    required this.name,
    required this.densityLevel,
    required this.density,
  });

  factory StationModel.fromJson(Map<String, dynamic> j) => StationModel(
        id: j['id'] as int,
        name: j['name'] as String,
        densityLevel: j['densityLevel'] as String,
        density: (j['density'] as num).toDouble(),
      );
}
```

`mobile/lib/core/models/crowd_model.dart`:
```dart
class CrowdModel {
  final int stationId;
  final String stationName;
  final double density;
  final String densityLevel;
  final String source;
  final DateTime capturedAt;
  final List<CrowdHistoryPoint> history;

  const CrowdModel({
    required this.stationId,
    required this.stationName,
    required this.density,
    required this.densityLevel,
    required this.source,
    required this.capturedAt,
    required this.history,
  });

  factory CrowdModel.fromJson(Map<String, dynamic> j) => CrowdModel(
        stationId: j['stationId'] as int,
        stationName: j['stationName'] as String,
        density: (j['density'] as num).toDouble(),
        densityLevel: j['densityLevel'] as String,
        source: j['source'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        history: (j['history'] as List)
            .map((h) => CrowdHistoryPoint.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

class CrowdHistoryPoint {
  final double density;
  final String level;
  final DateTime capturedAt;

  const CrowdHistoryPoint({
    required this.density,
    required this.level,
    required this.capturedAt,
  });

  factory CrowdHistoryPoint.fromJson(Map<String, dynamic> j) => CrowdHistoryPoint(
        density: (j['density'] as num).toDouble(),
        level: j['level'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
      );
}
```

`mobile/lib/core/models/usage_model.dart`:
```dart
class UsageModel {
  final int queriesUsed;
  final int queriesLimit;
  final bool isPremium;

  const UsageModel({
    required this.queriesUsed,
    required this.queriesLimit,
    required this.isPremium,
  });

  factory UsageModel.fromJson(Map<String, dynamic> j) => UsageModel(
        queriesUsed: j['queriesUsed'] as int,
        queriesLimit: j['queriesLimit'] as int,
        isPremium: j['isPremium'] as bool,
      );

  bool get canQuery => isPremium || queriesUsed < queriesLimit;
  int get remaining => isPremium ? 999 : (queriesLimit - queriesUsed).clamp(0, queriesLimit);
}
```

---

### Task 3: API Service & Token Storage

**Files:**
- Create: `mobile/lib/core/services/api_service.dart`
- Create: `mobile/lib/core/services/auth_service.dart`

- [ ] **Step 1: Create AuthService**

`mobile/lib/core/services/auth_service.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  Future<void> ensureRegistered(ApiService api) async {
    final token = await getToken();
    if (token != null) return;

    final response = await api.register();
    await _storage.write(key: _tokenKey, value: response['token'] as String);
    await _storage.write(key: _userIdKey, value: response['userId'] as String);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
  }
}
```

- [ ] **Step 2: Create ApiService**

`mobile/lib/core/services/api_service.dart`:
```dart
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/crowd_model.dart';
import '../models/line_model.dart';
import '../models/station_model.dart';
import '../models/usage_model.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<Map<String, dynamic>> register() async {
    final resp = await _dio.post('/api/auth/register');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<LineModel>> getLines() async {
    final resp = await _dio.get('/api/lines');
    return (resp.data as List).map((j) => LineModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getLineStatus(String code) async {
    final resp = await _dio.get('/api/lines/$code/status');
    return resp.data as Map<String, dynamic>;
  }

  Future<CrowdModel> getStationCrowd(int stationId) async {
    final resp = await _dio.get('/api/stations/$stationId/crowd');
    return CrowdModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<UsageModel> getUsage() async {
    final resp = await _dio.get('/api/users/me/usage');
    return UsageModel.fromJson(resp.data as Map<String, dynamic>);
  }
}
```

---

### Task 4: Services — AdMob, RevenueCat, UsageTracker

**Files:**
- Create: `mobile/lib/core/services/admob_service.dart`
- Create: `mobile/lib/core/services/revenuecat_service.dart`
- Create: `mobile/lib/core/services/usage_tracker.dart`

- [ ] **Step 1: Create UsageTracker**

`mobile/lib/core/services/usage_tracker.dart`:
```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'revenuecat_service.dart';

class UsageTracker {
  static const _boxName = 'usage';
  static const int _limit = 3;

  Future<bool> canQuery() async {
    if (RevenueCatService.isPremium) return true;
    final box = await Hive.openBox<dynamic>(_boxName);
    _resetIfNewDay(box);
    final count = box.get('count', defaultValue: 0) as int;
    return count < _limit;
  }

  Future<void> recordQuery() async {
    if (RevenueCatService.isPremium) return;
    final box = await Hive.openBox<dynamic>(_boxName);
    _resetIfNewDay(box);
    final count = box.get('count', defaultValue: 0) as int;
    await box.put('count', count + 1);
  }

  Future<int> queriesRemaining() async {
    if (RevenueCatService.isPremium) return 999;
    final box = await Hive.openBox<dynamic>(_boxName);
    _resetIfNewDay(box);
    final count = box.get('count', defaultValue: 0) as int;
    return (_limit - count).clamp(0, _limit);
  }

  void _resetIfNewDay(Box<dynamic> box) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (box.get('date') != today) {
      box.put('date', today);
      box.put('count', 0);
    }
  }
}
```

- [ ] **Step 2: Create RevenueCatService**

`mobile/lib/core/services/revenuecat_service.dart`:
```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../constants.dart';

class RevenueCatService {
  static bool _isPremium = false;
  static bool get isPremium => _isPremium;

  static Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.warning);
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
      _isPremium = info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
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
      _isPremium = info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
      return _isPremium;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  static Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      _isPremium = info.entitlements.active.containsKey(AppConstants.premiumEntitlement);
      return _isPremium;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}
```

- [ ] **Step 3: Create AdMobService**

`mobile/lib/core/services/admob_service.dart`:
```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants.dart';

class AdMobService {
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static String get bannerAdUnitId =>
      Platform.isIOS ? AppConstants.admobBannerIos : AppConstants.admobBannerAndroid;

  static String get interstitialAdUnitId =>
      Platform.isIOS ? AppConstants.admobInterstitialIos : AppConstants.admobInterstitialAndroid;

  static InterstitialAd? _interstitialAd;

  static Future<void> loadInterstitial() async {
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

  static Future<void> showInterstitial() async {
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
```

---

## Chunk 2: Riverpod Providers

### Task 5: Providers

**Files:**
- Create: `mobile/lib/core/providers/app_providers.dart`
- Create: `mobile/lib/core/providers/lines_provider.dart`
- Create: `mobile/lib/core/providers/crowd_provider.dart`
- Create: `mobile/lib/core/providers/usage_provider.dart`
- Create: `mobile/lib/core/providers/signalr_provider.dart`

- [ ] **Step 1: Create base service providers**

`mobile/lib/core/providers/app_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/usage_tracker.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final usageTrackerProvider = Provider<UsageTracker>((ref) => UsageTracker());
```

- [ ] **Step 2: Create LinesProvider**

`mobile/lib/core/providers/lines_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/line_model.dart';
import 'app_providers.dart';

final linesProvider = FutureProvider<List<LineModel>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getLines();
});
```

- [ ] **Step 3: Create CrowdProvider**

`mobile/lib/core/providers/crowd_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/crowd_model.dart';
import 'app_providers.dart';

final crowdProvider = FutureProvider.family<CrowdModel, int>((ref, stationId) async {
  final api = ref.read(apiServiceProvider);
  return api.getStationCrowd(stationId);
});
```

- [ ] **Step 4: Create UsageProvider**

`mobile/lib/core/providers/usage_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/usage_model.dart';
import '../services/revenuecat_service.dart';
import 'app_providers.dart';

final usageProvider = FutureProvider<UsageModel>((ref) async {
  // Local check first (faster)
  final tracker = ref.read(usageTrackerProvider);
  final remaining = await tracker.queriesRemaining();
  return UsageModel(
    queriesUsed: 3 - remaining,
    queriesLimit: RevenueCatService.isPremium ? 999 : 3,
    isPremium: RevenueCatService.isPremium,
  );
});

final canQueryProvider = FutureProvider<bool>((ref) async {
  final tracker = ref.read(usageTrackerProvider);
  return tracker.canQuery();
});
```

- [ ] **Step 5: Create SignalR provider**

`mobile/lib/core/providers/signalr_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants.dart';

class SignalRNotifier extends StateNotifier<Map<int, String>> {
  late final HubConnection _hub;

  SignalRNotifier() : super({}) {
    _connect();
  }

  Future<void> _connect() async {
    _hub = HubConnectionBuilder()
        .withUrl(AppConstants.signalrHubUrl)
        .withAutomaticReconnect()
        .build();

    _hub.on('CrowdUpdated', (args) {
      if (args == null || args.isEmpty) return;
      final data = args[0] as Map<String, dynamic>;
      final stationId = data['stationId'] as int;
      final level = data['densityLevel'] as String;
      state = {...state, stationId: level};
    });

    await _hub.start();
  }

  Future<void> subscribeLine(String lineCode) async {
    if (_hub.state == HubConnectionState.Connected) {
      await _hub.invoke('SubscribeLine', args: [lineCode]);
    }
  }

  @override
  void dispose() {
    _hub.stop();
    super.dispose();
  }
}

final signalRProvider = StateNotifierProvider<SignalRNotifier, Map<int, String>>(
  (ref) => SignalRNotifier(),
);
```

---

## Chunk 3: Screens

### Task 6: Router & main.dart

**Files:**
- Create: `mobile/lib/router.dart`
- Modify: `mobile/lib/main.dart`

- [ ] **Step 1: Create router**

`mobile/lib/router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/map/map_screen.dart';
import 'features/line_detail/line_detail_screen.dart';
import 'features/station_detail/station_detail_screen.dart';
import 'features/paywall/paywall_screen.dart';
import 'features/settings/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'map',
      builder: (ctx, state) => const MapScreen(),
    ),
    GoRoute(
      path: '/line/:code',
      name: 'line_detail',
      builder: (ctx, state) => LineDetailScreen(
        lineCode: state.pathParameters['code']!,
      ),
    ),
    GoRoute(
      path: '/station/:id',
      name: 'station_detail',
      builder: (ctx, state) => StationDetailScreen(
        stationId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/paywall',
      name: 'paywall',
      builder: (ctx, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (ctx, state) => const SettingsScreen(),
    ),
  ],
);
```

- [ ] **Step 2: Create main.dart**

`mobile/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/services/admob_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/revenuecat_service.dart';
import 'core/providers/app_providers.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AdMobService.initialize();
  await RevenueCatService.initialize();
  runApp(const ProviderScope(child: TrilhoApp()));
}

class TrilhoApp extends ConsumerStatefulWidget {
  const TrilhoApp({super.key});

  @override
  ConsumerState<TrilhoApp> createState() => _TrilhoAppState();
}

class _TrilhoAppState extends ConsumerState<TrilhoApp> {
  @override
  void initState() {
    super.initState();
    // Register anonymously on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = ref.read(apiServiceProvider);
      final auth = ref.read(authServiceProvider);
      await auth.ensureRegistered(api);
      // Set JWT on dio after registration
      final token = await auth.getToken();
      if (token != null) api.setToken(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Trilho',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

---

### Task 7: MapScreen

**Files:**
- Create: `mobile/lib/features/map/map_screen.dart`
- Create: `mobile/lib/features/map/density_marker.dart`

- [ ] **Step 1: Create density marker helper**

`mobile/lib/features/map/density_marker.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DensityMarker {
  static BitmapDescriptor forLevel(String level) {
    final hue = switch (level) {
      'Low'    => BitmapDescriptor.hueGreen,
      'Medium' => BitmapDescriptor.hueYellow,
      'High'   => BitmapDescriptor.hueOrange,
      'Packed' => BitmapDescriptor.hueRed,
      _        => BitmapDescriptor.hueAzure,
    };
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  static Color colorForLevel(String level) => switch (level) {
    'Low'    => Colors.green,
    'Medium' => Colors.yellow.shade700,
    'High'   => Colors.orange,
    'Packed' => Colors.red,
    _        => Colors.grey,
  };

  static String labelForLevel(String level) => switch (level) {
    'Low'    => 'Tranquilo',
    'Medium' => 'Moderado',
    'High'   => 'Cheio',
    'Packed' => 'Lotado',
    _        => '—',
  };
}
```

- [ ] **Step 2: Create MapScreen**

`mobile/lib/features/map/map_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/providers/lines_provider.dart';
import '../../core/providers/signalr_provider.dart';
import 'density_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _spCenter = LatLng(-23.5505, -46.6333);

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(linesProvider);
    final realtimeLevels = ref.watch(signalRProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trilho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: linesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (lines) {
          return Column(
            children: [
              // Line chips row
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final line = lines[i];
                    final color = Color(line.colorValue);
                    return ActionChip(
                      backgroundColor: color.withOpacity(0.15),
                      side: BorderSide(color: color),
                      label: Text(line.code, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      onPressed: () => context.push('/line/${line.code}'),
                    );
                  },
                ),
              ),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(target: _spCenter, zoom: 11),
                  markers: const {}, // Populated via station data in future iteration
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

### Task 8: LineDetailScreen

**Files:**
- Create: `mobile/lib/features/line_detail/line_detail_screen.dart`

- [ ] **Step 1: Create LineDetailScreen**

`mobile/lib/features/line_detail/line_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/station_model.dart';
import '../../core/providers/app_providers.dart';
import '../map/density_marker.dart';

final _lineDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, code) async {
  final api = ref.read(apiServiceProvider);
  return api.getLineStatus(code);
});

class LineDetailScreen extends ConsumerWidget {
  final String lineCode;

  const LineDetailScreen({super.key, required this.lineCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_lineDetailProvider(lineCode));

    return Scaffold(
      appBar: AppBar(title: Text('Linha $lineCode')),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (data) {
          final status = data['status'] as String;
          final message = data['statusMessage'] as String?;
          final stations = (data['stations'] as List)
              .map((s) => StationModel.fromJson(s as Map<String, dynamic>))
              .toList();

          return Column(
            children: [
              // Status banner
              Container(
                width: double.infinity,
                color: _statusColor(status),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusLabel(status),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (message != null)
                      Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              // Stations list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: stations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final s = stations[i];
                    return ListTile(
                      leading: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: DensityMarker.colorForLevel(s.densityLevel),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(s.name),
                      trailing: Text(
                        DensityMarker.labelForLevel(s.densityLevel),
                        style: TextStyle(
                          color: DensityMarker.colorForLevel(s.densityLevel),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => context.push('/station/${s.id}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'Normal'        => Colors.green,
    'ReducedSpeed'  => Colors.orange,
    'Partial'       => Colors.deepOrange,
    'Suspended'     => Colors.red,
    _               => Colors.grey,
  };

  String _statusLabel(String status) => switch (status) {
    'Normal'        => 'Operação Normal',
    'ReducedSpeed'  => 'Velocidade Reduzida',
    'Partial'       => 'Operação Parcial',
    'Suspended'     => 'Linha Paralisada',
    _               => status,
  };
}
```

---

### Task 9: StationDetailScreen (freemium gate)

**Files:**
- Create: `mobile/lib/features/station_detail/station_detail_screen.dart`
- Create: `mobile/lib/features/station_detail/crowd_chart.dart`

- [ ] **Step 1: Create CrowdChart**

`mobile/lib/features/station_detail/crowd_chart.dart`:
```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/models/crowd_model.dart';
import '../map/density_marker.dart';

class CrowdChart extends StatelessWidget {
  final List<CrowdHistoryPoint> history;

  const CrowdChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = history.reversed.toList().asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.density * 100);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
              reservedSize: 36,
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
```

- [ ] **Step 2: Create StationDetailScreen**

`mobile/lib/features/station_detail/station_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/providers/crowd_provider.dart';
import '../../core/providers/usage_provider.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/admob_service.dart';
import '../map/density_marker.dart';
import 'crowd_chart.dart';

class StationDetailScreen extends ConsumerStatefulWidget {
  final int stationId;
  const StationDetailScreen({super.key, required this.stationId});

  @override
  ConsumerState<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends ConsumerState<StationDetailScreen> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadBannerIfNeeded();
    _recordQueryAndShowInterstitial();
  }

  void _loadBannerIfNeeded() async {
    final can = await ref.read(canQueryProvider.future);
    if (!can) return; // paywall will show instead
    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
    setState(() {});
  }

  void _recordQueryAndShowInterstitial() async {
    final tracker = ref.read(usageTrackerProvider);
    final canQuery = await tracker.canQuery();
    if (!canQuery) return;
    await tracker.recordQuery();
    await AdMobService.showInterstitial();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canQueryAsync = ref.watch(canQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estação')),
      body: canQueryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (canQuery) {
          if (!canQuery) {
            return _buildPaywall(context);
          }
          return _buildDetail();
        },
      ),
    );
  }

  Widget _buildPaywall(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Limite diário atingido',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Você usou suas 3 consultas gratuitas de hoje.\nAssine o Trilho Premium para acesso ilimitado.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.star),
              label: const Text('Ver Planos Premium'),
              onPressed: () => context.push('/paywall'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail() {
    final crowdAsync = ref.watch(crowdProvider(widget.stationId));
    return Column(
      children: [
        Expanded(
          child: crowdAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (crowd) {
              final color = DensityMarker.colorForLevel(crowd.densityLevel);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(crowd.stationName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  // Density indicator
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Column(children: [
                      Text(
                        DensityMarker.labelForLevel(crowd.densityLevel),
                        style: TextStyle(
                          color: color,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: crowd.density,
                        color: color,
                        backgroundColor: color.withOpacity(0.2),
                      ),
                      const SizedBox(height: 4),
                      Text('${(crowd.density * 100).toStringAsFixed(0)}% da capacidade',
                          style: const TextStyle(color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  // History chart
                  if (crowd.history.isNotEmpty) ...[
                    Text('Últimas 3 horas',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(height: 160, child: CrowdChart(history: crowd.history)),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Fonte: ${crowd.source} • Atualizado ${_formatTime(crowd.capturedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
        // Banner ad for free users
        if (_bannerAd != null)
          SafeArea(
            child: SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    return 'há ${diff.inHours}h';
  }
}
```

---

### Task 10: PaywallScreen & SettingsScreen

**Files:**
- Create: `mobile/lib/features/paywall/paywall_screen.dart`
- Create: `mobile/lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Create PaywallScreen**

`mobile/lib/features/paywall/paywall_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/revenuecat_service.dart';
import '../../core/providers/usage_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;

  Future<void> _purchase() async {
    setState(() => _loading = true);
    try {
      final success = await RevenueCatService.purchase();
      if (success && mounted) {
        ref.invalidate(usageProvider);
        ref.invalidate(canQueryProvider);
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium ativado! Obrigado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      final success = await RevenueCatService.restore();
      if (mounted) {
        ref.invalidate(usageProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Compras restauradas!' : 'Nenhuma compra encontrada.')),
        );
        if (success) context.pop();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Icon(Icons.train, size: 80, color: Color(0xFF1565C0)),
            const SizedBox(height: 16),
            Text(
              'Trilho Premium',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'R\$9,90/mês',
              style: TextStyle(fontSize: 22, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _Feature(icon: Icons.all_inclusive, label: 'Consultas ilimitadas'),
            _Feature(icon: Icons.block, label: 'Sem anúncios'),
            _Feature(icon: Icons.history, label: 'Histórico completo de lotação'),
            _Feature(icon: Icons.notifications, label: 'Alertas de linha (em breve)'),
            const Spacer(),
            FilledButton(
              onPressed: _loading ? null : _purchase,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Assinar por R\$9,90/mês'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : _restore,
              child: const Text('Restaurar compras'),
            ),
            const SizedBox(height: 8),
            Text(
              'A assinatura é renovada automaticamente. Cancele a qualquer momento.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF1565C0)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 15)),
      ]),
    );
  }
}
```

- [ ] **Step 2: Create SettingsScreen**

`mobile/lib/features/settings/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/usage_provider.dart';
import '../../core/services/revenuecat_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          usageAsync.when(
            loading: () => const ListTile(title: Text('Carregando...')),
            error: (_, __) => const SizedBox.shrink(),
            data: (usage) => Column(children: [
              ListTile(
                leading: Icon(
                  usage.isPremium ? Icons.star : Icons.star_border,
                  color: usage.isPremium ? Colors.amber : null,
                ),
                title: Text(usage.isPremium ? 'Trilho Premium' : 'Plano Gratuito'),
                subtitle: usage.isPremium
                    ? const Text('Obrigado por apoiar o Trilho!')
                    : Text('${usage.remaining} consultas restantes hoje'),
              ),
              if (!usage.isPremium)
                ListTile(
                  leading: const Icon(Icons.upgrade),
                  title: const Text('Assinar Premium'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/paywall'),
                ),
            ]),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o Trilho'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Trilho',
              applicationVersion: '1.0.0',
              children: const [
                Text(
                  'Trilho mostra a lotação estimada do transporte público em tempo real. '
                  'Os dados de lotação são inferidos a partir de fontes públicas e histórico de passageiros.',
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacidade & LGPD'),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Privacidade'),
                content: const Text(
                  'O Trilho não coleta dados pessoais identificáveis.\n\n'
                  'Seu usuário é identificado por um UUID anônimo, sem nome, e-mail ou qualquer PII.\n\n'
                  'Localização (futura feature) é enviada apenas como ping anônimo e deletada após 10 minutos.',
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run Flutter analyze**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/mobile
flutter analyze
```
Expected: No issues found (or only minor warnings).

- [ ] **Step 4: Run Flutter tests**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/mobile
flutter test
```
Expected: All tests pass.

- [ ] **Step 5: Commit Flutter app**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit
git add mobile/
git commit -m "feat: add complete Flutter app — map, line detail, station detail, paywall, settings"
```

---

## Chunk 4: README

### Task 11: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**

`README.md`:
```markdown
# Trilho

Trilho é um app Flutter + .NET 8 que indica em tempo real o nível de lotação de trens, metrô e ônibus. Inicialmente focado em São Paulo, mas projetado para funcionar em qualquer cidade com transporte público.

## Pré-requisitos

- [Flutter SDK 3.19+](https://flutter.dev/docs/get-started/install)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)

## Setup

### 1. Variáveis de ambiente

```bash
cp .env.example .env
# Edite .env com:
# OLHOVIVO_TOKEN — cadastre em sptrans.com.br/desenvolvedores
# JWT_SECRET — string aleatória de 32+ caracteres
```

### 2. Subir infraestrutura

```bash
docker-compose up -d db redis
```

### 3. Rodar backend (dev local)

```bash
cd backend
dotnet run --project Trilho.API
# API disponível em http://localhost:5000
# Swagger em http://localhost:5000/swagger
```

### 4. Rodar app Flutter

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

### 5. Subir stack completa com Docker

```bash
docker-compose up --build
```

## Checklist de Configuração

- [ ] Token OlhoVivo: `sptrans.com.br/desenvolvedores`
- [ ] Google Cloud: habilitar Maps SDK Android + iOS → API key no AndroidManifest + Info.plist
- [ ] AdMob: criar banner e interstitial → atualizar IDs em `lib/core/constants.dart`
- [ ] RevenueCat: criar produto `trilho_premium_monthly` → atualizar chaves em `constants.dart`
- [ ] Cittamobi: inspecionar via mitmproxy → implementar `CitamobiProvider`

## Arquitetura

```
mobile/                  Flutter app (Riverpod + go_router)
backend/
  Trilho.Domain/         Entidades, enums, interfaces
  Trilho.Infrastructure/ EF Core, scrapers, workers, Redis
  Trilho.API/            Minimal API + SignalR
docker-compose.yml       PostgreSQL/PostGIS + Redis + API
```

## Fontes de dados

| Fonte | Dados |
|-------|-------|
| SPTrans OlhoVivo | Posição ônibus em tempo real |
| Metrô SP (scraping) | Status operacional linhas 1–5, 15 |
| CPTM (scraping) | Status operacional linhas 7–13 |
| Cittamobi (TODO) | Posição trens CPTM |
| PDFs Metrô SP | Histórico de passageiros (seed) |

## Licença

MIT
```

- [ ] **Step 2: Final commit**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit
git add README.md
git commit -m "docs: add README with setup instructions"
```

---

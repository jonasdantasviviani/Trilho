import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/providers/app_providers.dart';
import 'core/services/admob_service.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/geofencing_service.dart';
import 'core/services/payment_service.dart';
import 'core/widgets/app_theme.dart';
import 'router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional at startup — the app must open even without
  // google-services.json / GoogleService-Info.plist configured.
  // Social auth and FCM are only activated after a successful init.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FcmService().initialize();
  } catch (e) {
    debugPrint('[main] Firebase not configured — social auth / FCM unavailable: $e');
  }

  await Hive.initFlutter();
  await Hive.openBox('app_prefs');

  // Native-only services — skip on web where platform channels are unavailable.
  if (!kIsWeb) {
    try {
      await AdMobService.initialize();
    } catch (e) {
      debugPrint('[main] AdMob unavailable: $e');
    }
    try {
      await PaymentService().initialize();
    } catch (e) {
      debugPrint('[main] PaymentService unavailable: $e');
    }
  }

  final box = Hive.box('app_prefs');

  // Create a SINGLE ApiService instance that both main() and all Riverpod
  // providers will share. This prevents the token set during auth from being
  // invisible to subsequent requests made by providers.
  final api  = ApiService();
  final auth = AuthService();

  // Restore persisted token immediately so providers can make authenticated
  // requests as soon as the app launches (returning users).
  final savedToken = await auth.getToken();
  if (savedToken != null) {
    api.setToken(savedToken);
  }

  // Auto-register anonymously on first launch so the user sees the map
  // immediately without a forced login screen. Social login is opt-in from Settings.
  if (box.get('auth_done') != 'true') {
    try {
      final geofencing = GeofencingService(apiService: api);
      await auth.ensureRegistered(api, geofencing);
      debugPrint('[main] Anonymous registration completed.');
    } catch (e) {
      // Non-fatal — the router will handle the auth_done = false case.
      debugPrint('[main] Anonymous registration failed (offline?): $e');
    }
  }

  final savedTheme = box.get('theme_mode') as String?;
  final initialTheme = savedTheme == 'dark'
      ? ThemeMode.dark
      : savedTheme == 'light'
          ? ThemeMode.light
          : ThemeMode.system;

  runApp(ProviderScope(
    overrides: [
      // Pass the pre-authenticated ApiService so every provider uses the
      // same instance (and the same Bearer token).
      apiServiceProvider.overrideWithValue(api),
      themeModeProvider.overrideWith((ref) => initialTheme),
    ],
    child: const TrilhoApp(),
  ));
}

class TrilhoApp extends ConsumerStatefulWidget {
  const TrilhoApp({super.key});

  @override
  ConsumerState<TrilhoApp> createState() => _TrilhoAppState();
}

class _TrilhoAppState extends ConsumerState<TrilhoApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Trilho',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import 'auth_service.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthService _auth = AuthService();

  final _notificationController = StreamController<RemoteNotification>.broadcast();
  Stream<RemoteNotification> get onNotification => _notificationController.stream;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _registerToken();
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerToken();
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    _initialized = true;
  }

  Future<String?> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
        _messaging.onTokenRefresh.listen(_sendTokenToServer);
      }
      return token;
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
      return null;
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final jwt = await _auth.getToken();
      if (jwt == null) return;

      final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
      dio.options.headers['Authorization'] = 'Bearer $jwt';

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

      await dio.post('/api/notifications/register-token', data: {
        'token': token,
        'platform': platform,
      });

      debugPrint('FCM token registered to server');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _notificationController.add(notification);
      _showLocalNotification(notification, message.data);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification opened app: ${message.data}');
  }

  Future<void> _showLocalNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) async {
    debugPrint('FCM notification: ${notification.title} - ${notification.body}');
  }

  Future<void> subscribeToLine(String lineCode) async {
    try {
      final topic = 'line_${lineCode.toLowerCase()}';
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Failed to subscribe to line: $e');
    }
  }

  Future<void> unsubscribeFromLine(String lineCode) async {
    try {
      final topic = 'line_${lineCode.toLowerCase()}';
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Failed to unsubscribe from line: $e');
    }
  }

  Future<List<String>> getSubscribedLines() async {
    return [];
  }

  void dispose() {
    _notificationController.close();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

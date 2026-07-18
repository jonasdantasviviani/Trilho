import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';
import 'geofencing_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey    = 'jwt_token';
  static const _userIdKey   = 'user_id';
  static const _kBoxName    = 'app_prefs';
  static const _kAuthDoneKey = 'auth_done';

  Future<String?> getToken()  => _storage.read(key: _tokenKey);
  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  /// Returns true when the user already has a saved JWT token.
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> ensureRegistered(ApiService api, GeofencingService geofencing) async {
    final token = await getToken();
    if (token != null) {
      // Returning user — token already stored; just wire up the api and geofencing.
      api.setToken(token);
      await _startGeofencing(api, geofencing);
      return;
    }

    final response = await api.register();
    await _storage.write(key: _tokenKey,  value: response['token']  as String);
    await _storage.write(key: _userIdKey, value: response['userId'] as String);

    // Mark auth as complete so the router redirect can read it synchronously
    // from Hive without waiting for secure-storage on next cold start.
    Hive.box(_kBoxName).put(_kAuthDoneKey, 'true');

    api.setToken(response['token'] as String);
    await _startGeofencing(api, geofencing);
  }

  /// Authenticates via a Firebase social-login ID token.
  ///
  /// Backend endpoint: POST /api/auth/social
  /// Body:   { "provider": "google"|"apple"|"facebook", "idToken": "..." }
  /// Response: { "token": "...", "userId": "..." }
  ///
  /// Falls back to anonymous registration when the backend returns an error
  /// (e.g. social-auth endpoint not yet deployed).
  Future<void> loginWithSocial(
    ApiService api,
    GeofencingService geofencing, {
    required String provider,
    required String idToken,
    String? displayName,
    String? email,
  }) async {
    try {
      final response = await api.loginWithSocial(
        provider: provider,
        idToken: idToken,
        displayName: displayName,
        email: email,
      );
      await _storage.write(key: _tokenKey,  value: response['token']  as String);
      await _storage.write(key: _userIdKey, value: response['userId'] as String);
      Hive.box(_kBoxName).put(_kAuthDoneKey, 'true');
      Hive.box(_kBoxName).put('is_social_auth', 'true');
      api.setToken(response['token'] as String);
      await _startGeofencing(api, geofencing);
    } catch (_) {
      // Backend does not support social auth yet — fall back to anonymous.
      await ensureRegistered(api, geofencing);
    }
  }

  /// Authenticates via a Firebase ID token obtained from any social provider
  /// or email/password sign-in.
  ///
  /// Backend endpoint: POST /api/auth/firebase
  /// Body:     { "idToken": "..." }
  /// Response: { "token": "...", "user": { "id": ..., "email": "...", ... } }
  Future<void> loginWithFirebase(
    ApiService api,
    GeofencingService geofencing, {
    required String idToken,
  }) async {
    final response = await api.loginWithFirebase(idToken);
    final token = response['token'] as String;
    final userId = (response['user'] as Map<String, dynamic>)['id'].toString();
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    Hive.box(_kBoxName).put(_kAuthDoneKey, 'true');
    Hive.box(_kBoxName).put('is_social_auth', 'true');
    api.setToken(token);
    await _startGeofencing(api, geofencing);
  }

  Future<void> _startGeofencing(
    ApiService api,
    GeofencingService geofencing,
  ) async {
    try {
      final stations = await api.getStations();
      await geofencing.initialize(stations);
    } catch (e) {
      // Geofencing is best-effort — spec RN-11/12
      debugPrint('[AuthService] geofencing init failed: $e');
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    Hive.box(_kBoxName).delete(_kAuthDoneKey);
    Hive.box(_kBoxName).delete('is_social_auth');
  }
}

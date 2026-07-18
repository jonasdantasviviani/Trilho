import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/crowd_model.dart';
import '../models/line_model.dart';
import '../models/service_health_model.dart';
import '../models/station_model.dart';
import '../models/station_arrivals_model.dart';
import '../models/train_position_model.dart';
import '../models/usage_model.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  ApiService.withDio(Dio dio) {
    _dio = dio;
  }

  String get baseUrl => _dio.options.baseUrl;

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<Map<String, dynamic>> register() async {
    final resp = await _dio.post('/api/auth/register');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<LineModel>> getLines() async {
    final resp = await _dio.get('/api/lines');
    return (resp.data as List)
        .map((j) => LineModel.fromJson(j as Map<String, dynamic>))
        .toList();
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

  Future<Map<String, dynamic>> loginWithSocial({
    required String provider,
    required String idToken,
    String? displayName,
    String? email,
  }) async {
    final resp = await _dio.post('/api/auth/social', data: {
      'provider': provider,
      'idToken': idToken,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<List<StationModel>> getStations() async {
    final resp = await _dio.get('/api/stations');
    return (resp.data as List)
        .map((j) => StationModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> loginWithFirebase(String idToken) async {
    final resp = await _dio.post('/api/auth/firebase', data: {'idToken': idToken});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> postPing(
      {required double lat, required double lng}) async {
    try {
      final resp = await _dio.post('/api/users/pings', data: {
        'lat': lat,
        'lng': lng,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      return resp.data as Map<String, dynamic>?;
    } catch (_) {
      // Silent — crowdsourcing pings are best-effort (spec RN-12)
      return null;
    }
  }

  Future<List<TrainPositionModel>> getTrainPositions() async {
    final resp = await _dio.get('/api/trains/positions');
    return (resp.data as List)
        .map((j) => TrainPositionModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<StationArrivals> getStationArrivals(int stationId) async {
    final resp = await _dio.get('/api/stations/$stationId/arrivals');
    return StationArrivals.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Público — não requer token.
  /// Sempre retorna [ServiceHealthFetch]: em caso de erro de rede o campo
  /// [connectionError] contém a mensagem da exceção.
  Future<ServiceHealthFetch> getServiceHealth() async {
    try {
      final resp = await _dio.get(
        '/api/health/services',
        options: Options(
          sendTimeout:    const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return ServiceHealthFetch(
        result: ServiceHealthResult.fromJson(resp.data as Map<String, dynamic>),
      );
    } catch (e) {
      return ServiceHealthFetch(connectionError: e.toString());
    }
  }
}

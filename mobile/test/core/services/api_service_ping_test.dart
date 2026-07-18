import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:trilho/core/services/api_service.dart';

// Use GenerateNiceMocks — Dio has generic return types that plain GenerateMocks can't handle
@GenerateNiceMocks([MockSpec<Dio>()])
import 'api_service_ping_test.mocks.dart';

void main() {
  late ApiService api;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    api = ApiService.withDio(mockDio);
  });

  group('postPing', () {
    test('sends lat, lng, and UTC ISO-8601 timestamp to /api/users/pings', () async {
      when(mockDio.post(
        '/api/users/pings',
        data: anyNamed('data'),
      )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/users/pings'),
            statusCode: 200,
            data: {'registered': true},
          ));

      await api.postPing(lat: -23.5505, lng: -46.6333);

      final captured = verify(mockDio.post(
        '/api/users/pings',
        data: captureAnyNamed('data'),
      )).captured.single as Map<String, dynamic>;

      expect(captured['lat'], -23.5505);
      expect(captured['lng'], -46.6333);
      expect(captured['timestamp'], isA<String>());
      expect((captured['timestamp'] as String).endsWith('Z'), isTrue);
    });

    test('swallows DioException silently', () async {
      when(mockDio.post(
        '/api/users/pings',
        data: anyNamed('data'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/users/pings'),
      ));

      await expectLater(
        api.postPing(lat: -23.5505, lng: -46.6333),
        completes,
      );
    });
  });

  group('getStations', () {
    test('returns list of StationModel with lat/lng', () async {
      when(mockDio.get('/api/stations')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/stations'),
            statusCode: 200,
            data: [
              {
                'id': 1,
                'name': 'Luz',
                'lineCode': '10',
                'densityLevel': 'Medium',
                'density': 0.5,
                'lat': -23.5342,
                'lng': -46.6337,
              }
            ],
          ));

      final stations = await api.getStations();

      expect(stations.length, 1);
      expect(stations.first.id, 1);
      expect(stations.first.lat, -23.5342);
      expect(stations.first.lng, -46.6337);
    });
  });
}

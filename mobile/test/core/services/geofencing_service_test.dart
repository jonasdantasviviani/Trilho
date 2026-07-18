import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:trilho/core/services/api_service.dart';
import 'package:trilho/core/services/geofencing_service.dart';

@GenerateMocks([ApiService])
import 'geofencing_service_test.mocks.dart';

void main() {
  late MockApiService mockApi;
  late GeofencingService service;

  setUp(() {
    mockApi = MockApiService();
    // Pass skipNativeInit: true so GeofenceService.instance is never touched in tests
    service = GeofencingService(apiService: mockApi, skipNativeInit: true);
  });

  group('handleEnter', () {
    test('calls postPing with the correct coordinates', () async {
      when(mockApi.postPing(lat: anyNamed('lat'), lng: anyNamed('lng')))
          .thenAnswer((_) async {});

      await service.handleEnter(lat: -23.5505, lng: -46.6333);

      verify(mockApi.postPing(lat: -23.5505, lng: -46.6333)).called(1);
    });

    test('swallows exception from postPing silently', () async {
      when(mockApi.postPing(lat: anyNamed('lat'), lng: anyNamed('lng')))
          .thenThrow(Exception('network'));

      await expectLater(
        service.handleEnter(lat: -23.5505, lng: -46.6333),
        completes,
      );
    });
  });

  group('onStatusChanged', () {
    test('calls handleEnter only on ENTER status', () async {
      when(mockApi.postPing(lat: anyNamed('lat'), lng: anyNamed('lng')))
          .thenAnswer((_) async {});

      // Simulate ENTER event
      await service.testOnStatusChanged(
        lat: -23.5505,
        lng: -46.6333,
        isEnter: true,
      );

      verify(mockApi.postPing(lat: -23.5505, lng: -46.6333)).called(1);
    });

    test('does NOT call postPing on EXIT status', () async {
      await service.testOnStatusChanged(
        lat: -23.5505,
        lng: -46.6333,
        isEnter: false,
      );

      verifyNever(mockApi.postPing(lat: anyNamed('lat'), lng: anyNamed('lng')));
    });
  });
}

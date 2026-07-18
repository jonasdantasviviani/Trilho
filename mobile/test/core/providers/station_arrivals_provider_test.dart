// mobile/test/core/providers/station_arrivals_provider_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/station_arrivals_model.dart';
import 'package:trilho/core/providers/station_arrivals_provider.dart';
import 'package:trilho/core/providers/app_providers.dart';
import 'package:trilho/core/services/api_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([ApiService])
import 'station_arrivals_provider_test.mocks.dart';

void main() {
  test('returns arrivals from API when successful', () async {
    final mockApi = MockApiService();
    const fakeArrivals = StationArrivals(
      stationId: 1,
      directions: [
        DirectionArrivals(
          terminus: 'Jabaquara',
          arrivals: [ArrivalTime(estimatedMinutes: 3, isEstimated: false)],
        ),
      ],
    );

    when(mockApi.getStationArrivals(1)).thenAnswer((_) async => fakeArrivals);

    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(mockApi)],
    );
    addTearDown(container.dispose);

    final result = await container.read(stationArrivalsProvider(1).future);
    expect(result.directions.length, 1);
    expect(result.directions[0].terminus, 'Jabaquara');
  });

  test('returns unavailable when API returns 404', () async {
    final mockApi = MockApiService();
    when(mockApi.getStationArrivals(1)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/stations/1/arrivals'),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(mockApi)],
    );
    addTearDown(container.dispose);

    final result = await container.read(stationArrivalsProvider(1).future);
    expect(result.directions, isEmpty);
  });
}

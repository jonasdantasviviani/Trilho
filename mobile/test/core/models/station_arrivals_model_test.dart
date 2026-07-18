// mobile/test/core/models/station_arrivals_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/station_arrivals_model.dart';

void main() {
  group('StationArrivals', () {
    test('fromJson parses directions and arrival times', () {
      final json = {
        'stationId': 10,
        'directions': [
          {
            'terminus': 'Jabaquara',
            'arrivals': [
              {'estimatedMinutes': 2, 'isEstimated': false},
              {'estimatedMinutes': 8, 'isEstimated': false},
            ],
          },
          {
            'terminus': 'Tucuruvi',
            'arrivals': [
              {'estimatedMinutes': 4, 'isEstimated': true},
            ],
          },
        ],
      };

      final arrivals = StationArrivals.fromJson(json);
      expect(arrivals.stationId, 10);
      expect(arrivals.directions.length, 2);
      expect(arrivals.directions[0].terminus, 'Jabaquara');
      expect(arrivals.directions[0].arrivals[0].estimatedMinutes, 2);
      expect(arrivals.directions[1].arrivals[0].isEstimated, true);
    });

    test('ArrivalTime.fromJson defaults isEstimated to true when absent', () {
      final json = {'estimatedMinutes': 5};
      final arrival = ArrivalTime.fromJson(json);
      expect(arrival.isEstimated, true);
    });

    test('StationArrivals.unavailable returns empty directions list', () {
      final a = StationArrivals.unavailable(stationId: 5);
      expect(a.stationId, 5);
      expect(a.directions, isEmpty);
    });

    test('DirectionArrivals.fromJson parses optional lineCode', () {
      final json = {
        'terminus': 'Jabaquara',
        'lineCode': 'L1',
        'arrivals': [
          {'estimatedMinutes': 3, 'isEstimated': false},
        ],
      };
      final d = DirectionArrivals.fromJson(json);
      expect(d.lineCode, 'L1');
    });

    test('DirectionArrivals.fromJson lineCode is null when absent', () {
      final json = {
        'terminus': 'Jabaquara',
        'arrivals': [],
      };
      final d = DirectionArrivals.fromJson(json);
      expect(d.lineCode, isNull);
    });
  });
}

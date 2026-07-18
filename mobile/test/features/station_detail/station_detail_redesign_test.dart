// mobile/test/features/station_detail/station_detail_redesign_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/crowd_model.dart';
import 'package:trilho/core/models/station_arrivals_model.dart';
import 'package:trilho/core/models/usage_model.dart';
import 'package:trilho/core/providers/app_providers.dart';
import 'package:trilho/core/providers/city_provider.dart';
import 'package:trilho/core/providers/crowd_provider.dart';
import 'package:trilho/core/providers/station_arrivals_provider.dart';
import 'package:trilho/core/providers/usage_provider.dart';
import 'package:trilho/core/services/usage_tracker.dart';
import 'package:trilho/core/widgets/app_theme.dart';
import 'package:trilho/features/station_detail/station_detail_screen.dart';

/// Fake UsageTracker that never touches Hive.
class _FakeUsageTracker implements UsageTracker {
  @override
  Future<bool> isAnonymous() async => false;

  @override
  Future<bool> canQuery() async => true;

  @override
  Future<void> recordQuery() async {}

  @override
  Future<int> queriesRemaining() async => 3;
}

/// Shared overrides for all tests.
List<Override> _overrides({
  required CrowdModel crowd,
  required StationArrivals arrivals,
  required UsageModel usage,
}) =>
    [
      usageProvider.overrideWith((ref) => Future.value(usage)),
      crowdProvider(1).overrideWith((ref) => Future.value(crowd)),
      stationArrivalsProvider(1).overrideWith((ref) => Future.value(arrivals)),
      usageTrackerProvider.overrideWithValue(_FakeUsageTracker()),
      selectedCityProvider.overrideWith((_) => SelectedCityNotifier.skipHive()),
    ];

void main() {
  final fakeCrowd = CrowdModel(
    stationId: 1,
    stationName: 'Paraíso',
    density: 0.65,
    densityLevel: 'High',
    source: 'Test',
    capturedAt: DateTime.now(),
    history: [],
  );

  const fakeArrivals = StationArrivals(
    stationId: 1,
    directions: [
      DirectionArrivals(
        terminus: 'Jabaquara',
        arrivals: [
          ArrivalTime(estimatedMinutes: 2, isEstimated: false),
          ArrivalTime(estimatedMinutes: 8, isEstimated: false),
        ],
      ),
      DirectionArrivals(
        terminus: 'Tucuruvi',
        arrivals: [
          ArrivalTime(estimatedMinutes: 5, isEstimated: true),
        ],
      ),
    ],
  );

  const fakeUsage = UsageModel(
    queriesUsed: 0,
    queriesLimit: 3,
    isPremium: false,
    isAnonymous: false,
  );

  testWidgets('shows people estimate card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          crowd: fakeCrowd,
          arrivals: fakeArrivals,
          usage: fakeUsage,
        ),
        child: const MaterialApp(home: StationDetailScreen(stationId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('pessoas'), findsOneWidget);
  });

  testWidgets('shows both direction cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          crowd: fakeCrowd,
          arrivals: fakeArrivals,
          usage: fakeUsage,
        ),
        child: const MaterialApp(home: StationDetailScreen(stationId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('→ Jabaquara'), findsOneWidget);
    expect(find.text('← Tucuruvi'), findsOneWidget);
  });

  testWidgets('shows "Dados indisponíveis" when arrivals empty', (tester) async {
    final noArrivals = StationArrivals.unavailable(stationId: 1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          crowd: fakeCrowd,
          arrivals: noArrivals,
          usage: fakeUsage,
        ),
        child: const MaterialApp(home: StationDetailScreen(stationId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('indispon'), findsOneWidget);
  });

  testWidgets('StationDetailScreen scaffold bg is AppTheme.bgDark in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          crowd: fakeCrowd,
          arrivals: fakeArrivals,
          usage: fakeUsage,
        ),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const StationDetailScreen(stationId: 1),
        ),
      ),
    );
    await tester.pump(); // single pump, scaffold renders before async resolves
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.bgDark);
  });
}

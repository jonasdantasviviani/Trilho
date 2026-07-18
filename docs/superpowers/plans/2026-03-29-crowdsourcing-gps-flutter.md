# Crowdsourcing GPS — Flutter Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement background geofencing in the Flutter app so users passively contribute crowd density data when entering metro/CPTM stations.

**Architecture:** A thin `GeofencingService` wrapper around the `geofence_service` package loads all stations from the API on boot, creates 300 m geofences, and silently POSTs lat/lng to the backend on `ENTER` events. The backend resolves the nearest station via PostGIS. All failures are swallowed — the feature is completely transparent to the user.

**Tech Stack:** Flutter, `geofence_service: ^5.0.0`, `geolocator: ^11.0.0` (permission check), `dio: ^5.4.3+1` (existing `ApiService`), `mockito: ^5.4.4` (tests), Riverpod (existing DI pattern)

---

## What already exists (do NOT re-implement)

| Item | Status |
|------|--------|
| Backend `POST /api/users/pings` endpoint | ✅ Done — accepts `{ lat, lng, timestamp }`, resolves station via PostGIS |
| Android permissions in `AndroidManifest.xml` | ✅ Done — `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` |
| iOS permissions in `Info.plist` | ✅ Done — `NSLocationAlwaysAndWhenInUseUsageDescription` |
| `geofence_service: ^5.0.0` in `pubspec.yaml` | ✅ Done |
| `geolocator: ^11.0.0` in `pubspec.yaml` | ✅ Done |
| Backend `GET /api/stations` returning lat/lng | ✅ Done — `StationListDto(int Id, string Name, ..., double Lat, double Lng)` |

## Files to create or modify

| File | Action | Responsibility |
|------|--------|----------------|
| `mobile/lib/core/models/station_model.dart` | **Modify** | Add `lat` and `lng` fields |
| `mobile/lib/core/services/api_service.dart` | **Modify** | Add `postPing()` + `getStations()` methods; remove `final` from `_dio` |
| `mobile/lib/core/services/geofencing_service.dart` | **Create** | Wrapper: load stations, create geofences, fire pings on ENTER |
| `mobile/lib/core/providers/app_providers.dart` | **Modify** | Add `geofencingServiceProvider` |
| `mobile/lib/core/services/auth_service.dart` | **Modify** | Call `geofencingService.initialize()` after successful auth |
| `mobile/test/core/services/api_service_ping_test.dart` | **Create** | Unit tests for `postPing` |
| `mobile/test/core/services/geofencing_service_test.dart` | **Create** | Unit tests for `GeofencingService` with mocked deps |

---

## Chunk 1: StationModel + ApiService extensions

### Task 1: Extend StationModel with lat/lng

**Files:**
- Modify: `mobile/lib/core/models/station_model.dart`

The backend `GET /api/stations` returns `{ id, name, lineCode, lat, lng, densityLevel, density }`. The current `StationModel` only parses `id`, `name`, `densityLevel`, `density`. We need `lat` and `lng` for geofencing.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/models/station_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/models/station_model.dart';

void main() {
  test('StationModel.fromJson parses lat and lng', () {
    final json = {
      'id': 1,
      'name': 'Luz',
      'lineCode': '10',
      'densityLevel': 'Medium',
      'density': 0.5,
      'lat': -23.5342,
      'lng': -46.6337,
    };

    final model = StationModel.fromJson(json);

    expect(model.lat, -23.5342);
    expect(model.lng, -46.6337);
  });

  test('StationModel.fromJson defaults lat/lng to 0.0 when absent', () {
    final json = {
      'id': 1,
      'name': 'Luz',
      'densityLevel': 'Low',
      'density': 0.2,
    };

    final model = StationModel.fromJson(json);

    expect(model.lat, 0.0);
    expect(model.lng, 0.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd mobile
flutter test test/core/models/station_model_test.dart --no-pub
```

Expected: FAIL — `StationModel` has no `lat` or `lng`.

- [ ] **Step 3: Add lat/lng to StationModel**

In `mobile/lib/core/models/station_model.dart`:

```dart
class StationModel {
  final int id;
  final String name;
  final String densityLevel;
  final double density;
  final double lat;  // ADD
  final double lng;  // ADD

  const StationModel({
    required this.id,
    required this.name,
    required this.densityLevel,
    required this.density,
    this.lat = 0.0,   // ADD — default keeps existing code from breaking
    this.lng = 0.0,   // ADD
  });

  factory StationModel.fromJson(Map<String, dynamic> j) => StationModel(
        id: j['id'] as int,
        name: j['name'] as String,
        densityLevel: j['densityLevel'] as String,
        density: (j['density'] as num).toDouble(),
        lat: (j['lat'] as num?)?.toDouble() ?? 0.0,   // ADD
        lng: (j['lng'] as num?)?.toDouble() ?? 0.0,   // ADD
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd mobile
flutter test test/core/models/station_model_test.dart --no-pub
```

Expected: 2 tests PASS.

- [ ] **Step 5: Run full test suite to check no regressions**

```bash
cd mobile
flutter test --no-pub
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/core/models/station_model.dart \
        mobile/test/core/models/station_model_test.dart
git commit -m "feat(mobile): add lat/lng fields to StationModel"
```

---

### Task 2: Add postPing and getStations to ApiService

**Files:**
- Modify: `mobile/lib/core/services/api_service.dart`
- Create: `mobile/test/core/services/api_service_ping_test.dart`

Two changes to `ApiService`:
1. Remove `final` from `_dio` field to allow test injection via `ApiService.withDio()`
2. Add `postPing(lat, lng)` — silent POST to `/api/users/pings`
3. Add `getStations()` — GET `/api/stations` returning `List<StationModel>`

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/core/services/api_service_ping_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:trilho/core/services/api_service.dart';

// Use GenerateNiceMocks (not GenerateMocks) because Dio uses generic return types
// that plain GenerateMocks cannot handle correctly.
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
    });
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
cd mobile
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd mobile
flutter test test/core/services/api_service_ping_test.dart --no-pub
```

Expected: FAIL — `ApiService.withDio` not found, `postPing` not found, `getStations` not found.

- [ ] **Step 4: Implement changes to ApiService**

In `mobile/lib/core/services/api_service.dart`, make these changes:

```dart
// 1. Change the field declaration (line 9):
//    BEFORE: late final Dio _dio;
//    AFTER:  late Dio _dio;   ← remove 'final' so withDio() can assign it

// 2. Add named constructor after the default one:
ApiService.withDio(Dio dio) {
  _dio = dio;
}

// 3. Add getStations() method:
Future<List<StationModel>> getStations() async {
  final resp = await _dio.get('/api/stations');
  return (resp.data as List)
      .map((j) => StationModel.fromJson(j as Map<String, dynamic>))
      .toList();
}

// 4. Add postPing() method:
Future<void> postPing({required double lat, required double lng}) async {
  try {
    await _dio.post('/api/users/pings', data: {
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  } catch (_) {
    // Silent — crowdsourcing pings are best-effort (spec RN-12)
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd mobile
flutter test test/core/services/api_service_ping_test.dart --no-pub
```

Expected: 3 tests PASS.

- [ ] **Step 6: Run full suite to check no regressions**

```bash
cd mobile
flutter test --no-pub
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/core/services/api_service.dart \
        mobile/test/core/services/api_service_ping_test.dart \
        mobile/test/core/services/api_service_ping_test.mocks.dart
git commit -m "feat(mobile): add postPing and getStations to ApiService"
```

---

## Chunk 2: GeofencingService

### Task 3: Create GeofencingService

**Files:**
- Create: `mobile/lib/core/services/geofencing_service.dart`
- Create: `mobile/test/core/services/geofencing_service_test.dart`

> **Naming:** The package exports `GeofenceService`. Our wrapper is `GeofencingService` (with "ing") to avoid collision.

> **Testability:** Do NOT initialize `GeofenceService.instance` as an inline field — it triggers native platform calls and breaks unit tests. Instead, accept the package service as an optional constructor parameter so tests can pass a null/mock.

**Key design — geofence_service v5 API:**
```dart
// Setup — returns the same instance for chaining
GeofenceService.instance.setup(
  interval: 5000,           // ms between location checks in background
  accuracy: 100,            // GPS accuracy in meters
  loiteringDelayMs: 60000,
  statusChangeDelayMs: 10000,
  useActivityRecognition: false,
  allowMockLocations: false,
  printDevLog: false,
  geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
);

// Add listener BEFORE start
_gfService.addGeofenceStatusChangedListener(_onStatusChanged);

// Start — must be awaited; use catchError to swallow permission denials
await _gfService.start(geofences).catchError(_onError);

// Listener signature in v5:
Future<void> _onStatusChanged(
  Geofence geofence,
  GeofenceRadius radius,
  GeofenceStatus status,
  Location location,
) async { ... }

// Check for ENTER in v5:
// Option A (getter): status.isEnter
// Option B (comparison): status == GeofenceStatus.enter
// Verify which one exists by checking the installed package source (Step 1 below).
```

- [ ] **Step 1: Verify GeofenceStatus API in installed package**

Run this to find the package source:
```bash
cd mobile && flutter pub deps --style=list 2>/dev/null | grep geofence_service
```

Then locate and read the `geofence_status.dart` file:
```bash
find ~/.pub-cache -path "*/geofence_service-*/lib/src*" -name "*.dart" | xargs grep -l "GeofenceStatus" 2>/dev/null | head -5
```

Look for whether `GeofenceStatus` has an `isEnter` getter or is a plain enum to compare with `==`. Use the correct form in Step 4.

- [ ] **Step 2: Write the failing tests**

Create `mobile/test/core/services/geofencing_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geofence_service/geofence_service.dart';
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
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd mobile
flutter test test/core/services/geofencing_service_test.dart --no-pub
```

Expected: FAIL — `GeofencingService` not found.

- [ ] **Step 4: Implement GeofencingService**

Create `mobile/lib/core/services/geofencing_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:geofence_service/geofence_service.dart';
import '../models/station_model.dart';
import 'api_service.dart';

/// Flutter-side geofence radius (meters).
/// Larger than backend's 200 m to account for GPS jitter in background (spec RN-04).
const double _kRadius = 300.0;

class GeofencingService {
  final ApiService apiService;
  final bool skipNativeInit; // true in unit tests to avoid native platform calls

  GeofencingService({
    required this.apiService,
    this.skipNativeInit = false,
  });

  /// Load stations from API, create geofences, and start listening.
  /// Silently does nothing if permission is denied or stations list is empty.
  Future<void> initialize(List<StationModel> stations) async {
    if (skipNativeInit) return;

    final validStations = stations.where((s) => s.lat != 0.0 || s.lng != 0.0).toList();
    if (validStations.isEmpty) return;

    final geofences = validStations
        .map((s) => Geofence(
              id: 'station_${s.id}',
              latitude: s.lat,
              longitude: s.lng,
              radius: [GeofenceRadius(id: 'r_${s.id}', length: _kRadius)],
            ))
        .toList();

    // Setup is called here (not as an inline field) to avoid native calls during tests
    final gfService = GeofenceService.instance.setup(
      interval: 5000,
      accuracy: 100,
      loiteringDelayMs: 60000,
      statusChangeDelayMs: 10000,
      useActivityRecognition: false,
      allowMockLocations: false,
      printDevLog: false,
      geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
    );

    gfService.addGeofenceStatusChangedListener(_onStatusChanged);
    // Note: addStreamErrorListener does not exist in all v5 builds.
    // Use try/catch on start() as the safe default.
    try {
      await gfService.start(geofences);
    } catch (e) {
      _onError(e);
    }
  }

  /// Called when geofence status changes. Only acts on ENTER.
  Future<void> _onStatusChanged(
    Geofence geofence,
    GeofenceRadius radius,
    GeofenceStatus status,
    Location location,
  ) async {
    // NOTE: Verify the correct check for your installed package version.
    // Option A (v5 getter): status.isEnter
    // Option B (enum comparison): status == GeofenceStatus.enter
    // Use whichever matches the source you found in Step 1.
    final entering = status.isEnter; // adjust if needed
    await testOnStatusChanged(
      lat: location.latitude,
      lng: location.longitude,
      isEnter: entering,
    );
  }

  /// Exposed for testing — simulates a status change event.
  @visibleForTesting
  Future<void> testOnStatusChanged({
    required double lat,
    required double lng,
    required bool isEnter,
  }) async {
    if (!isEnter) return; // spec RN-06: only ENTER events trigger pings
    await handleEnter(lat: lat, lng: lng);
  }

  /// Exposed for testing — fires a ping for the given coordinates.
  @visibleForTesting
  Future<void> handleEnter({required double lat, required double lng}) async {
    await apiService.postPing(lat: lat, lng: lng);
    // postPing already swallows exceptions (spec RN-12)
  }

  void _onError(dynamic error) {
    debugPrint('[GeofencingService] error: $error'); // silent in production (spec RN-11)
  }
}
```

- [ ] **Step 5: Regenerate mocks**

```bash
cd mobile
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd mobile
flutter test test/core/services/geofencing_service_test.dart --no-pub
```

Expected: 4 tests PASS.

- [ ] **Step 7: Run full suite**

```bash
cd mobile
flutter test --no-pub
```

Expected: all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/core/services/geofencing_service.dart \
        mobile/test/core/services/geofencing_service_test.dart \
        mobile/test/core/services/geofencing_service_test.mocks.dart
git commit -m "feat(mobile): add GeofencingService with background ENTER-only pings"
```

---

## Chunk 3: Initialization via Riverpod + AuthService

### Task 4: Register GeofencingService in Riverpod and initialize after auth

**Files:**
- Modify: `mobile/lib/core/providers/app_providers.dart`
- Modify: `mobile/lib/core/services/auth_service.dart`

**Why NOT `main.dart`:** `ApiService` is provided exclusively via Riverpod (`apiServiceProvider`). It is not instantiated in `main()`. Creating `GeofencingService` in `main()` before `ProviderScope` would require a second independent `ApiService` instance, breaking the singleton pattern.

**Correct approach:**
1. Register `geofencingServiceProvider` in `app_providers.dart`, referencing `apiServiceProvider`
2. Pass `GeofencingService` into `AuthService` methods and call `initialize()` after auth succeeds

**Important — 4 setToken call sites:** `AuthService` has two auth entry points: `ensureRegistered()` (anonymous) and `loginWithSocial()` (Google/Apple/Facebook). Both result in a valid JWT. Initialize geofencing at the end of BOTH methods. In `login_screen.dart`, `setToken` is also called directly in 4 sign-in methods — but `AuthService.ensureRegistered` and `loginWithSocial` are the canonical auth paths that cover all cases.

- [ ] **Step 1: Add geofencingServiceProvider to app_providers.dart**

In `mobile/lib/core/providers/app_providers.dart`:

```dart
import '../services/geofencing_service.dart';

// Add after the existing providers:
final geofencingServiceProvider = Provider<GeofencingService>((ref) {
  final api = ref.read(apiServiceProvider);
  return GeofencingService(apiService: api);
});
```

- [ ] **Step 2: Add initGeofencing helper to AuthService**

In `mobile/lib/core/services/auth_service.dart`, add a private helper and call it from both auth methods:

```dart
// Add import at top:
import 'geofencing_service.dart';

// Add private helper method:
Future<void> _startGeofencing(
  ApiService api,
  GeofencingService geofencing,
) async {
  try {
    final stations = await api.getStations();
    await geofencing.initialize(stations);
  } catch (_) {
    // Geofencing is best-effort — spec RN-11/12
  }
}
```

In `ensureRegistered()`, after the token is saved to storage:

```dart
// After Hive.box(_kBoxName).put(_kAuthDoneKey, 'true');
await api.setToken(await getToken() ?? '');
await _startGeofencing(api, geofencing);
```

In `loginWithSocial()`, after `Hive.box(_kBoxName).put('is_social_auth', 'true');`:

```dart
await api.setToken(await getToken() ?? '');
await _startGeofencing(api, geofencing);
```

Update the method signatures to accept `GeofencingService`:

```dart
Future<void> ensureRegistered(ApiService api, GeofencingService geofencing) async { ... }

Future<void> loginWithSocial(
  ApiService api,
  GeofencingService geofencing, {
  required String provider,
  required String idToken,
  String? displayName,
  String? email,
}) async { ... }
```

- [ ] **Step 3: Update call sites in login_screen.dart**

All calls to `auth.ensureRegistered(api)` and `auth.loginWithSocial(api, ...)` must pass the geofencing service:

```dart
// In login_screen.dart, read the provider:
final geofencing = ref.read(geofencingServiceProvider);

// Then pass it:
await auth.ensureRegistered(api, geofencing);
await auth.loginWithSocial(api, geofencing, provider: ..., idToken: ...);
```

There are 4 sign-in methods in `login_screen.dart` (`_signInWithGoogle`, `_signInWithApple`, `_signInWithFacebook`, `_signInAnonymous`). Each calls `ensureRegistered` or `loginWithSocial`. Update all of them.

- [ ] **Step 4: Run full test suite**

```bash
cd mobile
flutter test --no-pub
```

Expected: all tests PASS.

- [ ] **Step 5: Analyze for warnings**

```bash
cd mobile
flutter analyze
```

Fix any errors before proceeding.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/core/providers/app_providers.dart \
        mobile/lib/core/services/auth_service.dart \
        mobile/lib/features/auth/login_screen.dart
git commit -m "feat(mobile): register GeofencingService via Riverpod, initialize after auth"
```

---

## Chunk 4: PR

### Task 5: Push and open PR

- [ ] **Step 1: Final test run**

```bash
cd mobile
flutter test --no-pub
```

Expected: all tests PASS.

- [ ] **Step 2: Run flutter analyze one last time**

```bash
cd mobile && flutter analyze
```

Fix any remaining warnings.

- [ ] **Step 3: Push**

```bash
git push origin master
```

- [ ] **Step 3: Open PR**

```bash
gh pr create \
  --title "feat(mobile): background geofencing crowdsourcing GPS (Milestone 2A)" \
  --base main \
  --body "$(cat <<'EOF'
## Summary

Implements background geofencing in the Flutter app (Milestone 2A — Crowdsourcing GPS).

- **StationModel** — adds `lat`/`lng` fields parsed from `GET /api/stations`
- **ApiService.getStations()** — new method returning stations with coordinates
- **ApiService.postPing(lat, lng)** — silent POST to backend; swallows all errors
- **GeofencingService** — 300 m geofences per station; fires ping on ENTER; no user-visible feedback

## Business rules implemented

| Rule | Description |
|------|-------------|
| RN-01 | All JWT users contribute (anon or authenticated) |
| RN-04 | Flutter geofence radius = 300 m (backend filters at 200 m via PostGIS) |
| RN-06 | Only ENTER events trigger pings — EXIT and DWELL ignored |
| RN-11 | Feature is silent — no user-visible feedback |
| RN-12 | Network failures discarded without retry |
| RN-14 | Stations loaded once after auth |

## Tests added

- `station_model_test.dart` — lat/lng parsed correctly; defaults to 0.0 when absent
- `api_service_ping_test.dart` — postPing sends correct payload + UTC timestamp; swallows DioException; getStations parses lat/lng
- `geofencing_service_test.dart` — ENTER triggers postPing; EXIT does NOT trigger postPing; exceptions swallowed

## What was already in place

- Android permissions (`ACCESS_BACKGROUND_LOCATION`)
- iOS permissions (`NSLocationAlwaysAndWhenInUseUsageDescription`)
- `geofence_service: ^5.0.0` in pubspec.yaml
- Backend endpoint `POST /api/users/pings` (Milestone 1)

Spec: `docs/superpowers/specs/2026-03-29-crowdsourcing-gps-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Notes for implementer

### If `status.isEnter` does not compile

Replace with:
```dart
status == GeofenceStatus.enter
```
Or whatever value the enum uses. Check the package source per Task 3, Step 1.

### If `gfService.addStreamErrorListener` does not exist in v5

The error listener API varies by version. Alternatives:
```dart
// Option A — wrap start() in try/catch instead:
try {
  await gfService.start(geofences);
} catch (e) {
  debugPrint('[GeofencingService] start error: $e');
}

// Option B — use onError parameter if available:
gfService.start(geofences).then((_) {}).catchError(_onError);
```

### If GeofenceService.instance.setup() returns void (not the instance)

Some versions of the package make `.setup()` return `void`. In that case, use `GeofenceService.instance` directly:
```dart
GeofenceService.instance.setup(...);
final gfService = GeofenceService.instance;
gfService.addGeofenceStatusChangedListener(_onStatusChanged);
await gfService.start(geofences).catchError(_onError);
```

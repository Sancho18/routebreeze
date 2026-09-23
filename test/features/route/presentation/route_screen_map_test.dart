// The default map of the Route screen draws the plan and fits the camera to
// the whole route once the platform view exists.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';
import 'package:routebreeze/features/route/presentation/route_cubit.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';

import '../../../helpers/fake_google_map.dart';

class MockRouteCubit extends MockCubit<RouteState> implements RouteCubit {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class FakeMapMarkers extends MapMarkers {
  @override
  Future<BitmapDescriptor> numbered(int n, {double pixelRatio = 3}) async =>
      BitmapDescriptor.defaultMarkerWithHue(n * 10);
}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  final start = Fix(origin, 12, DateTime.utc(2026, 9, 22, 10));
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: b, order: 1, visited: false),
      RouteStop(stop: a, order: 2, visited: false),
    ],
    polyline: const [origin, GeoPoint(-23.60, -46.70)],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );

  late MockRouteCubit cubit;
  late MockConnectivityService connectivity;
  late StreamController<bool> online;
  late FakeGoogleMapPlatform platform;

  setUpAll(() {
    registerFallbackValue(origin);
    registerFallbackValue(const <Stop>[]);
  });

  setUp(() {
    cubit = MockRouteCubit();
    connectivity = MockConnectivityService();
    online = StreamController<bool>();
    when(() => cubit.compute(any(), any())).thenAnswer((_) async {});
    when(() => connectivity.check()).thenAnswer((_) async => true);
    when(() => connectivity.isOnline).thenAnswer((_) => online.stream);
    whenListen(
      cubit,
      const Stream<RouteState>.empty(),
      initialState: RouteState(status: RouteStatus.ready, plan: plan),
    );
  });

  tearDown(() => online.close());

  Future<void> pumpReady(WidgetTester tester) async {
    platform = FakeGoogleMapPlatform.install(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: RouteScreen(
          start: start,
          stops: const [a, b],
          cubit: cubit,
          connectivity: connectivity,
          markers: FakeMapMarkers(),
          onStart: (_) {},
        ),
      ),
    );
    // Marker icons, platform view creation and `map#waitForMap`.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  group('RouteScreen default map', () {
    testWidgets('mounts a GoogleMap on the origin at zoom 14 with the start, '
        'the numbered stops and the brand polyline', (tester) async {
      await pumpReady(tester);

      expect(find.byType(GoogleMap), findsOneWidget);
      final map = platform.maps.single;
      expect(map.initialCameraPosition['zoom'], 14.0);
      expect(map.initialCameraPosition['target'], [-23.5614, -46.6559]);
      final markerIds = map.markersToAdd
          .map((m) => (m as Map<Object?, Object?>)['markerId'])
          .toSet();
      expect(markerIds, {'start', 'stop-pb', 'stop-pa'});
      expect(map.polylinesToAdd, hasLength(1));
      await tester.pump(RouteScreen.cameraFitDelay);
    });

    testWidgets('fits the camera to the route bounds 300 ms after the map '
        'is created, not before', (tester) async {
      await pumpReady(tester);
      final map = platform.maps.single;
      expect(map.callsOf('map#waitForMap'), hasLength(1));

      await tester.pump(const Duration(milliseconds: 299));
      expect(map.cameraAnimations, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      final update = map.cameraAnimations.single as List<Object?>;
      expect(update[0], 'newLatLngBounds');
      expect(update[1], [
        [-23.60, -46.70],
        [-23.5614, -46.6559],
      ]);
      expect(update[2], RouteScreen.cameraPadding);
    });

    testWidgets('a platform error while fitting (view not laid out yet) is '
        'swallowed and the map stays on screen', (tester) async {
      await pumpReady(tester);
      platform.failures['camera#animate'] = PlatformException(
        code: 'error',
        message: "Map size can't be 0",
      );

      await tester.pump(RouteScreen.cameraFitDelay);

      expect(tester.takeException(), isNull);
      expect(find.byType(GoogleMap), findsOneWidget);
      expect(platform.maps.single.callsOf('camera#animate'), hasLength(1));
    });

    testWidgets('leaving the screen before the fit delay skips the camera '
        'move', (tester) async {
      await pumpReady(tester);
      final map = platform.maps.single;

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(RouteScreen.cameraFitDelay);

      expect(map.cameraAnimations, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

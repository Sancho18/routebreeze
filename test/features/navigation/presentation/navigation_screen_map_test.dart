// The real `GoogleMap` on a fake platform: initial camera placement and the
// moves that following and "Recentralizar" trigger.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_screen.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';

import '../../../helpers/fake_google_map.dart';

class MockNavigationCubit extends MockCubit<NavigationState>
    implements NavigationCubit {}

class FakeMapMarkers extends MapMarkers {
  @override
  Future<BitmapDescriptor> numbered(int n, {double pixelRatio = 3}) async =>
      BitmapDescriptor.defaultMarkerWithHue(n * 10);

  @override
  Future<BitmapDescriptor> position({double pixelRatio = 3}) async =>
      BitmapDescriptor.defaultMarkerWithHue(200);
}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: a, order: 1, visited: false),
      RouteStop(stop: b, order: 2, visited: false),
    ],
    polyline: const [origin, GeoPoint(-23.60, -46.70)],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );
  final first = Fix(
    const GeoPoint(-23.562, -46.656),
    8,
    DateTime.utc(2026, 9, 22, 10, 31),
  );
  final second = Fix(
    const GeoPoint(-23.563, -46.657),
    8,
    DateTime.utc(2026, 9, 22, 10, 31, 5),
  );

  late MockNavigationCubit cubit;
  late StreamController<NavigationState> states;
  late FakeGoogleMapPlatform platform;

  NavigationState navigating(Fix fix, {bool following = true}) =>
      NavigationState(
        plan: plan,
        phase: NavigationPhase.navigating,
        fix: fix,
        following: following,
      );

  setUp(() {
    cubit = MockNavigationCubit();
    states = StreamController<NavigationState>();
  });

  tearDown(() => states.close());

  Future<void> pumpScreen(WidgetTester tester, NavigationState initial) async {
    platform = FakeGoogleMapPlatform.install(tester);
    whenListen(cubit, states.stream, initialState: initial);
    await tester.pumpWidget(
      MaterialApp(
        home: NavigationScreen(
          plan: plan,
          cubit: cubit,
          markers: FakeMapMarkers(),
          onExit: () {},
          onNewRoute: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> emit(WidgetTester tester, NavigationState state) async {
    states.add(state);
    await tester.pumpAndSettle();
  }

  group('NavigationScreen default map', () {
    testWidgets('mounts a GoogleMap on the current position at zoom 16 with '
        'the "me" marker', (tester) async {
      await pumpScreen(tester, navigating(first));

      expect(find.byType(GoogleMap), findsOneWidget);
      final map = platform.maps.single;
      expect(map.initialCameraPosition['zoom'], NavigationScreen.zoom);
      expect(map.initialCameraPosition['target'], [-23.562, -46.656]);
      final markerIds = map.markersToAdd
          .map((m) => (m as Map<Object?, Object?>)['markerId'])
          .toSet();
      expect(markerIds, {'start', 'stop-pa', 'stop-pb', 'me'});
      expect(map.callsOf('map#waitForMap'), hasLength(1));
      expect(map.cameraAnimations, isEmpty);
    });

    testWidgets('each new fix moves the camera to it while following', (
      tester,
    ) async {
      await pumpScreen(tester, navigating(first));
      final map = platform.maps.single;

      await emit(tester, navigating(second));

      expect(map.cameraAnimations, [
        [
          'newLatLng',
          [-23.563, -46.657],
        ],
      ]);
    });

    testWidgets('after a drag the camera stays put; "Recentralizar" '
        '(following again) moves it back to the position', (tester) async {
      await pumpScreen(tester, navigating(first));
      final map = platform.maps.single;

      await emit(tester, navigating(first, following: false));
      await emit(tester, navigating(second, following: false));
      expect(map.cameraAnimations, isEmpty);

      await emit(tester, navigating(second));

      expect(map.cameraAnimations, [
        [
          'newLatLng',
          [-23.563, -46.657],
        ],
      ]);
    });
  });
}

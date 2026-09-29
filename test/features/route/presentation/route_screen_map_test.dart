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
import 'package:routebreeze/core/theme/map_style.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';
import 'package:routebreeze/features/route/presentation/route_cubit.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';

import '../../../helpers/fake_google_map.dart';
import '../../../helpers/themed_app.dart';

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
      RouteStop(stop: b, order: 1),
      RouteStop(stop: a, order: 2),
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

  /// The ready screen in a bare `MaterialApp`, or in the app themes when
  /// [mode] is given.
  Future<void> pumpReady(WidgetTester tester, {ThemeMode? mode}) async {
    platform = FakeGoogleMapPlatform.install(tester);
    final screen = RouteScreen(
      start: start,
      stops: const [a, b],
      cubit: cubit,
      connectivity: connectivity,
      markers: FakeMapMarkers(),
      onStart: (_) async {},
    );
    await tester.pumpWidget(
      mode == null ? MaterialApp(home: screen) : themedApp(screen, mode: mode),
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

    testWidgets('the map is padded at the bottom by the sheet before the '
        'route is fitted', (tester) async {
      await pumpReady(tester);
      final map = platform.maps.single;

      final sheet = tester.getSize(find.byType(RouteSheet)).height;
      final paddings = [
        (map.creationParams['options']! as Map<Object?, Object?>)['padding'],
        for (final call in map.callsOf('map#update'))
          ((call.arguments as Map<Object?, Object?>)['options']
              as Map<Object?, Object?>)['padding'],
      ].nonNulls;
      expect(paddings.last, [0.0, 0.0, sheet, 0.0]);
      expect(map.cameraAnimations, isEmpty);

      await tester.pump(RouteScreen.cameraFitDelay);
      expect(map.cameraAnimations, hasLength(1));
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

  group('RouteScreen map theme', () {
    /// ARGB of the route line in the creation params.
    Object? createdRouteColor(FakeMapInstance map) =>
        (map.polylinesToAdd.single as Map<Object?, Object?>)['color'];

    testWidgets('dark mode creates the map with the dark style and the '
        '#7EA6F8 route line', (tester) async {
      await pumpReady(tester, mode: ThemeMode.dark);

      final map = platform.maps.single;
      expect(map.style, rbDarkMapStyle);
      expect(createdRouteColor(map), 0xFF7EA6F8);
      await tester.pump(RouteScreen.cameraFitDelay);
    });

    testWidgets("light mode creates the map with Google's default style and "
        'the #2A6DF4 route line', (tester) async {
      await pumpReady(tester, mode: ThemeMode.light);

      final map = platform.maps.single;
      expect(map.style, '');
      expect(createdRouteColor(map), 0xFF2A6DF4);
      await tester.pump(RouteScreen.cameraFitDelay);
    });

    testWidgets('a device theme switch restyles the same map and repaints '
        'the route line without moving the camera', (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      await pumpReady(tester, mode: ThemeMode.system);
      await tester.pump(RouteScreen.cameraFitDelay);
      final map = platform.maps.single;
      expect(map.style, '');
      expect(createdRouteColor(map), 0xFF2A6DF4);
      expect(map.cameraAnimations, hasLength(1));

      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(map.styleUpdates, [rbDarkMapStyle]);
      expect(map.polylineColorUpdates.last, 0xFF7EA6F8);

      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(map.styleUpdates, [rbDarkMapStyle, '']);
      expect(map.polylineColorUpdates.last, 0xFF2A6DF4);

      expect(platform.maps, hasLength(1));
      expect(find.byType(GoogleMap), findsOneWidget);
      expect(map.cameraAnimations, hasLength(1));
    });
  });
}

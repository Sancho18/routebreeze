import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';

class MockLocationService extends Mock implements LocationService {}

class MockRouteRepository extends Mock implements RouteRepository {}

void main() {
  late MockLocationService location;
  late MockRouteRepository routes;

  final at = DateTime.utc(2026, 9, 22, 10);
  Fix fix(double accuracy) =>
      Fix(const GeoPoint(-23.5614, -46.6559), accuracy, at);

  setUp(() {
    location = MockLocationService();
    routes = MockRouteRepository();
    when(() => routes.clear()).thenAnswer((_) async {});
    when(() => location.openAppSettings()).thenAnswer((_) async {});
    when(() => location.openLocationSettings()).thenAnswer((_) async {});
  });

  void stubAccess(LocationAccess access) =>
      when(() => location.checkAccess()).thenAnswer((_) async => access);

  void stubRequest(LocationAccess access) =>
      when(() => location.requestPermission()).thenAnswer((_) async => access);

  void stubFix(Object outcome) {
    final stub = when(
      () => location.currentFix(timeout: const Duration(seconds: 15)),
    );
    if (outcome is Fix) {
      stub.thenAnswer((_) async => outcome);
    } else {
      stub.thenThrow(outcome);
    }
  }

  test('starts checking without a start fix', () {
    expect(MapCubit(location).state, const MapState());
    expect(MapCubit(location).state.status, MapStatus.checking);
    expect(MapCubit(location).state.start, isNull);
    expect(MapCubit(location).state.resumable, isNull);
  });

  group('resume', () {
    final plan = RoutePlan(
      origin: const GeoPoint(-23.5614, -46.6559),
      stops: const [
        RouteStop(
          stop: Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66)),
          order: 1,
          visited: true,
        ),
        RouteStop(
          stop: Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70)),
          order: 2,
          visited: false,
        ),
      ],
      polyline: const [GeoPoint(-23.5614, -46.6559), GeoPoint(-23.60, -46.70)],
      distanceMeters: 6000,
      durationSeconds: 480,
      legs: const [],
      computedAt: at,
    );

    MapCubit buildReady() {
      stubAccess(LocationAccess.granted);
      stubFix(fix(12));
      return MapCubit(location, routes: routes);
    }

    blocTest<MapCubit, MapState>(
      'a persisted unfinished route → ready with resumable',
      build: () {
        when(() => routes.loadActive()).thenAnswer((_) async => plan);
        return buildReady();
      },
      act: (cubit) => cubit.init(),
      expect: () => [
        MapState(status: MapStatus.ready, start: fix(12), resumable: plan),
      ],
    );

    blocTest<MapCubit, MapState>(
      'no persisted route → resumable null',
      build: () {
        when(() => routes.loadActive()).thenAnswer((_) async => null);
        return buildReady();
      },
      act: (cubit) => cubit.init(),
      expect: () => [MapState(status: MapStatus.ready, start: fix(12))],
    );

    blocTest<MapCubit, MapState>(
      'a persisted route with every stop visited → resumable null',
      build: () {
        when(() => routes.loadActive())
            .thenAnswer((_) async => plan.markVisited('pb'));
        return buildReady();
      },
      act: (cubit) => cubit.init(),
      expect: () => [MapState(status: MapStatus.ready, start: fix(12))],
    );

    blocTest<MapCubit, MapState>(
      'a storage error is ignored → resumable null',
      build: () {
        when(() => routes.loadActive()).thenThrow(StateError('corrupt'));
        return buildReady();
      },
      act: (cubit) => cubit.init(),
      expect: () => [MapState(status: MapStatus.ready, start: fix(12))],
    );

    blocTest<MapCubit, MapState>(
      '"Nova rota" clears the persisted route and the offer',
      build: () {
        when(() => routes.loadActive()).thenAnswer((_) async => plan);
        return buildReady();
      },
      act: (cubit) async {
        await cubit.init();
        await cubit.dismissResume();
      },
      expect: () => [
        MapState(status: MapStatus.ready, start: fix(12), resumable: plan),
        MapState(status: MapStatus.ready, start: fix(12)),
      ],
      verify: (_) => verify(() => routes.clear()).called(1),
    );
  });

  group('init', () {
    blocTest<MapCubit, MapState>(
      'granted + fix of 12 m within 15 s → ready with the start fix',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(fix(12));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => [MapState(status: MapStatus.ready, start: fix(12))],
      verify: (_) {
        verify(() => location.currentFix(timeout: const Duration(seconds: 15)))
            .called(1);
        verifyNever(() => location.requestPermission());
      },
    );

    blocTest<MapCubit, MapState>(
      'accuracy exactly 50 m → ready',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(fix(50));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => [MapState(status: MapStatus.ready, start: fix(50))],
    );

    blocTest<MapCubit, MapState>(
      'accuracy 50.1 m → imprecise without a start fix',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(fix(50.1));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.imprecise)],
    );

    blocTest<MapCubit, MapState>(
      'accuracy 51 m → imprecise',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(fix(51));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.imprecise)],
    );

    blocTest<MapCubit, MapState>(
      'no fix within 15 s → timeout',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(TimeoutException('Time limit reached'));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.timeout)],
    );

    blocTest<MapCubit, MapState>(
      'a non-timeout error from the fix → timeout (retryable)',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(StateError('provider'));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.timeout)],
      errors: () => isEmpty,
    );

    blocTest<MapCubit, MapState>(
      'an error from the access check → timeout (retryable)',
      build: () {
        when(() => location.checkAccess()).thenThrow(Exception('platform'));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.timeout)],
      errors: () => isEmpty,
    );

    blocTest<MapCubit, MapState>(
      'an error from the permission request → timeout (retryable)',
      build: () {
        stubAccess(LocationAccess.denied);
        when(() => location.requestPermission())
            .thenThrow(Exception('platform'));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.timeout)],
      errors: () => isEmpty,
    );

    blocTest<MapCubit, MapState>(
      'denied → requests the permission once; granted → ready',
      build: () {
        stubAccess(LocationAccess.denied);
        stubRequest(LocationAccess.granted);
        stubFix(fix(12));
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => [MapState(status: MapStatus.ready, start: fix(12))],
      verify: (_) => verify(() => location.requestPermission()).called(1),
    );

    blocTest<MapCubit, MapState>(
      'denied → request denied again → denied',
      build: () {
        stubAccess(LocationAccess.denied);
        stubRequest(LocationAccess.denied);
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.denied)],
      verify: (_) {
        verify(() => location.requestPermission()).called(1);
        verifyNever(
          () => location.currentFix(timeout: const Duration(seconds: 15)),
        );
      },
    );

    blocTest<MapCubit, MapState>(
      'denied → request denied forever → deniedForever',
      build: () {
        stubAccess(LocationAccess.denied);
        stubRequest(LocationAccess.deniedForever);
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.deniedForever)],
    );

    blocTest<MapCubit, MapState>(
      'already denied forever → deniedForever without prompting',
      build: () {
        stubAccess(LocationAccess.deniedForever);
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.deniedForever)],
      verify: (_) => verifyNever(() => location.requestPermission()),
    );

    blocTest<MapCubit, MapState>(
      'location service off → serviceDisabled without prompting',
      build: () {
        stubAccess(LocationAccess.serviceDisabled);
        return MapCubit(location);
      },
      act: (cubit) => cubit.init(),
      expect: () => const [MapState(status: MapStatus.serviceDisabled)],
      verify: (_) => verifyNever(() => location.requestPermission()),
    );
  });

  group('retry', () {
    blocTest<MapCubit, MapState>(
      'from denied: checking again, then ready once granted',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(fix(20));
        return MapCubit(location);
      },
      seed: () => const MapState(status: MapStatus.denied),
      act: (cubit) => cubit.retry(),
      expect: () => [
        const MapState(),
        MapState(status: MapStatus.ready, start: fix(20)),
      ],
    );

    blocTest<MapCubit, MapState>(
      'from timeout: checking again, then timeout again',
      build: () {
        stubAccess(LocationAccess.granted);
        stubFix(TimeoutException('Time limit reached'));
        return MapCubit(location);
      },
      seed: () => const MapState(status: MapStatus.timeout),
      act: (cubit) => cubit.retry(),
      expect: () => const [MapState(), MapState(status: MapStatus.timeout)],
    );
  });

  group('openSettings', () {
    blocTest<MapCubit, MapState>(
      'deniedForever opens the app settings',
      build: () => MapCubit(location),
      seed: () => const MapState(status: MapStatus.deniedForever),
      act: (cubit) => cubit.openSettings(),
      expect: () => const <MapState>[],
      verify: (_) {
        verify(() => location.openAppSettings()).called(1);
        verifyNever(() => location.openLocationSettings());
      },
    );

    blocTest<MapCubit, MapState>(
      'serviceDisabled opens the device location settings',
      build: () => MapCubit(location),
      seed: () => const MapState(status: MapStatus.serviceDisabled),
      act: (cubit) => cubit.openSettings(),
      expect: () => const <MapState>[],
      verify: (_) {
        verify(() => location.openLocationSettings()).called(1);
        verifyNever(() => location.openAppSettings());
      },
    );

    blocTest<MapCubit, MapState>(
      'denied (still requestable) opens no settings screen',
      build: () => MapCubit(location),
      seed: () => const MapState(status: MapStatus.denied),
      act: (cubit) => cubit.openSettings(),
      expect: () => const <MapState>[],
      verify: (_) {
        verifyNever(() => location.openAppSettings());
        verifyNever(() => location.openLocationSettings());
      },
    );
  });
}

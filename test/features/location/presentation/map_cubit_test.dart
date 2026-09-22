import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';

class MockLocationService extends Mock implements LocationService {}

void main() {
  late MockLocationService location;

  final at = DateTime.utc(2026, 9, 22, 10);
  Fix fix(double accuracy) =>
      Fix(const GeoPoint(-23.5614, -46.6559), accuracy, at);

  setUp(() {
    location = MockLocationService();
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
  });
}

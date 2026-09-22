import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/location/data/geolocator_location_service.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

Position position({
  double lat = -23.5614,
  double lng = -46.6559,
  double accuracy = 12,
  DateTime? at,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: at ?? DateTime.utc(2026, 9, 22, 10),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late MockGeolocatorPlatform platform;
  late LocationService service;

  setUpAll(() => registerFallbackValue(const LocationSettings()));

  setUp(() {
    platform = MockGeolocatorPlatform();
    service = GeolocatorLocationService(platform: platform);
  });

  const mapped = <LocationPermission, LocationAccess>{
    LocationPermission.whileInUse: LocationAccess.granted,
    LocationPermission.always: LocationAccess.granted,
    LocationPermission.denied: LocationAccess.denied,
    LocationPermission.unableToDetermine: LocationAccess.denied,
    LocationPermission.deniedForever: LocationAccess.deniedForever,
  };

  group('checkAccess', () {
    test(
      'service disabled → serviceDisabled, permission not consulted',
      () async {
        when(() => platform.isLocationServiceEnabled())
            .thenAnswer((_) async => false);

        expect(await service.checkAccess(), LocationAccess.serviceDisabled);
        verifyNever(() => platform.checkPermission());
      },
    );

    for (final entry in mapped.entries) {
      test(
        'service enabled + ${entry.key.name} → ${entry.value.name}',
        () async {
          when(() => platform.isLocationServiceEnabled())
              .thenAnswer((_) async => true);
          when(() => platform.checkPermission())
              .thenAnswer((_) async => entry.key);

          expect(await service.checkAccess(), entry.value);
        },
      );
    }
  });

  group('requestPermission', () {
    for (final entry in mapped.entries) {
      test('prompt answered ${entry.key.name} → ${entry.value.name}', () async {
        when(() => platform.requestPermission())
            .thenAnswer((_) async => entry.key);

        expect(await service.requestPermission(), entry.value);
        verify(() => platform.requestPermission()).called(1);
      });
    }
  });

  group('currentFix', () {
    test('asks for best accuracy with a 15 s limit and maps the Position '
        'to a Fix', () async {
      final at = DateTime.utc(2026, 9, 22, 10, 30);
      when(
        () => platform.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) async => position(accuracy: 8.5, at: at));

      final fix = await service.currentFix();

      expect(fix, Fix(const GeoPoint(-23.5614, -46.6559), 8.5, at));
      final settings =
          verify(
                () => platform.getCurrentPosition(
                  locationSettings: captureAny(named: 'locationSettings'),
                ),
              ).captured.single
              as LocationSettings;
      expect(settings.accuracy, LocationAccuracy.best);
      expect(settings.timeLimit, const Duration(seconds: 15));
    });

    test('rethrows the TimeoutException when the time limit expires', () {
      when(
        () => platform.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenThrow(TimeoutException('Time limit reached'));

      expect(
        () => service.currentFix(timeout: const Duration(seconds: 15)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('watch', () {
    test('streams best-accuracy positions every 5 m mapped to Fix', () async {
      final first = DateTime.utc(2026, 9, 22, 10);
      final second = first.add(const Duration(seconds: 3));
      when(
        () => platform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          position(accuracy: 10, at: first),
          position(lat: -23.5620, lng: -46.6570, accuracy: 20, at: second),
        ]),
      );

      final fixes = await service.watch().toList();

      expect(fixes, [
        Fix(const GeoPoint(-23.5614, -46.6559), 10, first),
        Fix(const GeoPoint(-23.5620, -46.6570), 20, second),
      ]);
      final settings =
          verify(
                () => platform.getPositionStream(
                  locationSettings: captureAny(named: 'locationSettings'),
                ),
              ).captured.single
              as LocationSettings;
      expect(settings.accuracy, LocationAccuracy.best);
      expect(settings.distanceFilter, 5);
    });
  });

  group('settings', () {
    test('openAppSettings opens the app settings', () async {
      when(() => platform.openAppSettings()).thenAnswer((_) async => true);

      await service.openAppSettings();

      verify(() => platform.openAppSettings()).called(1);
      verifyNever(() => platform.openLocationSettings());
    });

    test('openLocationSettings opens the device location settings', () async {
      when(() => platform.openLocationSettings()).thenAnswer((_) async => true);

      await service.openLocationSettings();

      verify(() => platform.openLocationSettings()).called(1);
      verifyNever(() => platform.openAppSettings());
    });
  });

  test('uses GeolocatorPlatform.instance when no platform is given', () async {
    final previous = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = platform;
    addTearDown(() => GeolocatorPlatform.instance = previous);
    when(() => platform.isLocationServiceEnabled())
        .thenAnswer((_) async => false);

    expect(
      await GeolocatorLocationService().checkAccess(),
      LocationAccess.serviceDisabled,
    );
  });
}

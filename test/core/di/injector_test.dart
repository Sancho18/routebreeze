import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/data/round_trip_preference.dart';
import 'package:routebreeze/features/addresses/presentation/address_form_cubit.dart';
import 'package:routebreeze/features/location/data/geolocator_location_service.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/presentation/lock_cubit.dart';
import 'package:routebreeze/features/navigation/data/background_tracker.dart';
import 'package:routebreeze/features/navigation/data/customer_notifier.dart';
import 'package:routebreeze/features/navigation/data/navigation_app_launcher.dart';
import 'package:routebreeze/features/navigation/data/notification_permission.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/route/data/route_storage.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/presentation/route_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_notifications.dart';

void main() {
  late FakeLocalNotifications notifications;

  setUp(() {
    // The address form loads the round-trip choice when it is created.
    SharedPreferences.setMockInitialValues({});
    notifications = FakeLocalNotifications.install();
  });
  tearDown(resetDependencies);

  test(
    'configureDependencies registers Dio, ConnectivityService, '
    'LocalAuthService, LocationService and the app-level LockCubit',
    () async {
      await configureDependencies(apiKey: 'test-key');

      expect(getIt.isRegistered<Dio>(), isTrue);
      expect(getIt.isRegistered<ConnectivityService>(), isTrue);
      expect(getIt<Dio>().options.headers['X-Goog-Api-Key'], 'test-key');
      expect(getIt<ConnectivityService>(), isA<ConnectivityServiceImpl>());
      expect(getIt<LocalAuthService>(), isA<LocalAuthServiceImpl>());
      expect(getIt<LocationService>(), isA<GeolocatorLocationService>());
      expect(getIt<PlacesApi>(), isA<PlacesApiImpl>());
      expect(getIt<RoundTripPreference>(), isA<RoundTripPreferenceImpl>());
      expect(getIt<RoutesApi>(), isA<RoutesApiImpl>());
      expect(getIt<RouteStorage>(), isA<RouteStorageImpl>());
      expect(getIt<NavigationAppLauncher>(), isA<UrlNavigationAppLauncher>());
      expect(getIt<CustomerNotifier>(), isA<SharePlusCustomerNotifier>());
      expect(
        getIt<NotificationPermission>(),
        isA<PluginNotificationPermission>(),
      );
      expect(getIt<RouteRepository>(), isA<RouteRepository>());
      expect(
        identical(getIt<RouteRepository>(), getIt<RouteRepository>()),
        isTrue,
      );
      expect(getIt<MapCubit>().state, const MapState());
      expect(identical(getIt<MapCubit>(), getIt<MapCubit>()), isFalse);
      const bias = GeoPoint(-23.5, -46.6);
      expect(getIt<AddressFormCubit>(param1: bias).bias, bias);
      expect(getIt<AddressFormCubit>(param1: bias).state.fields, hasLength(3));
      expect(getIt<RouteCubit>().state, const RouteState());
      expect(identical(getIt<RouteCubit>(), getIt<RouteCubit>()), isFalse);
      final plan = RoutePlan(
        origin: bias,
        stops: const [],
        polyline: const [],
        distanceMeters: 0,
        durationSeconds: 0,
        legs: const [],
        computedAt: DateTime.utc(2026, 9, 22),
      );
      expect(getIt<NavigationCubit>(param1: plan).state.plan, plan);
      expect(
        identical(
          getIt<NavigationCubit>(param1: plan),
          getIt<NavigationCubit>(param1: plan),
        ),
        isFalse,
      );
      expect(getIt<LockCubit>().state, const LockState());
      expect(identical(getIt<LockCubit>(), getIt<LockCubit>()), isTrue);
      expect(getIt<SessionState>().isNavigationActive, isFalse);
      expect(identical(getIt<SessionState>(), getIt<SessionState>()), isTrue);
    },
  );

  test('resetDependencies clears every registration', () async {
    await configureDependencies(apiKey: 'test-key');

    await resetDependencies();

    expect(getIt.isRegistered<Dio>(), isFalse);
    expect(getIt.isRegistered<ConnectivityService>(), isFalse);
    expect(getIt.isRegistered<LocalAuthService>(), isFalse);
    expect(getIt.isRegistered<LocationService>(), isFalse);
    expect(getIt.isRegistered<PlacesApi>(), isFalse);
    expect(getIt.isRegistered<RoundTripPreference>(), isFalse);
    expect(getIt.isRegistered<RoutesApi>(), isFalse);
    expect(getIt.isRegistered<RouteStorage>(), isFalse);
    expect(getIt.isRegistered<RouteRepository>(), isFalse);
    expect(getIt.isRegistered<RouteCubit>(), isFalse);
    expect(getIt.isRegistered<MapCubit>(), isFalse);
    expect(getIt.isRegistered<AddressFormCubit>(), isFalse);
    expect(getIt.isRegistered<LockCubit>(), isFalse);
    expect(getIt.isRegistered<SessionState>(), isFalse);
  });

  group('local notifications', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'on Android, the foreground service keeps tracking in background, '
      'and the plugin starts once with the notification small icon',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await configureDependencies(apiKey: 'test-key');

        expect(getIt<BackgroundTracker>(), isA<ForegroundServiceTracker>());
        expect(notifications.calls.single.method, 'initialize');
        expect(notifications.calls.single.arguments, {
          'defaultIcon': 'ic_stat_routebreeze',
        });
      },
    );

    test('on iOS, no service to start, and the plugin starts once without '
        'asking for any notification permission', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      notifications = FakeLocalNotifications.install();

      await configureDependencies(apiKey: 'test-key');

      expect(getIt<BackgroundTracker>(), isA<NoopBackgroundTracker>());
      expect(notifications.calls.single.method, 'initialize');
      final arguments =
          notifications.calls.single.arguments as Map<Object?, Object?>;
      expect(
        {
          for (final MapEntry(:key, :value) in arguments.entries)
            if ((key! as String).startsWith('request')) key: value,
        },
        {
          'requestAlertPermission': false,
          'requestSoundPermission': false,
          'requestBadgePermission': false,
          'requestProvisionalPermission': false,
          'requestCriticalPermission': false,
          'requestProvidesAppNotificationSettings': false,
        },
      );
    });

    test('a plugin that fails to initialize does not stop the app: the '
        'tracker still resolves, and its start swallows the failing '
        'channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      notifications = FakeLocalNotifications.install(
        error: PlatformException(code: 'invalid_icon'),
      );

      await expectLater(configureDependencies(apiKey: 'test-key'), completes);

      final tracker = getIt<BackgroundTracker>();
      expect(tracker, isA<ForegroundServiceTracker>());
      await expectLater(tracker.start(), completes);
      expect(
        [for (final call in notifications.calls) call.method],
        ['initialize', 'startForegroundService'],
      );
    });
  });
}

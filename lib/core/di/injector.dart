import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/addresses/data/places_api.dart';
import '../../features/addresses/data/round_trip_preference.dart';
import '../../features/addresses/presentation/address_form_cubit.dart';
import '../../features/location/data/geolocator_location_service.dart';
import '../../features/location/domain/location_service.dart';
import '../../features/location/presentation/map_cubit.dart';
import '../../features/lock/data/local_auth_service.dart';
import '../../features/lock/presentation/lock_cubit.dart';
import '../../features/navigation/data/background_tracker.dart';
import '../../features/navigation/data/customer_notifier.dart';
import '../../features/navigation/data/navigation_app_launcher.dart';
import '../../features/navigation/data/notification_permission.dart';
import '../../features/navigation/data/route_alerts.dart';
import '../../features/navigation/presentation/navigation_cubit.dart';
import '../../features/route/data/route_storage.dart';
import '../../features/route/data/routes_api.dart';
import '../../features/route/domain/route_plan.dart';
import '../../features/route/domain/route_repository.dart';
import '../../features/route/presentation/route_cubit.dart';
import '../config/env.dart';
import '../geo/geo_point.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../session/session_state.dart';

final GetIt getIt = GetIt.instance;

/// Composition root; [apiKey] overrides `Env.googleMapsApiKey` in tests.
Future<void> configureDependencies({String? apiKey}) async {
  getIt
    ..registerLazySingleton<Dio>(
      () => buildGoogleDio(apiKey: apiKey ?? Env.googleMapsApiKey),
    )
    ..registerLazySingleton<ConnectivityService>(
      () => ConnectivityServiceImpl(Connectivity()),
    )
    ..registerLazySingleton<LocalAuthService>(
      () => LocalAuthServiceImpl(LocalAuthentication()),
    )
    ..registerLazySingleton<LocationService>(GeolocatorLocationService.new)
    ..registerLazySingleton<PlacesApi>(() => PlacesApiImpl(getIt<Dio>()))
    ..registerLazySingleton<RoundTripPreference>(RoundTripPreferenceImpl.new)
    ..registerLazySingleton<RoutesApi>(() => RoutesApiImpl(getIt<Dio>()))
    ..registerLazySingleton<RouteStorage>(RouteStorageImpl.new)
    ..registerLazySingleton<RouteRepository>(
      () => RouteRepository(getIt<RoutesApi>(), getIt<RouteStorage>()),
    )
    ..registerLazySingleton<NavigationAppLauncher>(UrlNavigationAppLauncher.new)
    ..registerLazySingleton<CustomerNotifier>(SharePlusCustomerNotifier.new)
    ..registerSingleton<FlutterLocalNotificationsPlugin>(
      FlutterLocalNotificationsPlugin(),
    )
    ..registerLazySingleton<BackgroundTracker>(
      () => defaultTargetPlatform == TargetPlatform.android
          ? ForegroundServiceTracker(getIt<FlutterLocalNotificationsPlugin>())
          : NoopBackgroundTracker(),
    )
    ..registerLazySingleton<NotificationPermission>(
      () => PluginNotificationPermission(
        getIt<FlutterLocalNotificationsPlugin>(),
      ),
    )
    ..registerLazySingleton<RouteAlerts>(
      () => PluginRouteAlerts(getIt<FlutterLocalNotificationsPlugin>()),
    )
    ..registerFactory<MapCubit>(
      () =>
          MapCubit(getIt<LocationService>(), routes: getIt<RouteRepository>()),
    )
    ..registerFactoryParam<AddressFormCubit, GeoPoint, void>(
      (bias, _) => AddressFormCubit(
        getIt<PlacesApi>(),
        bias: bias,
        preference: getIt<RoundTripPreference>(),
      ),
    )
    ..registerFactory<RouteCubit>(() => RouteCubit(getIt<RouteRepository>()))
    ..registerFactoryParam<NavigationCubit, RoutePlan, void>(
      (plan, _) => NavigationCubit(
        plan: plan,
        location: getIt<LocationService>(),
        routes: getIt<RouteRepository>(),
        connectivity: getIt<ConnectivityService>(),
        session: getIt<SessionState>(),
        tracker: getIt<BackgroundTracker>(),
      ),
    )
    ..registerLazySingleton<LockCubit>(
      () => LockCubit(getIt<LocalAuthService>()),
    )
    ..registerLazySingleton<SessionState>(SessionState.new);
  // Once, before any use; the iOS permission is asked later, not here.
  try {
    await getIt<FlutterLocalNotificationsPlugin>().initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_routebreeze'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  } on PlatformException {
    // The app opens and navigates without the ongoing notification.
  }
}

Future<void> resetDependencies() => getIt.reset();

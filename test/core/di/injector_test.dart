import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/presentation/address_form_cubit.dart';
import 'package:routebreeze/features/location/data/geolocator_location_service.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/presentation/lock_cubit.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';

void main() {
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
      expect(getIt<RoutesApi>(), isA<RoutesApiImpl>());
      expect(getIt<MapCubit>().state, const MapState());
      expect(identical(getIt<MapCubit>(), getIt<MapCubit>()), isFalse);
      const bias = GeoPoint(-23.5, -46.6);
      expect(getIt<AddressFormCubit>(param1: bias).bias, bias);
      expect(getIt<AddressFormCubit>(param1: bias).state.fields, hasLength(3));
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
    expect(getIt.isRegistered<RoutesApi>(), isFalse);
    expect(getIt.isRegistered<MapCubit>(), isFalse);
    expect(getIt.isRegistered<AddressFormCubit>(), isFalse);
    expect(getIt.isRegistered<LockCubit>(), isFalse);
    expect(getIt.isRegistered<SessionState>(), isFalse);
  });
}

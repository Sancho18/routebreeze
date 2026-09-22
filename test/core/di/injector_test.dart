import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';

void main() {
  tearDown(resetDependencies);

  test('configureDependencies registers Dio, ConnectivityService and '
      'LocalAuthService', () async {
    await configureDependencies(apiKey: 'test-key');

    expect(getIt.isRegistered<Dio>(), isTrue);
    expect(getIt.isRegistered<ConnectivityService>(), isTrue);
    expect(getIt<Dio>().options.headers['X-Goog-Api-Key'], 'test-key');
    expect(getIt<ConnectivityService>(), isA<ConnectivityServiceImpl>());
    expect(getIt<LocalAuthService>(), isA<LocalAuthServiceImpl>());
  });

  test('resetDependencies clears every registration', () async {
    await configureDependencies(apiKey: 'test-key');

    await resetDependencies();

    expect(getIt.isRegistered<Dio>(), isFalse);
    expect(getIt.isRegistered<ConnectivityService>(), isFalse);
    expect(getIt.isRegistered<LocalAuthService>(), isFalse);
  });
}

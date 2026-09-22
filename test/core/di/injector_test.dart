import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';

void main() {
  tearDown(resetDependencies);

  test('configureDependencies registers Dio and ConnectivityService', () async {
    await configureDependencies(apiKey: 'test-key');

    expect(getIt.isRegistered<Dio>(), isTrue);
    expect(getIt.isRegistered<ConnectivityService>(), isTrue);
    expect(getIt<Dio>().options.headers['X-Goog-Api-Key'], 'test-key');
    expect(getIt<ConnectivityService>(), isA<ConnectivityServiceImpl>());
  });

  test('resetDependencies clears every registration', () async {
    await configureDependencies(apiKey: 'test-key');

    await resetDependencies();

    expect(getIt.isRegistered<Dio>(), isFalse);
    expect(getIt.isRegistered<ConnectivityService>(), isFalse);
  });
}

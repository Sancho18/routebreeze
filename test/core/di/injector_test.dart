import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/presentation/lock_cubit.dart';

void main() {
  tearDown(resetDependencies);

  test('configureDependencies registers Dio, ConnectivityService, '
      'LocalAuthService and the app-level LockCubit', () async {
    await configureDependencies(apiKey: 'test-key');

    expect(getIt.isRegistered<Dio>(), isTrue);
    expect(getIt.isRegistered<ConnectivityService>(), isTrue);
    expect(getIt<Dio>().options.headers['X-Goog-Api-Key'], 'test-key');
    expect(getIt<ConnectivityService>(), isA<ConnectivityServiceImpl>());
    expect(getIt<LocalAuthService>(), isA<LocalAuthServiceImpl>());
    expect(getIt<LockCubit>().state, const LockState());
    expect(identical(getIt<LockCubit>(), getIt<LockCubit>()), isTrue);
    expect(getIt<SessionState>().isNavigationActive, isFalse);
    expect(identical(getIt<SessionState>(), getIt<SessionState>()), isTrue);
  });

  test('resetDependencies clears every registration', () async {
    await configureDependencies(apiKey: 'test-key');

    await resetDependencies();

    expect(getIt.isRegistered<Dio>(), isFalse);
    expect(getIt.isRegistered<ConnectivityService>(), isFalse);
    expect(getIt.isRegistered<LocalAuthService>(), isFalse);
    expect(getIt.isRegistered<LockCubit>(), isFalse);
    expect(getIt.isRegistered<SessionState>(), isFalse);
  });
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../config/env.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';

final GetIt getIt = GetIt.instance;

/// Composition root. Each feature task registers its own types here.
///
/// [apiKey] overrides `Env.googleMapsApiKey` (tests).
Future<void> configureDependencies({String? apiKey}) async {
  getIt
    ..registerLazySingleton<Dio>(
      () => buildGoogleDio(apiKey: apiKey ?? Env.googleMapsApiKey),
    )
    ..registerLazySingleton<ConnectivityService>(
      () => ConnectivityServiceImpl(Connectivity()),
    );
}

Future<void> resetDependencies() => getIt.reset();

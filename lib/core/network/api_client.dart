import 'dart:io';

import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Connect and receive timeout for Google web services.
const Duration apiTimeout = Duration(seconds: 10);

/// Delay before the single retry on a connection error (OFFL-06).
const Duration retryDelay = Duration(seconds: 2);

/// A [Dio] configured for Google web services: API key header, JSON
/// content type, 10 s timeouts and one retry after 2 s on connection errors.
///
/// [adapter] replaces the HTTP transport (tests).
Dio buildGoogleDio({required String apiKey, HttpClientAdapter? adapter}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: apiTimeout,
      receiveTimeout: apiTimeout,
      contentType: Headers.jsonContentType,
      headers: {'X-Goog-Api-Key': apiKey},
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(RetryOnConnectionErrorInterceptor(dio));
  return dio;
}

/// Retries a request exactly once, after [retryDelay], when it failed with
/// [DioExceptionType.connectionError]. Any other failure passes through.
class RetryOnConnectionErrorInterceptor extends Interceptor {
  RetryOnConnectionErrorInterceptor(this._dio);

  final Dio _dio;

  static const _retriedKey = 'rb.retried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.type != DioExceptionType.connectionError ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    options.extra[_retriedKey] = true;
    await Future<void>.delayed(retryDelay);
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

/// Maps a [DioException] to the app's [Failure] vocabulary.
Failure mapDioError(DioException error) => switch (error.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout => const TimeoutFailure(),
  DioExceptionType.connectionError => const NoConnection(),
  DioExceptionType.badResponse => ApiFailure(
    error.response?.statusCode,
    _responseMessage(error.response),
  ),
  _ when error.error is SocketException => const NoConnection(),
  _ => Unknown(error.error ?? error),
};

/// Google APIs answer errors as `{"error": {"message": ...}}`.
String _responseMessage(Response<dynamic>? response) {
  final data = response?.data;
  if (data is Map) {
    final error = data['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
  }
  if (data is String && data.isNotEmpty) return data;
  return 'HTTP ${response?.statusCode}';
}

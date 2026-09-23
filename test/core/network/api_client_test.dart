import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/network/api_client.dart';

/// Transport stub: answers each call with the next scripted result and
/// records every request with its timestamp.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.script);

  final List<Object Function(RequestOptions options)> script;
  final requests = <RequestOptions>[];
  final calledAt = <DateTime>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    calledAt.add(DateTime.now());
    final step = script.length == 1
        ? script.single
        : script[requests.length - 1];
    final result = step(options);
    if (result is ResponseBody) return result;
    throw result;
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(String body, [int status = 200]) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

DioException connectionError(RequestOptions o) =>
    DioException.connectionError(requestOptions: o, reason: 'refused');

void main() {
  const url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

  Future<Failure> failureOf(Future<Response<dynamic>> request) async {
    try {
      await request;
    } on DioException catch (e) {
      return mapDioError(e);
    }
    fail('expected a DioException');
  }

  group('buildGoogleDio', () {
    test(
      'sends the API key header, JSON content type and 10 s timeouts',
      () async {
        final adapter = FakeAdapter([(_) => json('{"ok":true}')]);
        final dio = buildGoogleDio(apiKey: 'test-key', adapter: adapter);

        final response = await dio.post<Map<String, dynamic>>(url, data: {});

        expect(response.data, {'ok': true});
        final sent = adapter.requests.single;
        expect(sent.headers['X-Goog-Api-Key'], 'test-key');
        expect(sent.headers[Headers.contentTypeHeader], 'application/json');
        expect(sent.connectTimeout, const Duration(seconds: 10));
        expect(sent.receiveTimeout, const Duration(seconds: 10));
      },
    );

    test(
      'retries once after 2 s on a connection error, then succeeds',
      () async {
        final adapter = FakeAdapter([
          (o) => connectionError(o),
          (_) => json('{"ok":true}'),
        ]);
        final dio = buildGoogleDio(apiKey: 'k', adapter: adapter);

        final response = await dio.get<Map<String, dynamic>>(url);

        expect(response.data, {'ok': true});
        expect(adapter.requests, hasLength(2));
        final gap = adapter.calledAt[1].difference(adapter.calledAt[0]);
        expect(gap, greaterThanOrEqualTo(const Duration(seconds: 2)));
        expect(gap, lessThan(const Duration(seconds: 3)));
      },
    );

    test(
      'retries once on a connection error, then reports NoConnection',
      () async {
        final adapter = FakeAdapter([(o) => connectionError(o)]);
        final dio = buildGoogleDio(apiKey: 'k', adapter: adapter);

        expect(await failureOf(dio.get<dynamic>(url)), const NoConnection());
        expect(adapter.requests, hasLength(2));
      },
    );

    test('a non-JSON error body becomes the ApiFailure message; an empty body '
        'falls back to the HTTP status', () async {
      final adapter = FakeAdapter([
        (_) => ResponseBody.fromString('Bad Gateway', 502),
        (_) => ResponseBody.fromString('', 503),
      ]);
      final dio = buildGoogleDio(apiKey: 'k', adapter: adapter);

      expect(
        await failureOf(dio.get<dynamic>(url)),
        const ApiFailure(502, 'Bad Gateway'),
      );
      expect(
        await failureOf(dio.get<dynamic>(url)),
        const ApiFailure(503, 'HTTP 503'),
      );
    });

    test(
      '4xx maps to ApiFailure with the API message and is not retried',
      () async {
        final adapter = FakeAdapter([
          (_) =>
              json('{"error":{"code":403,"message":"API key not valid"}}', 403),
        ]);
        final dio = buildGoogleDio(apiKey: 'k', adapter: adapter);

        expect(
          await failureOf(dio.get<dynamic>(url)),
          const ApiFailure(403, 'API key not valid'),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test('timeout maps to TimeoutFailure and is not retried', () async {
      final adapter = FakeAdapter([
        (o) => DioException.connectionTimeout(
          timeout: apiTimeout,
          requestOptions: o,
        ),
      ]);
      final dio = buildGoogleDio(apiKey: 'k', adapter: adapter);

      expect(await failureOf(dio.get<dynamic>(url)), const TimeoutFailure());
      expect(adapter.requests, hasLength(1));
    });
  });

  group('mapDioError', () {
    final options = RequestOptions(path: url);

    test('send and receive timeouts map to TimeoutFailure', () {
      for (final type in [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          mapDioError(DioException(requestOptions: options, type: type)),
          const TimeoutFailure(),
        );
      }
    });

    test('SocketException under an unknown type maps to NoConnection', () {
      expect(
        mapDioError(
          DioException(
            requestOptions: options,
            error: const SocketException('unreachable'),
          ),
        ),
        const NoConnection(),
      );
    });

    test('any other error maps to Unknown carrying the cause type', () {
      final cause = StateError('boom');
      expect(
        mapDioError(DioException(requestOptions: options, error: cause)),
        const Unknown('StateError'),
      );
    });

    test('Unknown never retains the exception, whose request options carry '
        'the API key header', () {
      final error = DioException(
        requestOptions: RequestOptions(
          path: url,
          headers: {'X-Goog-Api-Key': 'test-key'},
        ),
        type: DioExceptionType.unknown,
      );

      final failure = mapDioError(error);

      expect(failure, const Unknown('DioException'));
      expect(failure.props.whereType<DioException>(), isEmpty);
      expect('${failure.props}', isNot(contains('test-key')));
      expect(failure.toString(), isNot(contains('test-key')));
    });
  });
}

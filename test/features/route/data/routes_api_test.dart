import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/api_client.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_planner.dart';

/// Transport stub: answers every call with [body]/[status] and records the
/// request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.body, [this.status = 200]);

  final String body;
  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  const c = Stop('pc', 'Rua C, 3', GeoPoint(-23.70, -46.80));
  const request = RouteRequest(
    origin: origin,
    intermediates: [a, b],
    destination: c,
  );
  const invalid = ApiFailure(null, 'Resposta inválida da Routes API');

  late FakeAdapter adapter;

  RoutesApi api(String body, [int status = 200]) {
    adapter = FakeAdapter(body, status);
    return RoutesApiImpl(buildGoogleDio(apiKey: 'test-key', adapter: adapter));
  }

  const fixture =
      '{"routes":[{"distanceMeters":12345,"duration":"605s",'
      '"polyline":{"encodedPolyline":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"},'
      '"legs":[{"distanceMeters":4000,"duration":"200s"},'
      '{"distanceMeters":4345,"duration":"205s"},'
      '{"distanceMeters":4000,"duration":"200s"}],'
      '"optimizedIntermediateWaypointIndex":[1,0]}]}';

  group('computeRoutes request (ROUTE-01)', () {
    test('POSTs origin, farthest destination, intermediates, '
        'optimizeWaypointOrder, DRIVE, pt-BR, br, METRIC with the field '
        'mask limited to polyline, legs and the optimized index', () async {
      await api(fixture).computeRoutes(request);

      final sent = adapter.requests.single;
      expect(sent.method, 'POST');
      expect(
        sent.uri.toString(),
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );
      expect(sent.headers['X-Goog-Api-Key'], 'test-key');
      expect(sent.headers[Headers.contentTypeHeader], 'application/json');
      expect(
        sent.headers['X-Goog-FieldMask'],
        'routes.duration,routes.distanceMeters,'
        'routes.polyline.encodedPolyline,routes.legs.distanceMeters,'
        'routes.legs.duration,routes.optimizedIntermediateWaypointIndex',
      );
      expect(sent.data, {
        'origin': {
          'location': {
            'latLng': {'latitude': -23.5614, 'longitude': -46.6559},
          },
        },
        'destination': {
          'location': {
            'latLng': {'latitude': -23.70, 'longitude': -46.80},
          },
        },
        'intermediates': [
          {
            'location': {
              'latLng': {'latitude': -23.565, 'longitude': -46.66},
            },
          },
          {
            'location': {
              'latLng': {'latitude': -23.60, 'longitude': -46.70},
            },
          },
        ],
        'travelMode': 'DRIVE',
        'optimizeWaypointOrder': true,
        'languageCode': 'pt-BR',
        'regionCode': 'br',
        'units': 'METRIC',
      });
    });

    test(
      'single stop: no intermediates and no optimizeWaypointOrder',
      () async {
        const single = RouteRequest(
          origin: origin,
          intermediates: [],
          destination: a,
        );

        await api(
          '{"routes":[{"distanceMeters":600,"duration":"90s",'
          '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
          '"legs":[{"distanceMeters":600,"duration":"90s"}]}]}',
        ).computeRoutes(single);

        final sent = adapter.requests.single;
        final body = sent.data as Map<String, dynamic>;
        expect(body.containsKey('intermediates'), isFalse);
        expect(body.containsKey('optimizeWaypointOrder'), isFalse);
        expect(body['destination'], {
          'location': {
            'latLng': {'latitude': -23.565, 'longitude': -46.66},
          },
        });
        expect(body['travelMode'], 'DRIVE');
      },
    );
  });

  group('computeRoutes response', () {
    test('parses polyline, totals, "605s" durations, legs and the '
        'optimized index (ROUTE-02)', () async {
      final response = await api(fixture).computeRoutes(request);

      expect(
        response,
        const RouteResponse(
          encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          distanceMeters: 12345,
          durationSeconds: 605,
          legs: [
            RouteLeg(distanceMeters: 4000, durationSeconds: 200),
            RouteLeg(distanceMeters: 4345, durationSeconds: 205),
            RouteLeg(distanceMeters: 4000, durationSeconds: 200),
          ],
          optimizedIndex: [1, 0],
        ),
      );
    });

    test('single stop: optimized index is null', () async {
      const single = RouteRequest(
        origin: origin,
        intermediates: [],
        destination: a,
      );

      final response = await api(
        '{"routes":[{"distanceMeters":600,"duration":"90s",'
        '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
        '"legs":[{"distanceMeters":600,"duration":"90s"}]}]}',
      ).computeRoutes(single);

      expect(response.optimizedIndex, isNull);
      expect(response.legs, const [
        RouteLeg(distanceMeters: 600, durationSeconds: 90),
      ]);
    });

    test('no routes → ApiFailure (ROUTE-06)', () async {
      await expectLater(
        api('{"routes":[]}').computeRoutes(request),
        throwsA(invalid),
      );
      await expectLater(api('{}').computeRoutes(request), throwsA(invalid));
    });

    test('fewer legs than stops → ApiFailure (edge case)', () async {
      final api2 = api(
        '{"routes":[{"distanceMeters":12345,"duration":"605s",'
        '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
        '"legs":[{"distanceMeters":4000,"duration":"200s"},'
        '{"distanceMeters":4345,"duration":"205s"}],'
        '"optimizedIntermediateWaypointIndex":[1,0]}]}',
      );

      await expectLater(api2.computeRoutes(request), throwsA(invalid));
    });

    group('invalid optimized index → ApiFailure (ROUTE-02, edge case)', () {
      String withIndex(String index) =>
          '{"routes":[{"distanceMeters":12345,"duration":"605s",'
          '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
          '"legs":[{"distanceMeters":4000,"duration":"200s"},'
          '{"distanceMeters":4345,"duration":"205s"},'
          '{"distanceMeters":4000,"duration":"200s"}],'
          '"optimizedIntermediateWaypointIndex":$index}]}';

      for (final (label, index) in [
        ('duplicate', '[0,0]'),
        ('out of range', '[0,5]'),
        ('negative', '[-1,0]'),
        ('too short', '[0]'),
        ('too long', '[0,1,2]'),
        ('non-numeric', '["a",1]'),
      ]) {
        test(label, () async {
          await expectLater(
            api(withIndex(index)).computeRoutes(request),
            throwsA(invalid),
          );
        });
      }
    });

    test(
      'a leg that is not an object → ApiFailure (ROUTE-06, edge case)',
      () async {
        await expectLater(
          api(
            '{"routes":[{"distanceMeters":12345,"duration":"605s",'
            '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
            '"legs":[{"distanceMeters":4000,"duration":"200s"},'
            '"leg",'
            '{"distanceMeters":4000,"duration":"200s"}],'
            '"optimizedIntermediateWaypointIndex":[1,0]}]}',
          ).computeRoutes(request),
          throwsA(invalid),
        );
      },
    );

    group('non-numeric totals → ApiFailure (edge case)', () {
      test('duration that is not "<seconds>s"', () async {
        await expectLater(
          api(
            '{"routes":[{"distanceMeters":12345,"duration":"xs",'
            '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
            '"legs":[{"distanceMeters":4000,"duration":"200s"},'
            '{"distanceMeters":4345,"duration":"205s"},'
            '{"distanceMeters":4000,"duration":"200s"}],'
            '"optimizedIntermediateWaypointIndex":[1,0]}]}',
          ).computeRoutes(request),
          throwsA(invalid),
        );
      });

      test('distanceMeters that is not a number', () async {
        await expectLater(
          api(
            '{"routes":[{"distanceMeters":"far","duration":"605s",'
            '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
            '"legs":[{"distanceMeters":4000,"duration":"200s"},'
            '{"distanceMeters":4345,"duration":"205s"},'
            '{"distanceMeters":4000,"duration":"200s"}],'
            '"optimizedIntermediateWaypointIndex":[1,0]}]}',
          ).computeRoutes(request),
          throwsA(invalid),
        );
      });

      test('leg duration that is not "<seconds>s"', () async {
        await expectLater(
          api(
            '{"routes":[{"distanceMeters":12345,"duration":"605s",'
            '"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
            '"legs":[{"distanceMeters":4000,"duration":"Infinitys"},'
            '{"distanceMeters":4345,"duration":"205s"},'
            '{"distanceMeters":4000,"duration":"200s"}],'
            '"optimizedIntermediateWaypointIndex":[1,0]}]}',
          ).computeRoutes(request),
          throwsA(invalid),
        );
      });

      test('absent totals still parse as 0 (proto JSON omits zeros)', () async {
        final response = await api(
          '{"routes":[{"polyline":{"encodedPolyline":"_p~iF~ps|U"},'
          '"legs":[{},{},{}],'
          '"optimizedIntermediateWaypointIndex":[1,0]}]}',
        ).computeRoutes(request);

        expect(response.distanceMeters, 0);
        expect(response.durationSeconds, 0);
        expect(response.legs, const [
          RouteLeg(distanceMeters: 0, durationSeconds: 0),
          RouteLeg(distanceMeters: 0, durationSeconds: 0),
          RouteLeg(distanceMeters: 0, durationSeconds: 0),
        ]);
      });
    });

    test('HTTP error → ApiFailure with the API message (ROUTE-06)', () async {
      final api2 = api(
        '{"error":{"code":400,"message":"Invalid waypoint"}}',
        400,
      );

      await expectLater(
        api2.computeRoutes(request),
        throwsA(const ApiFailure(400, 'Invalid waypoint')),
      );
    });
  });
}

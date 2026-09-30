import 'dart:convert';
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
  const single = RouteRequest(
    origin: origin,
    intermediates: [],
    destination: a,
  );
  const invalid = ApiFailure(null, 'Resposta inválida da Routes API');

  // Google's reference points split into three legs; each leg starts on the
  // vertex where the previous one ended.
  const p0 = GeoPoint(38.5, -120.2);
  const p1 = GeoPoint(40.7, -120.95);
  const p2 = GeoPoint(43.252, -126.453);
  const p3 = GeoPoint(44, -127);
  const leg01 = '_p~iF~ps|U_ulLnnqC';
  const leg12 = '_flwFn`faV_mqNvxq`@';
  const leg23 = '_t~fGfzxbW_bqCvyiB';
  const onlyP1 = '_flwFn`faV';
  const onlyP3 = '_wpkG~tcfW';

  late FakeAdapter adapter;

  RoutesApi api(String body, [int status = 200]) {
    adapter = FakeAdapter(body, status);
    return RoutesApiImpl(buildGoogleDio(apiKey: 'test-key', adapter: adapter));
  }

  /// A leg as the API sends it; a null [polyline] leaves the field out.
  Map<String, Object?> leg(
    Object? distance,
    Object? duration, [
    Object? polyline,
  ]) => {
    'distanceMeters': ?distance,
    'duration': ?duration,
    if (polyline != null) 'polyline': {'encodedPolyline': polyline},
  };

  /// A `computeRoutes` answer with one route.
  String body({
    Object? distance = 12345,
    Object? duration = '605s',
    required List<Object?> legs,
    Object? index = const [1, 0],
  }) => jsonEncode({
    'routes': [
      {
        'distanceMeters': ?distance,
        'duration': ?duration,
        'legs': legs,
        'optimizedIntermediateWaypointIndex': ?index,
      },
    ],
  });

  final fixture = body(
    legs: [
      leg(4000, '200s', leg01),
      leg(4345, '205s', leg12),
      leg(4000, '200s', leg23),
    ],
  );

  group('computeRoutes request', () {
    test(
      'POSTs origin, farthest destination, intermediates, '
      'optimizeWaypointOrder, DRIVE, pt-BR, br, METRIC with the field '
      'mask limited to leg polylines, totals and the optimized index',
      () async {
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
          'routes.legs.polyline.encodedPolyline,routes.legs.distanceMeters,'
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
      },
    );

    test(
      'single stop: no intermediates and no optimizeWaypointOrder',
      () async {
        await api(
          body(
            distance: 600,
            duration: '90s',
            legs: [leg(600, '90s', leg01)],
            index: null,
          ),
        ).computeRoutes(single);

        final sent = adapter.requests.single;
        final body2 = sent.data as Map<String, dynamic>;
        expect(body2.containsKey('intermediates'), isFalse);
        expect(body2.containsKey('optimizeWaypointOrder'), isFalse);
        expect(body2['destination'], {
          'location': {
            'latLng': {'latitude': -23.565, 'longitude': -46.66},
          },
        });
        expect(body2['travelMode'], 'DRIVE');
      },
    );
  });

  group('computeRoutes response', () {
    test('joins the leg polylines keeping each shared vertex once, records '
        'where each leg ends and parses totals, "605s" durations and the '
        'optimized index', () async {
      final response = await api(fixture).computeRoutes(request);

      expect(
        response,
        const RouteResponse(
          polyline: [p0, p1, p2, p3],
          distanceMeters: 12345,
          durationSeconds: 605,
          legs: [
            RouteLeg(distanceMeters: 4000, durationSeconds: 200, endIndex: 1),
            RouteLeg(distanceMeters: 4345, durationSeconds: 205, endIndex: 2),
            RouteLeg(distanceMeters: 4000, durationSeconds: 200, endIndex: 3),
          ],
          optimizedIndex: [1, 0],
        ),
      );
    });

    test('single stop: optimized index is null', () async {
      final response = await api(
        body(
          distance: 600,
          duration: '90s',
          legs: [leg(600, '90s', leg01)],
          index: null,
        ),
      ).computeRoutes(single);

      expect(response.optimizedIndex, isNull);
      expect(response.polyline, const [p0, p1]);
      expect(response.legs, const [
        RouteLeg(distanceMeters: 600, durationSeconds: 90, endIndex: 1),
      ]);
    });

    test('a zero-length leg (a one-point polyline, distance omitted) ends on '
        'the vertex where the previous leg ended', () async {
      final response = await api(
        body(
          legs: [
            leg(4000, '200s', leg01),
            leg(null, '0s', onlyP1),
            leg(4345, '205s', leg12),
          ],
        ),
      ).computeRoutes(request);

      expect(response.polyline, const [p0, p1, p2]);
      expect(response.legs, const [
        RouteLeg(distanceMeters: 4000, durationSeconds: 200, endIndex: 1),
        RouteLeg(distanceMeters: 0, durationSeconds: 0, endIndex: 1),
        RouteLeg(distanceMeters: 4345, durationSeconds: 205, endIndex: 2),
      ]);
    });

    test('a leg without a polyline adds no points', () async {
      final response = await api(
        body(
          legs: [
            leg(4000, '200s', leg01),
            leg(0, '0s'),
            leg(4345, '205s', leg12),
          ],
        ),
      ).computeRoutes(request);

      expect(response.polyline, const [p0, p1, p2]);
      expect(response.legs.map((l) => l.endIndex), [1, 1, 2]);
    });

    test('a leg that does not start on the previous end keeps all its '
        'points', () async {
      final response = await api(
        body(
          legs: [
            leg(4000, '200s', leg01),
            leg(4000, '200s', leg23),
            leg(0, '0s', onlyP3),
          ],
        ),
      ).computeRoutes(request);

      expect(response.polyline, const [p0, p1, p2, p3]);
      expect(response.legs.map((l) => l.endIndex), [1, 3, 3]);
    });

    test('no leg polyline at all → ApiFailure', () async {
      await expectLater(
        api(
          body(legs: [leg(4000, '200s'), leg(4345, '205s'), leg(4000, '200s')]),
        ).computeRoutes(request),
        throwsA(invalid),
      );
    });

    test('a leg polyline cut in the middle → ApiFailure', () async {
      await expectLater(
        api(
          body(
            legs: [
              leg(4000, '200s', leg01),
              leg(4345, '205s', '_p~iF'),
              leg(4000, '200s', leg23),
            ],
          ),
        ).computeRoutes(request),
        throwsA(invalid),
      );
    });

    test('a leg polyline that is not a string → ApiFailure', () async {
      await expectLater(
        api(
          body(
            legs: [
              leg(4000, '200s', leg01),
              leg(4345, '205s', 42),
              leg(4000, '200s', leg23),
            ],
          ),
        ).computeRoutes(request),
        throwsA(invalid),
      );
    });

    test('no routes → ApiFailure', () async {
      await expectLater(
        api('{"routes":[]}').computeRoutes(request),
        throwsA(invalid),
      );
      await expectLater(api('{}').computeRoutes(request), throwsA(invalid));
    });

    test('fewer legs than stops → ApiFailure (edge case)', () async {
      final api2 = api(
        body(legs: [leg(4000, '200s', leg01), leg(4345, '205s', leg12)]),
      );

      await expectLater(api2.computeRoutes(request), throwsA(invalid));
    });

    group('invalid optimized index → ApiFailure', () {
      for (final (label, index) in [
        ('duplicate', const [0, 0]),
        ('out of range', const [0, 5]),
        ('negative', const [-1, 0]),
        ('too short', const [0]),
        ('too long', const [0, 1, 2]),
        ('non-numeric', const ['a', 1]),
      ]) {
        test(label, () async {
          await expectLater(
            api(
              body(
                legs: [
                  leg(4000, '200s', leg01),
                  leg(4345, '205s', leg12),
                  leg(4000, '200s', leg23),
                ],
                index: index,
              ),
            ).computeRoutes(request),
            throwsA(invalid),
          );
        });
      }
    });

    test('a leg that is not an object → ApiFailure', () async {
      await expectLater(
        api(
          body(
            legs: [leg(4000, '200s', leg01), 'leg', leg(4000, '200s', leg23)],
          ),
        ).computeRoutes(request),
        throwsA(invalid),
      );
    });

    group('non-numeric totals → ApiFailure (edge case)', () {
      test('duration that is not "<seconds>s"', () async {
        await expectLater(
          api(
            body(
              duration: 'xs',
              legs: [
                leg(4000, '200s', leg01),
                leg(4345, '205s', leg12),
                leg(4000, '200s', leg23),
              ],
            ),
          ).computeRoutes(request),
          throwsA(invalid),
        );
      });

      test('distanceMeters that is not a number', () async {
        await expectLater(
          api(
            body(
              distance: 'far',
              legs: [
                leg(4000, '200s', leg01),
                leg(4345, '205s', leg12),
                leg(4000, '200s', leg23),
              ],
            ),
          ).computeRoutes(request),
          throwsA(invalid),
        );
      });

      test('leg duration that is not "<seconds>s"', () async {
        await expectLater(
          api(
            body(
              legs: [
                leg(4000, 'Infinitys', leg01),
                leg(4345, '205s', leg12),
                leg(4000, '200s', leg23),
              ],
            ),
          ).computeRoutes(request),
          throwsA(invalid),
        );
      });

      test('absent totals still parse as 0 (proto JSON omits zeros)', () async {
        final response = await api(
          body(
            distance: null,
            duration: null,
            legs: [
              leg(null, null, leg01),
              leg(null, null, leg12),
              leg(null, null, leg23),
            ],
          ),
        ).computeRoutes(request);

        expect(response.distanceMeters, 0);
        expect(response.durationSeconds, 0);
        expect(response.legs, const [
          RouteLeg(distanceMeters: 0, durationSeconds: 0, endIndex: 1),
          RouteLeg(distanceMeters: 0, durationSeconds: 0, endIndex: 2),
          RouteLeg(distanceMeters: 0, durationSeconds: 0, endIndex: 3),
        ]);
      });
    });

    test('HTTP error → ApiFailure with the API message', () async {
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

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/domain/route_planner.dart';

void main() {
  const planner = RoutePlanner();
  // Distances from origin: near ≈ 0.6 km, mid ≈ 6 km, far ≈ 20 km.
  const origin = GeoPoint(-23.5614, -46.6559);
  const near = Stop('near', 'Rua Perto, 1', GeoPoint(-23.565, -46.66));
  const mid = Stop('mid', 'Rua Meio, 2', GeoPoint(-23.60, -46.70));
  const far = Stop('far', 'Rua Longe, 3', GeoPoint(-23.70, -46.80));

  group('buildRequest', () {
    test('3 stops: the farthest becomes the destination, the others are '
        'intermediates in input order', () {
      final request = planner.buildRequest(origin, const [mid, far, near]);

      expect(
        request,
        const RouteRequest(
          origin: origin,
          intermediates: [mid, near],
          destination: far,
        ),
      );
    });

    test('1 stop: it is the destination and there are no intermediates', () {
      final request = planner.buildRequest(origin, const [near]);

      expect(request.destination, near);
      expect(request.intermediates, isEmpty);
    });

    test('5 stops: one request with 4 intermediates and the farthest '
        'destination (generalizes beyond 3)', () {
      const s4 = Stop('s4', 'Rua 4', GeoPoint(-23.58, -46.64));
      const s5 = Stop('s5', 'Rua 5', GeoPoint(-23.55, -46.70));

      final request = planner.buildRequest(origin, const [
        near,
        s4,
        far,
        mid,
        s5,
      ]);

      expect(request.destination, far);
      expect(request.intermediates, const [near, s4, mid, s5]);
    });

    test('recalculation from a new origin applies the same farthest rule '
        'to the unvisited stops', () {
      const nearFar = GeoPoint(-23.69, -46.79);

      final request = planner.buildRequest(nearFar, const [mid, near]);

      expect(request.origin, nearFar);
      expect(request.destination, near);
      expect(request.intermediates, const [mid]);
    });

    test('an origin more than 50 km from every stop still builds the request '
        'with all stops (edge case: the Places bias is a hint)', () {
      // ≈ 80 km north of the nearest stop.
      const farOrigin = GeoPoint(-22.85, -46.6559);
      for (final stop in const [near, mid, far]) {
        expect(haversineMeters(farOrigin, stop.point), greaterThan(50000));
      }

      final request = planner.buildRequest(farOrigin, const [mid, far, near]);

      expect(request.origin, farOrigin);
      expect(request.destination, far);
      expect(request.intermediates, const [mid, near]);
    });

    test('no stops → ArgumentError', () {
      expect(
        () => planner.buildRequest(origin, const []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('order', () {
    const request = RouteRequest(
      origin: origin,
      intermediates: [mid, near],
      destination: far,
    );

    test('applies optimizedIntermediateWaypointIndex then the destination, '
        'never the typed order', () {
      expect(planner.order(request, [1, 0]), const [near, mid, far]);
    });

    test('identity index keeps the request order then the destination', () {
      expect(planner.order(request, [0, 1]), const [mid, near, far]);
    });

    test('missing index keeps the input order then the destination', () {
      expect(planner.order(request, null), const [mid, near, far]);
      expect(planner.order(request, const []), const [mid, near, far]);
    });

    test('an index that is not a permutation of the intermediates → '
        'ArgumentError', () {
      for (final index in [
        [0, 0],
        [0, 5],
        [-1, 0],
        [0],
        [0, 1, 2],
      ]) {
        expect(
          () => planner.order(request, index),
          throwsA(isA<ArgumentError>()),
          reason: '$index',
        );
      }
    });

    test('single stop: only the destination', () {
      const single = RouteRequest(
        origin: origin,
        intermediates: [],
        destination: near,
      );

      expect(planner.order(single, null), const [near]);
    });
  });
}

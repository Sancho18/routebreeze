import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.56, -46.65));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.57, -46.66));
  const c = Stop('pc', 'Rua C, 3', GeoPoint(-23.58, -46.67));

  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: b, order: 1, visited: false),
      RouteStop(stop: a, order: 2, visited: false),
      RouteStop(stop: c, order: 3, visited: false),
    ],
    polyline: const [
      origin,
      GeoPoint(-23.565, -46.655),
      GeoPoint(-23.58, -46.67),
    ],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [
      RouteLeg(distanceMeters: 4000, durationSeconds: 200),
      RouteLeg(distanceMeters: 4345, durationSeconds: 205),
      RouteLeg(distanceMeters: 4000, durationSeconds: 200),
    ],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );

  group('RoutePlan JSON (OFFL-03)', () {
    test('round-trips ordered stops, visited flags, polyline and totals', () {
      final visited = plan.markVisited('pb');

      expect(RoutePlan.fromJson(visited.toJson()), visited);
      expect(RoutePlan.fromJson(plan.toJson()), plan);
    });

    test('serializes every persisted field explicitly', () {
      expect(plan.toJson(), {
        'origin': {'lat': -23.5614, 'lng': -46.6559},
        'stops': [
          {'stop': b.toJson(), 'order': 1, 'visited': false},
          {'stop': a.toJson(), 'order': 2, 'visited': false},
          {'stop': c.toJson(), 'order': 3, 'visited': false},
        ],
        'polyline': [
          {'lat': -23.5614, 'lng': -46.6559},
          {'lat': -23.565, 'lng': -46.655},
          {'lat': -23.58, 'lng': -46.67},
        ],
        'distanceMeters': 12345,
        'durationSeconds': 605,
        'legs': [
          {'distanceMeters': 4000, 'durationSeconds': 200},
          {'distanceMeters': 4345, 'durationSeconds': 205},
          {'distanceMeters': 4000, 'durationSeconds': 200},
        ],
        'computedAt': '2026-09-22T10:30:00.000Z',
      });
    });
  });

  group('RoutePlan progress (ROUTE-02, NAV-04)', () {
    test('unvisited keeps the optimized order and skips visited stops', () {
      expect(plan.unvisited.map((s) => s.stop.placeId), ['pb', 'pa', 'pc']);
      expect(plan.unvisited.map((s) => s.order), [1, 2, 3]);

      final afterFirst = plan.markVisited('pb');

      expect(afterFirst.unvisited.map((s) => s.stop.placeId), ['pa', 'pc']);
      expect(afterFirst.unvisited.map((s) => s.order), [2, 3]);
    });

    test('nextStop is the first unvisited stop, null when complete', () {
      expect(plan.nextStop, const RouteStop(stop: b, order: 1, visited: false));
      expect(
        plan.markVisited('pb').nextStop,
        const RouteStop(stop: a, order: 2, visited: false),
      );
      expect(
        plan.markVisited('pb').markVisited('pa').markVisited('pc').nextStop,
        isNull,
      );
    });

    test('isComplete only when every stop is visited', () {
      expect(plan.isComplete, isFalse);
      expect(plan.markVisited('pb').markVisited('pa').isComplete, isFalse);
      expect(
        plan.markVisited('pb').markVisited('pa').markVisited('pc').isComplete,
        isTrue,
      );
    });

    test('markVisited returns a new plan and leaves the original intact', () {
      final visited = plan.markVisited('pa');

      expect(
        visited.stops[1],
        const RouteStop(stop: a, order: 2, visited: true),
      );
      expect(visited.stops[0].visited, isFalse);
      expect(visited.stops[2].visited, isFalse);
      expect(plan.stops.every((s) => !s.visited), isTrue);
      expect(visited.origin, plan.origin);
      expect(visited.polyline, plan.polyline);
      expect(visited.distanceMeters, 12345);
      expect(visited.durationSeconds, 605);
      expect(visited.legs, plan.legs);
      expect(visited.computedAt, plan.computedAt);
    });

    test('markVisited with an unknown placeId changes nothing', () {
      expect(plan.markVisited('nope'), plan);
    });
  });
}

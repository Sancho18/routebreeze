import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.56, -46.65));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.57, -46.66));
  const c = Stop('pc', 'Rua C, 3', GeoPoint(-23.58, -46.67));
  const delivered = StopResult.delivered();
  final startedAt = DateTime.utc(2026, 9, 28, 16, 40);
  final deliveredAt = StopResult.delivered(
    at: DateTime.utc(2026, 9, 28, 16, 50),
  );
  final refused = StopResult.failed(
    FailureReason.refused,
    at: DateTime.utc(2026, 9, 28, 17, 5),
  );

  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: b, order: 1),
      RouteStop(stop: a, order: 2),
      RouteStop(stop: c, order: 3),
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

  group('RoutePlan JSON', () {
    test('round-trips ordered stops, visited flags, polyline and totals', () {
      final visited = plan.record('pb', delivered);

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

    test('writes each result next to the visited flag, the start in UTC and '
        'the distance traveled, and restores them from the saved text', () {
      final progressed = plan
          .record('pb', deliveredAt)
          .record('pa', refused)
          .withStart(startedAt)
          .withTraveled(12430);

      expect(progressed.toJson(), {
        'origin': {'lat': -23.5614, 'lng': -46.6559},
        'stops': [
          {
            'stop': b.toJson(),
            'order': 1,
            'visited': true,
            'result': {
              'outcome': 'delivered',
              'at': '2026-09-28T16:50:00.000Z',
            },
          },
          {
            'stop': a.toJson(),
            'order': 2,
            'visited': true,
            'result': {
              'outcome': 'failed',
              'reason': 'refused',
              'at': '2026-09-28T17:05:00.000Z',
            },
          },
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
        'startedAt': '2026-09-28T16:40:00.000Z',
        'traveledMeters': 12430,
      });
      expect(
        plan.withStart(startedAt.toLocal()).toJson()['startedAt'],
        '2026-09-28T16:40:00.000Z',
      );

      final restored = RoutePlan.fromJson(
        jsonDecode(jsonEncode(progressed.toJson())) as Map<String, dynamic>,
      );
      expect(restored, progressed);
      expect(restored.stops[0].result, deliveredAt);
      expect(restored.stops[1].result, refused);
      expect(restored.stops[2].result, isNull);
      expect(restored.startedAt, startedAt);
      expect(restored.traveledMeters, 12430);
    });

    test('a route saved before results (visited flags only) reads a visited '
        'stop as delivered without a time, with no start and no distance, '
        'and keeps writing the visited flag', () {
      final legacy = RoutePlan.fromJson({
        ...plan.toJson(),
        'stops': [
          {'stop': b.toJson(), 'order': 1, 'visited': true},
          {'stop': a.toJson(), 'order': 2, 'visited': false},
          {'stop': c.toJson(), 'order': 3, 'visited': false},
        ],
      });

      expect(legacy.stops[0].result, const StopResult.delivered());
      expect(legacy.stops[0].result!.at, isNull);
      expect(legacy.stops[0].visited, isTrue);
      expect(legacy.stops[1].result, isNull);
      expect(legacy.stops[2].result, isNull);
      expect(legacy.nextStop, const RouteStop(stop: a, order: 2));
      expect(legacy.startedAt, isNull);
      expect(legacy.traveledMeters, 0);
      expect(legacy.toJson()['stops'], [
        {
          'stop': b.toJson(),
          'order': 1,
          'visited': true,
          'result': {'outcome': 'delivered'},
        },
        {'stop': a.toJson(), 'order': 2, 'visited': false},
        {'stop': c.toJson(), 'order': 3, 'visited': false},
      ]);
    });
  });

  group('RouteLeg JSON', () {
    test('keeps where the leg ends on the polyline', () {
      const leg = RouteLeg(
        distanceMeters: 4000,
        durationSeconds: 200,
        endIndex: 12,
      );

      expect(leg.toJson(), {
        'distanceMeters': 4000,
        'durationSeconds': 200,
        'endIndex': 12,
      });
      expect(RouteLeg.fromJson(leg.toJson()), leg);
    });

    test('a leg saved without its end (app 0.1.0) reads back with none and '
        'is written back the same way', () {
      final leg = RouteLeg.fromJson(const {
        'distanceMeters': 600,
        'durationSeconds': 60,
      });

      expect(leg.endIndex, isNull);
      expect(leg.toJson(), {'distanceMeters': 600, 'durationSeconds': 60});
    });
  });

  group('RoutePlan progress', () {
    test('unvisited keeps the optimized order and skips visited stops', () {
      expect(plan.unvisited.map((s) => s.stop.placeId), ['pb', 'pa', 'pc']);
      expect(plan.unvisited.map((s) => s.order), [1, 2, 3]);

      final afterFirst = plan.record('pb', delivered);

      expect(afterFirst.unvisited.map((s) => s.stop.placeId), ['pa', 'pc']);
      expect(afterFirst.unvisited.map((s) => s.order), [2, 3]);
    });

    test('nextStop is the first unvisited stop, null when complete', () {
      expect(plan.nextStop, const RouteStop(stop: b, order: 1));
      expect(
        plan.record('pb', delivered).nextStop,
        const RouteStop(stop: a, order: 2),
      );
      expect(
        plan
            .record('pb', delivered)
            .record('pa', delivered)
            .record('pc', delivered)
            .nextStop,
        isNull,
      );
    });

    test('isComplete only when every stop is visited', () {
      expect(plan.isComplete, isFalse);
      expect(
        plan.record('pb', delivered).record('pa', delivered).isComplete,
        isFalse,
      );
      expect(
        plan
            .record('pb', delivered)
            .record('pa', delivered)
            .record('pc', delivered)
            .isComplete,
        isTrue,
      );
    });

    test('record returns a new plan and leaves the original intact', () {
      final visited = plan.record('pa', delivered);

      expect(
        visited.stops[1],
        const RouteStop(stop: a, order: 2, result: delivered),
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

    test('record with an unknown placeId changes nothing', () {
      expect(plan.record('nope', delivered), plan);
    });

    test('record sets the result of one stop: a stop not delivered is '
        'visited too and the next stop moves on', () {
      final recorded = plan.record('pb', refused);

      expect(recorded.stops, [
        RouteStop(stop: b, order: 1, result: refused),
        const RouteStop(stop: a, order: 2),
        const RouteStop(stop: c, order: 3),
      ]);
      expect(recorded.stops[0].visited, isTrue);
      expect(recorded.nextStop, const RouteStop(stop: a, order: 2));
      expect(
        recorded.record('pa', deliveredAt).record('pc', refused).isComplete,
        isTrue,
      );
    });

    test('record ignores a stop that already has a result', () {
      final first = plan.record('pb', deliveredAt);

      final again = first.record('pb', refused);

      expect(again, first);
      expect(again.stops[0].result, deliveredAt);
      expect(again.nextStop, const RouteStop(stop: a, order: 2));
    });
  });

  group('RoutePlan start and distance', () {
    test('withStart stamps the first start and keeps it on a later one', () {
      final started = plan.withStart(startedAt);

      expect(started.startedAt, startedAt);
      expect(
        started.withStart(startedAt.add(const Duration(hours: 1))).startedAt,
        startedAt,
      );
      expect(started.stops, plan.stops);
      expect(started.polyline, plan.polyline);
      expect(started.computedAt, plan.computedAt);
      expect(plan.startedAt, isNull);
    });

    test('withTraveled replaces the distance traveled and keeps the rest', () {
      final traveled = plan.withStart(startedAt).withTraveled(850);

      expect(traveled.traveledMeters, 850);
      expect(traveled.withTraveled(12430).traveledMeters, 12430);
      expect(traveled.startedAt, startedAt);
      expect(traveled.stops, plan.stops);
      expect(plan.traveledMeters, 0);
    });

    test('withProgressFrom takes the results by place id, the start and the '
        'distance of the previous plan and keeps its own route', () {
      final previous = plan
          .record('pb', deliveredAt)
          .record('pa', refused)
          .withStart(startedAt)
          .withTraveled(12430);
      // A recalculation answer: its own order, line and totals, no progress.
      final recalculated = RoutePlan(
        origin: const GeoPoint(-23.575, -46.665),
        stops: const [
          RouteStop(stop: c, order: 1),
          RouteStop(stop: a, order: 2),
          RouteStop(stop: b, order: 3),
        ],
        polyline: const [GeoPoint(-23.575, -46.665), GeoPoint(-23.58, -46.67)],
        distanceMeters: 900,
        durationSeconds: 120,
        legs: const [RouteLeg(distanceMeters: 900, durationSeconds: 120)],
        computedAt: DateTime.utc(2026, 9, 28, 17, 6),
      );

      final merged = recalculated.withProgressFrom(previous);

      expect(merged.stops, [
        const RouteStop(stop: c, order: 1),
        RouteStop(stop: a, order: 2, result: refused),
        RouteStop(stop: b, order: 3, result: deliveredAt),
      ]);
      expect(merged.startedAt, startedAt);
      expect(merged.traveledMeters, 12430);
      expect(merged.origin, const GeoPoint(-23.575, -46.665));
      expect(merged.polyline, recalculated.polyline);
      expect(merged.distanceMeters, 900);
      expect(merged.durationSeconds, 120);
      expect(merged.legs, recalculated.legs);
      expect(merged.computedAt, DateTime.utc(2026, 9, 28, 17, 6));
    });
  });
}

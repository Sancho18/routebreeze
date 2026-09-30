import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

void main() {
  // Route along the equator, 0.01° (≈ 1112 m) between stops:
  // origin → A (leg 0, two segments) → B (leg 1) → C (leg 2). Google's leg
  // distances differ from the line lengths on purpose: the estimate scales
  // them by the share of the line still ahead.
  const origin = GeoPoint(0, 0);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(0, 0.01));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(0, 0.02));
  const c = Stop('pc', 'Rua C, 3', GeoPoint(0, 0.03));
  const delivered = StopResult.delivered();
  final at = DateTime.utc(2026, 9, 28, 14);
  double lat(double meters) => meters / earthRadiusMeters * 180 / math.pi;

  RoutePlan planOf(
    List<RouteStop> stops, {
    List<GeoPoint> polyline = const [
      origin,
      GeoPoint(0, 0.005),
      GeoPoint(0, 0.01),
      GeoPoint(0, 0.02),
      GeoPoint(0, 0.03),
    ],
    List<RouteLeg> legs = const [
      RouteLeg(distanceMeters: 1200, durationSeconds: 300, endIndex: 2),
      RouteLeg(distanceMeters: 1500, durationSeconds: 360, endIndex: 3),
      RouteLeg(distanceMeters: 900, durationSeconds: 240, endIndex: 4),
    ],
    GeoPoint? returnTo,
    RouteLeg? returnLeg,
  }) => RoutePlan(
    origin: origin,
    stops: stops,
    polyline: polyline,
    distanceMeters: 3600,
    durationSeconds: 900,
    legs: legs,
    computedAt: at,
    returnTo: returnTo,
    returnLeg: returnLeg,
  );

  // The same stops as a round trip: from C the line comes straight back to
  // the origin over the way out (leg 3).
  RoutePlan roundTripOf(List<RouteStop> stops) => planOf(
    stops,
    polyline: const [
      origin,
      GeoPoint(0, 0.005),
      GeoPoint(0, 0.01),
      GeoPoint(0, 0.02),
      GeoPoint(0, 0.03),
      origin,
    ],
    returnTo: origin,
    returnLeg: const RouteLeg(
      distanceMeters: 3200,
      durationSeconds: 540,
      endIndex: 5,
    ),
  );

  const stopA = RouteStop(stop: a, order: 1);
  const stopB = RouteStop(stop: b, order: 2);
  const stopC = RouteStop(stop: c, order: 3);
  final plan = planOf(const [stopA, stopB, stopC]);

  const estimator = ProgressEstimator();

  group('ProgressEstimator', () {
    test('at the origin: the whole first leg to A and every leg to the end, '
        'arriving at A in 5 min and at the end in 15 min', () {
      final progress = estimator.estimate(plan, origin, at)!;

      expect(
        progress,
        RouteProgress(
          next: stopA,
          toNextMeters: 1200,
          toNextSeconds: 300,
          remainingMeters: 3600,
          remainingSeconds: 900,
          at: at,
        ),
      );
      expect(progress.nextArrival, DateTime.utc(2026, 9, 28, 14, 5));
      expect(progress.finalArrival, DateTime.utc(2026, 9, 28, 14, 15));
    });

    test('a quarter of the way to A leaves 3/4 of the leg: 900 m and '
        '225 s', () {
      final progress = estimator.estimate(plan, const GeoPoint(0, 0.0025), at)!;

      expect(progress.toNextMeters, 900);
      expect(progress.toNextSeconds, 225);
      expect(progress.remainingMeters, 900 + 1500 + 900);
      expect(progress.remainingSeconds, 225 + 360 + 240);
    });

    test('a position 30 m beside the line counts from its projection', () {
      final progress = estimator.estimate(plan, GeoPoint(lat(30), 0.0025), at)!;

      expect(progress.toNextMeters, 900);
      expect(progress.toNextSeconds, 225);
    });

    test('past A while A is still next: nothing left to A (0 m, 0 s)', () {
      final progress = estimator.estimate(plan, const GeoPoint(0, 0.012), at)!;

      expect(progress.next, stopA);
      expect(progress.toNextMeters, 0);
      expect(progress.toNextSeconds, 0);
      expect(progress.remainingMeters, 1500 + 900);
      expect(progress.remainingSeconds, 360 + 240);
      expect(progress.nextArrival, at);
    });

    test('with A visited, B is next over leg 1: the whole leg from A', () {
      final progress = estimator.estimate(
        plan.record('pa', delivered),
        a.point,
        at,
      )!;

      expect(progress.next, stopB);
      expect(progress.toNextMeters, 1500);
      expect(progress.toNextSeconds, 360);
      expect(progress.remainingMeters, 1500 + 900);
      expect(progress.remainingSeconds, 360 + 240);
    });

    test('a position behind the next leg counts that whole leg', () {
      final progress = estimator.estimate(
        plan.record('pa', delivered),
        origin,
        at,
      )!;

      expect(progress.toNextMeters, 1500);
      expect(progress.toNextSeconds, 360);
    });

    test('a recalculated plan (visited stops first, legs only for the new '
        'order) measures the first new leg', () {
      // Recalculated at A: C before B.
      final recalculated = planOf(
        const [
          RouteStop(stop: a, order: 1, result: delivered),
          RouteStop(stop: c, order: 2),
          RouteStop(stop: b, order: 3),
        ],
        polyline: const [
          GeoPoint(0, 0.01),
          GeoPoint(0, 0.03),
          GeoPoint(0, 0.02),
        ],
        legs: const [
          RouteLeg(distanceMeters: 2400, durationSeconds: 500, endIndex: 1),
          RouteLeg(distanceMeters: 1300, durationSeconds: 300, endIndex: 2),
        ],
      );

      final progress = estimator.estimate(recalculated, a.point, at)!;

      expect(progress.next, const RouteStop(stop: c, order: 2));
      expect(progress.toNextMeters, 2400);
      expect(progress.toNextSeconds, 500);
      expect(progress.remainingMeters, 2400 + 1300);
      expect(progress.remainingSeconds, 500 + 300);
    });

    test('legs of visited stops after the last unvisited one are not '
        'left to go', () {
      final progress = estimator.estimate(
        plan.record('pc', delivered),
        origin,
        at,
      )!;

      expect(progress.next, stopA);
      expect(progress.remainingMeters, 1200 + 1500);
      expect(progress.remainingSeconds, 300 + 360);
    });

    test('a zero-length leg (two stops on the same spot) leaves 0 m', () {
      const twin = Stop('pa2', 'Rua A, 1 - fundos', GeoPoint(0, 0.01));
      final withTwin = planOf(
        const [
          RouteStop(stop: a, order: 1, result: delivered),
          RouteStop(stop: twin, order: 2),
          RouteStop(stop: b, order: 3),
        ],
        legs: const [
          RouteLeg(distanceMeters: 1200, durationSeconds: 300, endIndex: 2),
          RouteLeg(distanceMeters: 0, durationSeconds: 0, endIndex: 2),
          RouteLeg(distanceMeters: 1500, durationSeconds: 360, endIndex: 3),
        ],
      );

      final progress = estimator.estimate(withTwin, origin, at)!;

      expect(progress.toNextMeters, 0);
      expect(progress.toNextSeconds, 0);
      expect(progress.remainingMeters, 1500);
      expect(progress.remainingSeconds, 360);
    });

    group('round trip', () {
      test('while stops are left the totals include the way back: 6800 m '
          'and 1440 s from the origin, 4100 m and 780 s with only C left', () {
        final fromOrigin = estimator.estimate(
          roundTripOf(const [stopA, stopB, stopC]),
          origin,
          at,
        )!;
        final onlyC = estimator.estimate(
          roundTripOf(const [stopA, stopB, stopC])
              .record('pa', delivered)
              .record('pb', delivered),
          b.point,
          at,
        )!;

        expect(
          fromOrigin,
          RouteProgress(
            next: stopA,
            toNextMeters: 1200,
            toNextSeconds: 300,
            remainingMeters: 1200 + 1500 + 900 + 3200,
            remainingSeconds: 300 + 360 + 240 + 540,
            at: at,
          ),
        );
        expect(fromOrigin.finalArrival, DateTime.utc(2026, 9, 28, 14, 24));
        expect(onlyC.next, const RouteStop(stop: c, order: 3));
        expect(onlyC.toNextMeters, 900);
        expect(onlyC.toNextSeconds, 240);
        expect(onlyC.remainingMeters, 900 + 3200);
        expect(onlyC.remainingSeconds, 240 + 540);
      });

      test('returning, halfway back from C: no next stop, half of the way '
          'back left (1600 m, 270 s)', () {
        final returning = roundTripOf(const [stopA, stopB, stopC])
            .record('pa', delivered)
            .record('pb', delivered)
            .record('pc', delivered);

        final progress = estimator.estimate(
          returning,
          const GeoPoint(0, 0.015),
          at,
        )!;

        expect(
          progress,
          RouteProgress(
            next: null,
            toNextMeters: 1600,
            toNextSeconds: 270,
            remainingMeters: 1600,
            remainingSeconds: 270,
            at: at,
          ),
        );
        expect(progress.nextArrival, DateTime.utc(2026, 9, 28, 14, 4, 30));
        expect(progress.finalArrival, DateTime.utc(2026, 9, 28, 14, 4, 30));
      });

      test('returning after a recalculation (no stop legs): the way back is '
          'measured from the start of the line', () {
        // Recalculated at B after every result: straight back to the origin.
        final recalculated = planOf(
          const [
            RouteStop(stop: a, order: 1, result: delivered),
            RouteStop(stop: b, order: 2, result: delivered),
            RouteStop(stop: c, order: 3, result: delivered),
          ],
          polyline: const [GeoPoint(0, 0.02), GeoPoint(0, 0.01), origin],
          legs: const [],
          returnTo: origin,
          returnLeg: const RouteLeg(
            distanceMeters: 2300,
            durationSeconds: 400,
            endIndex: 2,
          ),
        );

        final progress = estimator.estimate(recalculated, a.point, at)!;

        expect(progress.next, isNull);
        expect(progress.toNextMeters, 1150);
        expect(progress.toNextSeconds, 200);
        expect(progress.remainingMeters, 1150);
        expect(progress.remainingSeconds, 200);
      });
    });

    group('no estimate (null)', () {
      test('every stop visited', () {
        final done = plan
            .record('pa', delivered)
            .record('pb', delivered)
            .record('pc', delivered);

        expect(estimator.estimate(done, origin, at), isNull);
      });

      test('a plan saved without leg ends (app 0.1.0)', () {
        final legacy = planOf(
          const [stopA, stopB, stopC],
          legs: const [
            RouteLeg(distanceMeters: 1200, durationSeconds: 300),
            RouteLeg(distanceMeters: 1500, durationSeconds: 360),
            RouteLeg(distanceMeters: 900, durationSeconds: 240),
          ],
        );

        expect(estimator.estimate(legacy, origin, at), isNull);
        expect(
          estimator.estimate(legacy.record('pa', delivered), origin, at),
          isNull,
        );
      });

      test('a plan without legs', () {
        final noLegs = planOf(const [stopA, stopB, stopC], legs: const []);

        expect(estimator.estimate(noLegs, origin, at), isNull);
      });

      test('a leg end beyond the polyline or before the leg start', () {
        final beyond = planOf(
          const [stopA, stopB, stopC],
          legs: const [
            RouteLeg(distanceMeters: 1200, durationSeconds: 300, endIndex: 9),
            RouteLeg(distanceMeters: 1500, durationSeconds: 360, endIndex: 3),
            RouteLeg(distanceMeters: 900, durationSeconds: 240, endIndex: 4),
          ],
        );
        final backwards = planOf(
          const [stopA, stopB, stopC],
          legs: const [
            RouteLeg(distanceMeters: 1200, durationSeconds: 300, endIndex: 2),
            RouteLeg(distanceMeters: 1500, durationSeconds: 360, endIndex: 1),
            RouteLeg(distanceMeters: 900, durationSeconds: 240, endIndex: 4),
          ],
        );

        expect(estimator.estimate(beyond, origin, at), isNull);
        expect(
          estimator.estimate(backwards.record('pa', delivered), origin, at),
          isNull,
        );
      });
    });
  });
}

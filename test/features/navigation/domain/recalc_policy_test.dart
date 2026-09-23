import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/navigation/domain/recalc_policy.dart';

void main() {
  group('ArrivalDetector', () {
    const stop = Stop('pa', 'Rua A, 1', GeoPoint(0, 0));
    final at = DateTime.utc(2026, 9, 22, 10);

    // A fix `m` meters north of the stop on the mean sphere.
    Fix fixAt(double meters, {double accuracy = 10}) => Fix(
      GeoPoint(meters / earthRadiusMeters * 180 / math.pi, 0),
      accuracy,
      at,
    );

    final detector = ArrivalDetector();

    test('default radius is 40 m and accuracy gate 50 m', () {
      expect(detector.radiusMeters, 40);
      expect(detector.maxAccuracyMeters, 50);
    });

    test('30 m from the stop with accuracy 60 m is not arrived; with 50 m '
        'it is', () {
      expect(detector.isArrived(fixAt(30, accuracy: 60), stop), isFalse);
      expect(detector.isArrived(fixAt(30, accuracy: 50), stop), isTrue);
    });

    test('30 m from the stop with accuracy 50.1 m is not arrived', () {
      expect(detector.isArrived(fixAt(30, accuracy: 50.1), stop), isFalse);
    });

    test('40.0 m from the stop is arrived', () {
      expect(detector.isArrived(fixAt(40), stop), isTrue);
    });

    test('40.1 m from the stop is not arrived', () {
      expect(detector.isArrived(fixAt(40.1), stop), isFalse);
    });
  });

  group('RecalcPolicy', () {
    final policy = RecalcPolicy();
    final now = DateTime.utc(2026, 9, 22, 10, 0, 40);

    RecalcDecision decide({
      bool offRoute = true,
      bool inFlight = false,
      bool online = true,
      DateTime? lastRecalcAt,
    }) => policy.decide(
      offRoute: offRoute,
      inFlight: inFlight,
      online: online,
      now: now,
      lastRecalcAt: lastRecalcAt,
    );

    test('default interval is 20 s', () {
      expect(policy.minInterval, const Duration(seconds: 20));
    });

    test('not off-route → none', () {
      expect(decide(offRoute: false), RecalcDecision.none);
      expect(
        decide(offRoute: false, inFlight: true, online: false),
        RecalcDecision.none,
      );
    });

    test('off-route with one in flight → wait', () {
      expect(decide(inFlight: true), RecalcDecision.wait);
      expect(decide(inFlight: true, online: false), RecalcDecision.wait);
    });

    test('off-route while offline → deferOffline', () {
      expect(decide(online: false), RecalcDecision.deferOffline);
      expect(
        decide(
          online: false,
          lastRecalcAt: now.subtract(const Duration(seconds: 5)),
        ),
        RecalcDecision.deferOffline,
      );
    });

    test('off-route 19 s after the last recalculation → wait', () {
      expect(
        decide(lastRecalcAt: now.subtract(const Duration(seconds: 19))),
        RecalcDecision.wait,
      );
    });

    test('off-route 20 s after the last recalculation → run', () {
      expect(
        decide(lastRecalcAt: now.subtract(const Duration(seconds: 20))),
        RecalcDecision.run,
      );
    });

    test('off-route for the first time → run', () {
      expect(decide(), RecalcDecision.run);
    });
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/navigation/domain/deviation_detector.dart';

void main() {
  // Polyline along the equator; a fix at latitude `lat(m)` is exactly `m`
  // meters from it on the detector's projection.
  const polyline = [GeoPoint(0, -0.01), GeoPoint(0, 0.01)];
  double lat(double meters) => meters / earthRadiusMeters * 180 / math.pi;

  final t0 = DateTime.utc(2026, 9, 22, 10);
  var seq = 0;

  /// A fix [meters] from the polyline with a fresh timestamp.
  Fix fix(double meters, {double accuracy = 10, DateTime? at}) => Fix(
    GeoPoint(lat(meters), 0),
    accuracy,
    at ?? t0.add(Duration(seconds: ++seq)),
  );

  Fix far({double accuracy = 10, DateTime? at}) =>
      fix(120, accuracy: accuracy, at: at);
  Fix near() => fix(5);

  late DeviationDetector detector;

  setUp(() {
    seq = 0;
    detector = DeviationDetector();
  });

  List<bool> feedAll(Iterable<Fix> fixes) => [
    for (final f in fixes) detector.feed(f, polyline),
  ];

  group('DeviationDetector', () {
    test('defaults are 50 m, 3 consecutive fixes and 30 m accuracy', () {
      expect(detector.thresholdMeters, 50);
      expect(detector.consecutive, 3);
      expect(detector.maxAccuracyMeters, 30);
      expect(detector.strikes, 0);
    });

    test('2 far fixes are not off-route', () {
      expect(feedAll([far(), far()]), [false, false]);
      expect(detector.strikes, 2);
    });

    test('3 consecutive far fixes declare off-route', () {
      expect(feedAll([far(), far(), far()]), [false, false, true]);
      expect(detector.strikes, 3);
    });

    test('a near fix resets the count: far, near, far, far, far → true only '
        'at the 3rd consecutive', () {
      expect(feedAll([far(), near(), far(), far(), far()]), [
        false,
        false,
        false,
        false,
        true,
      ]);
    });

    test('accuracy 31 m is ignored: neither counts nor resets', () {
      expect(
        feedAll([far(accuracy: 31), far(accuracy: 31), far(accuracy: 31)]),
        [false, false, false],
      );
      expect(detector.strikes, 0);

      expect(feedAll([far(), far(accuracy: 31), far(), far()]), [
        false,
        false,
        false,
        true,
      ]);
    });

    test('accuracy exactly 30 m counts', () {
      expect(
        feedAll([far(accuracy: 30), far(accuracy: 30), far(accuracy: 30)]),
        [false, false, true],
      );
    });

    test('the same fix arriving twice counts once', () {
      final t1 = t0.add(const Duration(minutes: 1));
      expect(feedAll([far(at: t1), far(at: t1), far()]), [false, false, false]);
      expect(detector.strikes, 2);

      expect(detector.feed(far(), polyline), isTrue);
    });

    test('50.0 m from the polyline is not off-route', () {
      expect(feedAll([fix(50), fix(50), fix(50)]), [false, false, false]);
      expect(detector.strikes, 0);
    });

    test('50.1 m from the polyline is off-route after 3 fixes', () {
      expect(feedAll([fix(50.1), fix(50.1), fix(50.1)]), [false, false, true]);
    });

    test('an ignored fix gives no verdict and keeps the strikes: after 3 far '
        'fixes, a 31 m fix or a repeated fix is false', () {
      feedAll([far(), far(), far()]);
      final last = t0.add(Duration(seconds: seq));

      expect(detector.feed(far(accuracy: 31), polyline), isFalse);
      expect(detector.strikes, 3);
      expect(detector.feed(far(at: last), polyline), isFalse);
      expect(detector.strikes, 3);

      expect(detector.feed(far(), polyline), isTrue);
      expect(detector.strikes, 4);
    });

    test('stays off-route on further far fixes until reset', () {
      feedAll([far(), far(), far()]);

      expect(detector.feed(far(), polyline), isTrue);
      expect(detector.strikes, 4);

      detector.reset();

      expect(detector.strikes, 0);
      expect(detector.feed(far(), polyline), isFalse);
      expect(detector.strikes, 1);
    });
  });
}

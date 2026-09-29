import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/navigation/domain/odometer.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 28, 16, 40);
  var seq = 0;

  /// A fix with a fresh timestamp.
  Fix fix(double lat, double lng, {double accuracy = 10}) =>
      Fix(GeoPoint(lat, lng), accuracy, t0.add(Duration(seconds: ++seq)));

  /// [meters] within ±1%, on top of [from].
  Matcher about(double meters, {int from = 0}) =>
      closeTo(from + meters, meters * 0.01);

  setUp(() => seq = 0);

  group('Odometer', () {
    test('fixes 0.001° apart on the equator add about 111 m each; the first '
        'fix adds nothing', () {
      final odometer = Odometer();
      expect(odometer.meters, 0);

      odometer.add(fix(0, 0));
      expect(odometer.meters, 0);

      odometer.add(fix(0, 0.001));
      expect(odometer.meters, about(111));

      odometer
        ..add(fix(0, 0.002))
        ..add(fix(0, 0.003));
      expect(odometer.meters, about(333));
    });

    test('a 31 m fix is skipped and the next precise fix connects to the '
        'last precise one', () {
      final odometer = Odometer()
        // Before the chain: it does not start it.
        ..add(fix(0.01, 0.01, accuracy: 31))
        ..add(fix(0, 0));
      expect(odometer.meters, 0);

      // A detour off the line: through it the total would be about 314 m.
      odometer.add(fix(0.001, 0.001, accuracy: 31));
      expect(odometer.meters, 0);

      odometer.add(fix(0, 0.002));
      expect(odometer.meters, about(222));
    });

    test('a 30 m fix counts', () {
      final odometer = Odometer()
        ..add(fix(0, 0, accuracy: 30))
        ..add(fix(0, 0.001, accuracy: 30));

      expect(odometer.meters, about(111));
    });

    test('starts from a given value and adds to it', () {
      final odometer = Odometer(meters: 850);
      expect(odometer.meters, 850);

      odometer
        ..add(fix(0, 0))
        ..add(fix(0, 0.001));
      expect(odometer.meters, about(111, from: 850));
    });
  });
}

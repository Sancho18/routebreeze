import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/route/presentation/route_format.dart';

void main() {
  group('formatDistance (ROUTE-04: km with one decimal)', () {
    test('12345 m → "12,3 km"', () {
      expect(formatDistance(12345), '12,3 km');
    });

    test('1000 m → "1,0 km"', () {
      expect(formatDistance(1000), '1,0 km');
    });

    test('below 1 km stays in meters: 850 m → "850 m"', () {
      expect(formatDistance(850), '850 m');
    });
  });

  group('formatDuration (ROUTE-04: minutes)', () {
    test('605 s → "10 min"', () {
      expect(formatDuration(605), '10 min');
    });

    test('90 s rounds to "2 min"', () {
      expect(formatDuration(90), '2 min');
    });

    test('3900 s → "1 h 05 min"', () {
      expect(formatDuration(3900), '1 h 05 min');
    });
  });
}

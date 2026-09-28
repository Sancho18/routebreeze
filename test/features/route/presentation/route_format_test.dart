import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/route/presentation/route_format.dart';

void main() {
  group('formatDistance (km with one decimal)', () {
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

  group('formatDuration (minutes)', () {
    test('605 s → "10 min"', () {
      expect(formatDuration(605), '10 min');
    });

    test('90 s rounds to "2 min"', () {
      expect(formatDuration(90), '2 min');
    });

    test('3900 s → "1 h 05 min"', () {
      expect(formatDuration(3900), '1 h 05 min');
    });

    test('under 30 s (0 minutes when rounded) → "< 1 min"; 30 s → '
        '"1 min"', () {
      expect(formatDuration(0), '< 1 min');
      expect(formatDuration(29), '< 1 min');
      expect(formatDuration(30), '1 min');
    });
  });

  group('formatClock (24 h, as given)', () {
    test('14:32 → "14:32"', () {
      expect(formatClock(DateTime.utc(2026, 9, 28, 14, 32, 59)), '14:32');
    });

    test('single-digit hour and minute are zero-padded: "09:05"', () {
      expect(formatClock(DateTime.utc(2026, 9, 28, 9, 5)), '09:05');
    });

    test('midnight → "00:00"', () {
      expect(formatClock(DateTime.utc(2026, 9, 29)), '00:00');
    });
  });
}

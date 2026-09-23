import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';

void main() {
  // 1° of latitude ≈ 111.195 km on the mean sphere; 0.001° ≈ 111.2 m.
  const metersPerMilliDegree = 111.2;

  group('haversineMeters', () {
    test('same point is 0', () {
      const p = GeoPoint(-23.5645, -46.6527);
      expect(haversineMeters(p, p), 0);
    });

    test('0.001° of latitude is ≈ 111.2 m (within 1%)', () {
      expect(
        haversineMeters(const GeoPoint(0, 0), const GeoPoint(0.001, 0)),
        closeTo(metersPerMilliDegree, metersPerMilliDegree * 0.01),
      );
    });

    test('Av. Paulista 1000 → Rua Augusta 500 is ≈ 1.2 km (within 1%)', () {
      const paulista = GeoPoint(-23.5645, -46.6527);
      const augusta = GeoPoint(-23.5537, -46.6534);
      expect(haversineMeters(paulista, augusta), closeTo(1200, 12));
    });
  });

  group('distanceToPolylineMeters', () {
    test('point on the segment is 0', () {
      const line = [GeoPoint(-23.56, -46.66), GeoPoint(-23.56, -46.64)];
      expect(
        distanceToPolylineMeters(const GeoPoint(-23.56, -46.65), line),
        closeTo(0, 1e-6),
      );
    });

    test('perpendicular offset of 0.001° latitude is ≈ 111.2 m', () {
      const line = [GeoPoint(0, -0.01), GeoPoint(0, 0.01)];
      expect(
        distanceToPolylineMeters(const GeoPoint(0.001, 0), line),
        closeTo(metersPerMilliDegree, metersPerMilliDegree * 0.01),
      );
    });

    test('a fix 50 m beside the line at São Paulo latitude measures 50 m '
        '(the deviation threshold)', () {
      const lat = -23.5645;
      const line = [GeoPoint(lat, -46.66), GeoPoint(lat, -46.64)];
      // 50 m north of the line: 50 / 111195 m per degree.
      const fix = GeoPoint(lat + 50 / 111195, -46.65);
      expect(distanceToPolylineMeters(fix, line), closeTo(50, 0.5));
    });

    test('beyond the endpoints the distance is to the nearest endpoint', () {
      const start = GeoPoint(0, 0);
      const end = GeoPoint(0, 0.01);
      const line = [start, end];
      const pastEnd = GeoPoint(0, 0.02);
      const beforeStart = GeoPoint(0, -0.005);

      final toEnd = haversineMeters(pastEnd, end);
      expect(
        distanceToPolylineMeters(pastEnd, line),
        closeTo(toEnd, toEnd * 0.01),
      );
      final toStart = haversineMeters(beforeStart, start);
      expect(
        distanceToPolylineMeters(beforeStart, line),
        closeTo(toStart, toStart * 0.01),
      );
    });

    test('takes the minimum over all segments', () {
      const line = [GeoPoint(0, 0), GeoPoint(0, 0.01), GeoPoint(0.01, 0.01)];
      // 0.0005° east of the second (north-south) segment ≈ 55.6 m; the first
      // segment is ≈ 556 m away.
      expect(
        distanceToPolylineMeters(const GeoPoint(0.005, 0.0105), line),
        closeTo(55.6, 0.6),
      );
    });

    test('single-point line is the distance to that point', () {
      expect(
        distanceToPolylineMeters(const GeoPoint(0.001, 0), const [
          GeoPoint(0, 0),
        ]),
        closeTo(metersPerMilliDegree, metersPerMilliDegree * 0.01),
      );
    });

    test('empty line is infinity', () {
      expect(
        distanceToPolylineMeters(const GeoPoint(0, 0), const []),
        double.infinity,
      );
    });
  });

  group('farthestIndex', () {
    test('returns the index of the farthest point', () {
      const origin = GeoPoint(0, 0);
      const points = [
        GeoPoint(0.001, 0),
        GeoPoint(0.003, 0),
        GeoPoint(0.002, 0),
      ];
      expect(farthestIndex(origin, points), 1);
    });

    test('throws ArgumentError on an empty list', () {
      expect(
        () => farthestIndex(const GeoPoint(0, 0), const []),
        throwsArgumentError,
      );
    });
  });
}

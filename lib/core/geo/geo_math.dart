import 'dart:math' as math;

import 'geo_point.dart';

/// Mean Earth radius in meters (IUGG).
const double earthRadiusMeters = 6371008.8;

double _radians(double degrees) => degrees * math.pi / 180;

/// Great-circle distance between [a] and [b] in meters.
double haversineMeters(GeoPoint a, GeoPoint b) {
  final dLat = _radians(b.lat - a.lat);
  final dLng = _radians(b.lng - a.lng);
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final h =
      sinLat * sinLat +
      math.cos(_radians(a.lat)) * math.cos(_radians(b.lat)) * sinLng * sinLng;
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Minimum distance in meters from [point] to the polyline [line].
///
/// Each vertex is projected onto a local equirectangular plane centered on
/// [point] (x = Δlng·cos(lat)·R, y = Δlat·R), then the smallest
/// point-to-segment distance is taken. A single-point line yields the
/// distance to that point; an empty line yields `double.infinity`.
double distanceToPolylineMeters(GeoPoint point, List<GeoPoint> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) return haversineMeters(point, line.first);

  final cosLat = math.cos(_radians(point.lat));
  math.Point<double> project(GeoPoint p) => math.Point(
    _radians(p.lng - point.lng) * cosLat * earthRadiusMeters,
    _radians(p.lat - point.lat) * earthRadiusMeters,
  );

  var best = double.infinity;
  var start = project(line.first);
  for (var i = 1; i < line.length; i++) {
    final end = project(line[i]);
    best = math.min(best, _distanceFromOriginToSegment(start, end));
    start = end;
  }
  return best;
}

/// Distance from the origin (0, 0) to the segment [a]–[b].
double _distanceFromOriginToSegment(
  math.Point<double> a,
  math.Point<double> b,
) {
  final d = b - a;
  final length2 = d.x * d.x + d.y * d.y;
  var t = 0.0;
  if (length2 > 0) {
    t = (-(a.x * d.x) - (a.y * d.y)) / length2;
    t = t.clamp(0.0, 1.0);
  }
  final closest = a + d * t;
  return closest.magnitude;
}

/// Index of the point in [points] farthest (great-circle) from [origin].
///
/// Throws [ArgumentError] when [points] is empty.
int farthestIndex(GeoPoint origin, List<GeoPoint> points) {
  if (points.isEmpty) {
    throw ArgumentError.value(points, 'points', 'must not be empty');
  }
  var bestIndex = 0;
  var bestDistance = -1.0;
  for (var i = 0; i < points.length; i++) {
    final distance = haversineMeters(origin, points[i]);
    if (distance > bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }
  return bestIndex;
}

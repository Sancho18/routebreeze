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

  final project = _planeAround(point);
  var best = double.infinity;
  var start = project(line.first);
  for (var i = 1; i < line.length; i++) {
    final end = project(line[i]);
    best = math.min(best, _closestToOrigin(start, end).distance);
    start = end;
  }
  return best;
}

/// Where [point] falls on the segment [a]→[b]: the distance in meters to the
/// closest point of the segment and how far along the segment that point
/// lies (`fraction` 0 at [a], 1 at [b]). Same plane as
/// [distanceToPolylineMeters].
({double meters, double fraction}) projectOntoSegment(
  GeoPoint point,
  GeoPoint a,
  GeoPoint b,
) {
  final project = _planeAround(point);
  final closest = _closestToOrigin(project(a), project(b));
  return (meters: closest.distance, fraction: closest.t);
}

/// Local equirectangular plane centered on [origin]:
/// x = Δlng·cos(lat)·R, y = Δlat·R.
math.Point<double> Function(GeoPoint) _planeAround(GeoPoint origin) {
  final cosLat = math.cos(_radians(origin.lat));
  return (p) => math.Point(
    _radians(p.lng - origin.lng) * cosLat * earthRadiusMeters,
    _radians(p.lat - origin.lat) * earthRadiusMeters,
  );
}

/// The point of segment [a]→[b] closest to the plane origin: its distance
/// to the origin and its position `t` along the segment (0..1). A segment
/// with no length is its start.
({double distance, double t}) _closestToOrigin(
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
  return (distance: (a + d * t).magnitude, t: t);
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

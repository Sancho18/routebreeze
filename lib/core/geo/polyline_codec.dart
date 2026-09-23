import 'geo_point.dart';

/// Decodes a Google encoded polyline (precision 1e-5) into points.
///
/// Throws [FormatException] on malformed input: a chunk cut before its
/// terminating character, a latitude without its longitude, or a character
/// below `?` (63).
List<GeoPoint> decodePolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final latDelta = _readDelta(encoded, index);
    index = latDelta.$2;
    final lngDelta = _readDelta(encoded, index);
    index = lngDelta.$2;
    lat += latDelta.$1;
    lng += lngDelta.$1;
    points.add(GeoPoint(lat / 1e5, lng / 1e5));
  }
  return points;
}

/// Reads one varint-encoded delta starting at [start]; returns the delta and
/// the index after it.
(int, int) _readDelta(String encoded, int start) {
  var index = start;
  var result = 0;
  var shift = 0;
  int chunk;
  do {
    if (index >= encoded.length) {
      throw FormatException('Unterminated polyline chunk', encoded, start);
    }
    chunk = encoded.codeUnitAt(index) - 63;
    if (chunk < 0) {
      throw FormatException('Invalid polyline character', encoded, index);
    }
    index++;
    result |= (chunk & 0x1f) << shift;
    shift += 5;
  } while (chunk >= 0x20);
  final delta = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  return (delta, index);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/geo/polyline_codec.dart';

void main() {
  group('decodePolyline', () {
    test("decodes Google's documented sample into its 3 points", () {
      expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), const [
        GeoPoint(38.5, -120.2),
        GeoPoint(40.7, -120.95),
        GeoPoint(43.252, -126.453),
      ]);
    });

    test('empty string decodes to an empty list', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('latitude without its longitude throws FormatException', () {
      expect(() => decodePolyline('_p~iF'), throwsFormatException);
    });

    test('chunk cut before its last character throws FormatException', () {
      expect(() => decodePolyline('_p~i'), throwsFormatException);
    });

    test('character below 63 throws FormatException', () {
      expect(() => decodePolyline('_p~iF ps|U'), throwsFormatException);
    });
  });
}

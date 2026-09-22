import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';

void main() {
  group('GeoPoint', () {
    test('is equatable by lat and lng', () {
      expect(
        const GeoPoint(-23.5645, -46.6527),
        const GeoPoint(-23.5645, -46.6527),
      );
      expect(
        const GeoPoint(-23.5645, -46.6527),
        isNot(const GeoPoint(-46.6527, -23.5645)),
      );
    });

    test('toJson/fromJson round-trips', () {
      const point = GeoPoint(-23.5645, -46.6527);
      expect(point.toJson(), {'lat': -23.5645, 'lng': -46.6527});
      expect(GeoPoint.fromJson(point.toJson()), point);
    });
  });
}

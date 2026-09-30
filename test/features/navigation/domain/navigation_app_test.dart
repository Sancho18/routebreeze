import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/navigation_app.dart';

void main() {
  const stop = Stop(
    'ChIJ_pl-paulista',
    'Av. Paulista, 1000 - Bela Vista, São Paulo',
    GeoPoint(-23.5658, -46.65),
  );

  group('NavigationApp', () {
    test('labels: "Google Maps" and "Waze", in that order', () {
      expect(NavigationApp.values.map((app) => app.label), [
        'Google Maps',
        'Waze',
      ]);
    });

    test('Google Maps: Maps URLs directions to the stop by coordinates and '
        'place id, driving, starting navigation', () {
      expect(
        NavigationApp.googleMaps.linkTo(stop).toString(),
        'https://www.google.com/maps/dir/?api=1'
        '&destination=-23.565800%2C-46.650000'
        '&destination_place_id=ChIJ_pl-paulista'
        '&travelmode=driving&dir_action=navigate',
      );
    });

    test('Waze: deep link to the coordinates with navigation on', () {
      expect(
        NavigationApp.waze.linkTo(stop).toString(),
        'https://waze.com/ul?ll=-23.565800%2C-46.650000&navigate=yes',
      );
    });

    test('coordinates keep six decimals and never use exponent notation', () {
      const nearZero = Stop('p0', 'Null Island', GeoPoint(0.0000001, -1e-7));

      expect(
        NavigationApp.waze.linkTo(nearZero).queryParameters['ll'],
        '0.000000,-0.000000',
      );
    });
  });
}

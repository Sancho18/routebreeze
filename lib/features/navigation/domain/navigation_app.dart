import '../../addresses/domain/stop.dart';

/// Navigation apps a stop can be handed over to.
enum NavigationApp {
  googleMaps('Google Maps'),
  waze('Waze');

  const NavigationApp(this.label);

  final String label;

  /// Universal link for driving directions to [stop]: it opens the app or,
  /// when missing, its website, so no URL scheme or package query is needed.
  Uri linkTo(Stop stop) {
    final point =
        '${_coordinate(stop.point.lat)},'
        '${_coordinate(stop.point.lng)}';
    return switch (this) {
      googleMaps => Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': point,
        if (stop.placeId.isNotEmpty) 'destination_place_id': stop.placeId,
        'travelmode': 'driving',
        'dir_action': 'navigate',
      }),
      waze => Uri.https('waze.com', '/ul', {'ll': point, 'navigate': 'yes'}),
    };
  }

  /// Six decimals (≈ 0.1 m); `toString` could switch to exponent notation.
  static String _coordinate(double degrees) => degrees.toStringAsFixed(6);
}

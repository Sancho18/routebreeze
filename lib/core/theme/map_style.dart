import 'dart:ui' show Brightness;

/// Google Maps style for dark mode, built on the `RbPalette.dark` colors.
const String rbDarkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1a1d23"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#a4acb9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#0f1115"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#242830"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2f343d"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#3a404b"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3a404b"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#242830"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f1115"}]}
]''';

/// The style for [brightness]; null means Google's default (light mode).
String? mapStyleFor(Brightness brightness) =>
    brightness == Brightness.dark ? rbDarkMapStyle : null;

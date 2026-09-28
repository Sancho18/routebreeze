import 'dart:ui' show Brightness;

/// Google Maps style for dark mode, from the dark palette: land #1A1D23
/// (surface-200), water #0F1115 (surface-100), local roads #2F343D (border),
/// arterials and highways #3A404B, POI and transit #242830 (between land and
/// roads), labels #A4ACB9 (ink-muted) outlined in #0F1115.
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

/// The map style for [brightness]: the dark style in dark mode, Google's
/// default (null) in light mode.
String? mapStyleFor(Brightness brightness) =>
    brightness == Brightness.dark ? rbDarkMapStyle : null;

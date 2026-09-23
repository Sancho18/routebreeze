import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/route_map_objects.dart';

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  const c = Stop('pc', 'Rua C, 3', GeoPoint(-23.70, -46.80));
  // The polyline bulges east of every stop so the bounds must include it.
  const polyline = [
    origin,
    GeoPoint(-23.58, -46.60),
    GeoPoint(-23.60, -46.70),
    GeoPoint(-23.70, -46.80),
  ];
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: b, order: 1, visited: false),
      RouteStop(stop: a, order: 2, visited: false),
      RouteStop(stop: c, order: 3, visited: false),
    ],
    polyline: polyline,
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );
  final icons = {
    1: BitmapDescriptor.defaultMarkerWithHue(10),
    2: BitmapDescriptor.defaultMarkerWithHue(20),
    3: BitmapDescriptor.defaultMarkerWithHue(30),
  };
  final startIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );

  late RouteMapObjects objects;

  setUp(() {
    objects = buildMapObjects(plan, numberedIcons: icons, startIcon: startIcon);
  });

  Marker marker(String id) =>
      objects.markers.singleWhere((m) => m.markerId.value == id);

  group('buildMapObjects', () {
    test('one start marker plus N numbered markers on the ordered stops', () {
      expect(objects.markers, hasLength(4));
      expect(objects.markers.map((m) => m.markerId.value), {
        'start',
        'stop-pb',
        'stop-pa',
        'stop-pc',
      });

      final start = marker('start');
      expect(start.position, const LatLng(-23.5614, -46.6559));
      expect(start.icon.toJson(), startIcon.toJson());
      expect(start.infoWindow.title, 'Partida');

      expect(marker('stop-pb').position, const LatLng(-23.60, -46.70));
      expect(marker('stop-pb').icon.toJson(), icons[1]!.toJson());
      expect(marker('stop-pa').position, const LatLng(-23.565, -46.66));
      expect(marker('stop-pa').icon.toJson(), icons[2]!.toJson());
      expect(marker('stop-pc').position, const LatLng(-23.70, -46.80));
      expect(marker('stop-pc').icon.toJson(), icons[3]!.toJson());
      expect(marker('stop-pb').anchor, const Offset(0.5, 0.5));
      expect(marker('stop-pb').infoWindow.title, 'Rua B, 2');
      expect(objects.origin, const LatLng(-23.5614, -46.6559));
    });

    test('one brand polyline, width 5, with the plan points', () {
      expect(objects.polylines, hasLength(1));
      final line = objects.polylines.single;
      expect(line.polylineId.value, 'route');
      expect(line.color, RbColors.brand);
      expect(line.width, 5);
      expect(line.points, const [
        LatLng(-23.5614, -46.6559),
        LatLng(-23.58, -46.60),
        LatLng(-23.60, -46.70),
        LatLng(-23.70, -46.80),
      ]);
    });

    test('bounds cover origin, stops and the polyline', () {
      expect(objects.bounds.southwest, const LatLng(-23.70, -46.80));
      expect(objects.bounds.northeast, const LatLng(-23.5614, -46.60));
    });
  });
}

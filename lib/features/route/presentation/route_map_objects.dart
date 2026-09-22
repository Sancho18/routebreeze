import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/geo/geo_point.dart';
import '../../../core/theme/rb_tokens.dart';
import '../domain/route_plan.dart';

/// What the route map draws (ROUTE-03): the start and numbered stop markers,
/// the `brand` polyline and the bounds the camera fits.
class RouteMapObjects {
  const RouteMapObjects({
    required this.origin,
    required this.markers,
    required this.polylines,
    required this.bounds,
  });

  final LatLng origin;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLngBounds bounds;

  static const String startMarkerId = 'start';
  static const String polylineId = 'route';

  /// Marker id of the stop with [placeId].
  static String stopMarkerId(String placeId) => 'stop-$placeId';
}

/// Pure mapping from a [plan] to map objects. [numberedIcons] is keyed by
/// stop order; [startIcon] marks "Partida".
RouteMapObjects buildMapObjects(
  RoutePlan plan, {
  required Map<int, BitmapDescriptor> numberedIcons,
  required BitmapDescriptor startIcon,
}) {
  final origin = _latLng(plan.origin);
  final markers = <Marker>{
    Marker(
      markerId: const MarkerId(RouteMapObjects.startMarkerId),
      position: origin,
      icon: startIcon,
      infoWindow: const InfoWindow(title: 'Partida'),
    ),
    for (final stop in plan.stops)
      Marker(
        markerId: MarkerId(RouteMapObjects.stopMarkerId(stop.stop.placeId)),
        position: _latLng(stop.stop.point),
        icon: numberedIcons[stop.order] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: stop.stop.address),
        zIndexInt: stop.order,
      ),
  };
  final polyline = Polyline(
    polylineId: const PolylineId(RouteMapObjects.polylineId),
    points: [for (final point in plan.polyline) _latLng(point)],
    color: RbColors.brand,
    width: 5,
  );
  return RouteMapObjects(
    origin: origin,
    markers: markers,
    polylines: {polyline},
    bounds: _bounds([
      plan.origin,
      for (final stop in plan.stops) stop.stop.point,
      ...plan.polyline,
    ]),
  );
}

LatLng _latLng(GeoPoint point) => LatLng(point.lat, point.lng);

LatLngBounds _bounds(List<GeoPoint> points) {
  var minLat = points.first.lat;
  var maxLat = points.first.lat;
  var minLng = points.first.lng;
  var maxLng = points.first.lng;
  for (final point in points) {
    minLat = math.min(minLat, point.lat);
    maxLat = math.max(maxLat, point.lat);
    minLng = math.min(minLng, point.lng);
    maxLng = math.max(maxLng, point.lng);
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

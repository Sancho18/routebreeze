import 'package:equatable/equatable.dart';

import '../../../core/geo/geo_point.dart';
import '../../addresses/domain/stop.dart';

/// A stop in its optimized position (`order` is 1..N) with its visited flag
/// (ROUTE-02, NAV-04).
class RouteStop extends Equatable {
  const RouteStop({
    required this.stop,
    required this.order,
    required this.visited,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    stop: Stop.fromJson(json['stop'] as Map<String, dynamic>),
    order: json['order'] as int,
    visited: json['visited'] as bool,
  );

  final Stop stop;
  final int order;
  final bool visited;

  RouteStop copyWith({bool? visited}) =>
      RouteStop(stop: stop, order: order, visited: visited ?? this.visited);

  Map<String, dynamic> toJson() => {
    'stop': stop.toJson(),
    'order': order,
    'visited': visited,
  };

  @override
  List<Object?> get props => [stop, order, visited];

  @override
  bool get stringify => true;
}

/// Distance and duration of one leg between consecutive route points.
class RouteLeg extends Equatable {
  const RouteLeg({required this.distanceMeters, required this.durationSeconds});

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
    distanceMeters: json['distanceMeters'] as int,
    durationSeconds: json['durationSeconds'] as int,
  );

  final int distanceMeters;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
  };

  @override
  List<Object?> get props => [distanceMeters, durationSeconds];

  @override
  bool get stringify => true;
}

/// The active route: ordered stops, decoded polyline and totals. This is the
/// unit persisted between sessions (OFFL-03).
class RoutePlan extends Equatable {
  const RoutePlan({
    required this.origin,
    required this.stops,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.legs,
    required this.computedAt,
  });

  factory RoutePlan.fromJson(Map<String, dynamic> json) => RoutePlan(
    origin: GeoPoint.fromJson(json['origin'] as Map<String, dynamic>),
    stops: [
      for (final stop in json['stops'] as List)
        RouteStop.fromJson(stop as Map<String, dynamic>),
    ],
    polyline: [
      for (final point in json['polyline'] as List)
        GeoPoint.fromJson(point as Map<String, dynamic>),
    ],
    distanceMeters: json['distanceMeters'] as int,
    durationSeconds: json['durationSeconds'] as int,
    legs: [
      for (final leg in json['legs'] as List)
        RouteLeg.fromJson(leg as Map<String, dynamic>),
    ],
    computedAt: DateTime.parse(json['computedAt'] as String),
  );

  final GeoPoint origin;

  /// Optimized order, numbered 1..N.
  final List<RouteStop> stops;

  /// Decoded route geometry.
  final List<GeoPoint> polyline;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteLeg> legs;
  final DateTime computedAt;

  /// Stops not yet visited, in optimized order.
  List<RouteStop> get unvisited => [
    for (final stop in stops)
      if (!stop.visited) stop,
  ];

  bool get isComplete => stops.every((stop) => stop.visited);

  /// The next stop to reach, or null when the route is complete.
  RouteStop? get nextStop => unvisited.firstOrNull;

  /// A copy with the stop identified by [placeId] marked visited.
  RoutePlan markVisited(String placeId) => RoutePlan(
    origin: origin,
    stops: [
      for (final stop in stops)
        stop.stop.placeId == placeId ? stop.copyWith(visited: true) : stop,
    ],
    polyline: polyline,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    legs: legs,
    computedAt: computedAt,
  );

  Map<String, dynamic> toJson() => {
    'origin': origin.toJson(),
    'stops': [for (final stop in stops) stop.toJson()],
    'polyline': [for (final point in polyline) point.toJson()],
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'legs': [for (final leg in legs) leg.toJson()],
    'computedAt': computedAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [
    origin,
    stops,
    polyline,
    distanceMeters,
    durationSeconds,
    legs,
    computedAt,
  ];

  @override
  bool get stringify => true;
}

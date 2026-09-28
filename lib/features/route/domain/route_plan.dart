import 'package:equatable/equatable.dart';

import '../../../core/geo/geo_point.dart';
import '../../addresses/domain/stop.dart';

/// A stop in its optimized position (`order` is 1..N) with its visited flag.
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

/// One stretch of the route, from the previous stop (or the origin) to the
/// next one.
class RouteLeg extends Equatable {
  const RouteLeg({
    required this.distanceMeters,
    required this.durationSeconds,
    this.endIndex,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
    distanceMeters: json['distanceMeters'] as int,
    durationSeconds: json['durationSeconds'] as int,
    endIndex: json['endIndex'] as int?,
  );

  final int distanceMeters;
  final int durationSeconds;

  /// Index in [RoutePlan.polyline] of the vertex where this leg reaches its
  /// stop. Null in plans persisted without it (app 0.1.0).
  final int? endIndex;

  Map<String, dynamic> toJson() => {
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    if (endIndex != null) 'endIndex': endIndex,
  };

  @override
  List<Object?> get props => [distanceMeters, durationSeconds, endIndex];

  @override
  bool get stringify => true;
}

/// The active route: ordered stops, decoded polyline and totals. This is the
/// unit persisted between sessions.
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

  final List<RouteStop> stops;

  final List<GeoPoint> polyline;
  final int distanceMeters;
  final int durationSeconds;

  /// One per stop of the last computation, in visiting order: they belong to
  /// the last `legs.length` [stops] (a recalculation keeps the visited stops
  /// first, without legs).
  final List<RouteLeg> legs;
  final DateTime computedAt;

  List<RouteStop> get unvisited => [
    for (final stop in stops)
      if (!stop.visited) stop,
  ];

  bool get isComplete => stops.every((stop) => stop.visited);

  RouteStop? get nextStop => unvisited.firstOrNull;

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

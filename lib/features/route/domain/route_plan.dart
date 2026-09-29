import 'package:equatable/equatable.dart';

import '../../../core/geo/geo_point.dart';
import '../../addresses/domain/stop.dart';
import 'stop_result.dart';

/// A stop in its optimized position (`order` is 1..N) with its [result].
class RouteStop extends Equatable {
  const RouteStop({required this.stop, required this.order, this.result});

  /// Reads the saved [result]; a stop saved as visited before results
  /// existed reads as delivered without a time.
  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    stop: Stop.fromJson(json['stop'] as Map<String, dynamic>),
    order: json['order'] as int,
    result: switch (json['result'] as Map<String, dynamic>?) {
      final result? => StopResult.fromJson(result),
      null when json['visited'] as bool => const StopResult.delivered(),
      null => null,
    },
  );

  final Stop stop;
  final int order;

  /// Null until the driver records what happened at the stop.
  final StopResult? result;

  bool get visited => result != null;

  /// `visited` is still written so older builds can read the route.
  Map<String, dynamic> toJson() => {
    'stop': stop.toJson(),
    'order': order,
    'visited': visited,
    'result': ?result?.toJson(),
  };

  @override
  List<Object?> get props => [stop, order, result];

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
    this.startedAt,
    this.traveledMeters = 0,
    this.returnTo,
    this.returnLeg,
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
    startedAt: switch (json['startedAt'] as String?) {
      final at? => DateTime.parse(at),
      null => null,
    },
    traveledMeters: json['traveledMeters'] as int? ?? 0,
    returnTo: switch (json['returnTo'] as Map<String, dynamic>?) {
      final point? => GeoPoint.fromJson(point),
      null => null,
    },
    returnLeg: switch (json['returnLeg'] as Map<String, dynamic>?) {
      final leg? => RouteLeg.fromJson(leg),
      null => null,
    },
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

  /// First "Iniciar" of the route; null before it and in routes saved
  /// before it was kept.
  final DateTime? startedAt;

  /// Meters traveled while navigating; 0 in routes saved before it was
  /// kept.
  final int traveledMeters;

  /// Where a round trip ends: the start of the route, which stays when a
  /// recalculation moves [origin]. Null on one-way routes and in routes
  /// saved before round trips.
  final GeoPoint? returnTo;

  /// The last leg of the last computation, from its last stop (or its
  /// origin) to [returnTo]; null on one-way routes.
  final RouteLeg? returnLeg;

  List<RouteStop> get unvisited => [
    for (final stop in stops)
      if (!stop.visited) stop,
  ];

  bool get isComplete => stops.every((stop) => stop.visited);

  bool get isRoundTrip => returnTo != null;

  /// Every stop of a round trip has a result: only the way back is left.
  bool get isReturning => isRoundTrip && isComplete;

  RouteStop? get nextStop => unvisited.firstOrNull;

  /// Gives the stop [placeId] its [result]; a stop that already has one
  /// keeps it.
  RoutePlan record(String placeId, StopResult result) => _copy(
    stops: [
      for (final stop in stops)
        stop.stop.placeId == placeId && stop.result == null
            ? RouteStop(stop: stop.stop, order: stop.order, result: result)
            : stop,
    ],
  );

  /// Starts the route at [at] unless it has already started.
  RoutePlan withStart(DateTime at) => _copy(startedAt: startedAt ?? at);

  RoutePlan withTraveled(int meters) => _copy(traveledMeters: meters);

  /// This plan with the results (matched by place id), the start and the
  /// distance traveled of [previous]; its own route, the point to return to
  /// and the way back included, stays.
  RoutePlan withProgressFrom(RoutePlan previous) {
    var plan = _copy(
      startedAt: previous.startedAt,
      traveledMeters: previous.traveledMeters,
    );
    for (final stop in previous.stops) {
      if (stop.result case final result?) {
        plan = plan.record(stop.stop.placeId, result);
      }
    }
    return plan;
  }

  RoutePlan _copy({
    List<RouteStop>? stops,
    DateTime? startedAt,
    int? traveledMeters,
  }) => RoutePlan(
    origin: origin,
    stops: stops ?? this.stops,
    polyline: polyline,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    legs: legs,
    computedAt: computedAt,
    startedAt: startedAt ?? this.startedAt,
    traveledMeters: traveledMeters ?? this.traveledMeters,
    returnTo: returnTo,
    returnLeg: returnLeg,
  );

  Map<String, dynamic> toJson() => {
    'origin': origin.toJson(),
    'stops': [for (final stop in stops) stop.toJson()],
    'polyline': [for (final point in polyline) point.toJson()],
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'legs': [for (final leg in legs) leg.toJson()],
    'computedAt': computedAt.toUtc().toIso8601String(),
    'startedAt': ?startedAt?.toUtc().toIso8601String(),
    if (traveledMeters > 0) 'traveledMeters': traveledMeters,
    'returnTo': ?returnTo?.toJson(),
    'returnLeg': ?returnLeg?.toJson(),
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
    startedAt,
    traveledMeters,
    returnTo,
    returnLeg,
  ];

  @override
  bool get stringify => true;
}

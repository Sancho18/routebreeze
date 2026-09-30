import 'package:equatable/equatable.dart';

import '../../route/domain/route_plan.dart';

/// The numbers of a finished route: results, distance traveled and times.
class RouteSummary extends Equatable {
  const RouteSummary({
    required this.delivered,
    required this.failed,
    required this.traveledMeters,
    required this.start,
    required this.end,
  });

  /// [end] is when the route completed; the start is the plan's.
  factory RouteSummary.of(
    RoutePlan plan, {
    required int traveledMeters,
    required DateTime end,
  }) => RouteSummary(
    delivered: plan.stops
        .where((stop) => stop.result?.delivered == true)
        .length,
    failed: [
      for (final stop in plan.stops)
        if (stop.result?.delivered == false) stop,
    ],
    traveledMeters: traveledMeters,
    start: plan.startedAt,
    end: end,
  );

  final int delivered;

  /// The stops not delivered, in stop order.
  final List<RouteStop> failed;

  final int traveledMeters;

  /// Null for a route saved without its start.
  final DateTime? start;
  final DateTime end;

  /// From the start to the [end]; null without a start.
  Duration? get duration => switch (start) {
    final start? => end.difference(start),
    null => null,
  };

  @override
  List<Object?> get props => [delivered, failed, traveledMeters, start, end];

  @override
  bool get stringify => true;
}

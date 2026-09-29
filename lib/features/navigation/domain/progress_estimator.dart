import 'package:equatable/equatable.dart';

import '../../../core/geo/geo_math.dart';
import '../../../core/geo/geo_point.dart';
import '../../route/domain/route_plan.dart';

/// What is left of the route when the position was taken ([at]): the next
/// stop, the distance and time to reach it and to finish the route.
class RouteProgress extends Equatable {
  const RouteProgress({
    required this.next,
    required this.toNextMeters,
    required this.toNextSeconds,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.at,
  });

  /// Null on the way back to the start of a round trip; [toNextMeters] and
  /// [toNextSeconds] are then what is left of it.
  final RouteStop? next;
  final int toNextMeters;
  final int toNextSeconds;

  /// Through the last unvisited stop and, on a round trip, back to the
  /// start; [toNextMeters] included.
  final int remainingMeters;
  final int remainingSeconds;

  final DateTime at;

  DateTime get nextArrival => at.add(Duration(seconds: toNextSeconds));

  DateTime get finalArrival => at.add(Duration(seconds: remainingSeconds));

  @override
  List<Object?> get props => [
    next,
    toNextMeters,
    toNextSeconds,
    remainingMeters,
    remainingSeconds,
    at,
  ];

  @override
  bool get stringify => true;
}

/// Progress from a position: the position is projected on the closest
/// segment of the leg that arrives at the next stop, and that leg's distance
/// and duration (Google's) are scaled by the share of its line still ahead.
/// The legs after it count in full, up to the last unvisited stop, and so
/// does the way back of a round trip. Once every stop of a round trip has a
/// result, the way back is the leg measured.
class ProgressEstimator {
  const ProgressEstimator();

  /// Null when every stop of a one-way route is visited or the plan does not
  /// know where its legs end (plans saved by app 0.1.0).
  RouteProgress? estimate(RoutePlan plan, GeoPoint position, DateTime at) {
    final returnLeg = plan.returnLeg;
    if (plan.isReturning && returnLeg != null) {
      return _measure(
        plan,
        position,
        at,
        next: null,
        leg: returnLeg,
        // The way back starts where the last stop leg ends.
        start: plan.legs.isEmpty ? 0 : plan.legs.last.endIndex,
      );
    }
    final nextIndex = plan.stops.indexWhere((stop) => !stop.visited);
    final lastIndex = plan.stops.lastIndexWhere((stop) => !stop.visited);
    // Legs belong to the last `legs.length` stops.
    final firstLegStop = plan.stops.length - plan.legs.length;
    final legIndex = nextIndex - firstLegStop;
    if (nextIndex < 0 || legIndex < 0) return null;
    return _measure(
      plan,
      position,
      at,
      next: plan.stops[nextIndex],
      leg: plan.legs[legIndex],
      start: legIndex == 0 ? 0 : plan.legs[legIndex - 1].endIndex,
      later: [
        ...plan.legs.sublist(legIndex + 1, lastIndex - firstLegStop + 1),
        ?returnLeg,
      ],
    );
  }

  /// [leg], whose line starts at [start] in the polyline, measured from
  /// [position], then [later] in full; null when the line is unknown.
  static RouteProgress? _measure(
    RoutePlan plan,
    GeoPoint position,
    DateTime at, {
    required RouteStop? next,
    required RouteLeg leg,
    required int? start,
    List<RouteLeg> later = const [],
  }) {
    final end = leg.endIndex;
    if (start == null ||
        end == null ||
        start > end ||
        end >= plan.polyline.length) {
      return null;
    }

    final ahead = _shareAhead(position, plan.polyline.sublist(start, end + 1));
    final toNextMeters = (leg.distanceMeters * ahead).round();
    final toNextSeconds = (leg.durationSeconds * ahead).round();
    return RouteProgress(
      next: next,
      toNextMeters: toNextMeters,
      toNextSeconds: toNextSeconds,
      remainingMeters: later.fold(
        toNextMeters,
        (sum, leg) => sum + leg.distanceMeters,
      ),
      remainingSeconds: later.fold(
        toNextSeconds,
        (sum, leg) => sum + leg.durationSeconds,
      ),
      at: at,
    );
  }

  /// Share (0..1) of [line]'s length ahead of [position] projected on the
  /// closest segment; the first of equally close segments wins. A line with
  /// no length is all behind.
  static double _shareAhead(GeoPoint position, List<GeoPoint> line) {
    final lengths = [
      for (var i = 1; i < line.length; i++)
        haversineMeters(line[i - 1], line[i]),
    ];
    final total = lengths.fold(0.0, (sum, length) => sum + length);
    if (total == 0) return 0;

    var closest = 0;
    var fraction = 0.0;
    var best = double.infinity;
    for (var i = 0; i < lengths.length; i++) {
      final projection = projectOntoSegment(position, line[i], line[i + 1]);
      if (projection.meters < best) {
        best = projection.meters;
        closest = i;
        fraction = projection.fraction;
      }
    }
    var ahead = lengths[closest] * (1 - fraction);
    for (var i = closest + 1; i < lengths.length; i++) {
      ahead += lengths[i];
    }
    return ahead / total;
  }
}

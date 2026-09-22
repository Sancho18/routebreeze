import '../../../core/geo/geo_math.dart';
import '../../addresses/domain/stop.dart';
import '../../location/domain/fix.dart';

/// Arrival at a stop (NAV-04): within [radiusMeters] great-circle distance,
/// counted only for fixes with accuracy of [maxAccuracyMeters] or better
/// (spec Assumptions: arrival accuracy gate).
class ArrivalDetector {
  ArrivalDetector({this.radiusMeters = 40, this.maxAccuracyMeters = 50});

  final double radiusMeters;
  final double maxAccuracyMeters;

  bool isArrived(Fix fix, Stop stop) =>
      fix.accuracyMeters <= maxAccuracyMeters &&
      haversineMeters(fix.point, stop.point) <= radiusMeters;
}

/// What to do with an off-route verdict.
enum RecalcDecision {
  /// Request a new route now.
  run,

  /// Not now: one is in flight (RECALC-07) or the interval has not passed
  /// (RECALC-03).
  wait,

  /// Offline: mark it pending and run when connectivity returns (RECALC-06).
  deferOffline,

  /// Not off-route.
  none,
}

/// Bounds recalculations: at most one in flight and at least [minInterval]
/// between two requests (RECALC-03, RECALC-06, RECALC-07).
class RecalcPolicy {
  RecalcPolicy({this.minInterval = const Duration(seconds: 20)});

  final Duration minInterval;

  RecalcDecision decide({
    required bool offRoute,
    required bool inFlight,
    required bool online,
    required DateTime now,
    DateTime? lastRecalcAt,
  }) {
    if (!offRoute) return RecalcDecision.none;
    if (inFlight) return RecalcDecision.wait;
    if (!online) return RecalcDecision.deferOffline;
    if (lastRecalcAt != null && now.difference(lastRecalcAt) < minInterval) {
      return RecalcDecision.wait;
    }
    return RecalcDecision.run;
  }
}

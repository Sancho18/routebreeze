import '../../../core/geo/geo_math.dart';
import '../../addresses/domain/stop.dart';
import '../../location/domain/fix.dart';

/// Arrival at a stop: within [radiusMeters] great-circle distance, counted
/// only for fixes with accuracy of [maxAccuracyMeters] or better.
class ArrivalDetector {
  ArrivalDetector({this.radiusMeters = 40, this.maxAccuracyMeters = 50});

  final double radiusMeters;
  final double maxAccuracyMeters;

  bool isArrived(Fix fix, Stop stop) =>
      fix.accuracyMeters <= maxAccuracyMeters &&
      haversineMeters(fix.point, stop.point) <= radiusMeters;
}

enum RecalcDecision {
  run,

  /// Not now: one is in flight or the interval has not passed.
  wait,

  /// Offline: mark it pending and run when connectivity returns.
  deferOffline,

  /// Not off-route.
  none,
}

/// Bounds recalculations: at most one in flight and at least [minInterval]
/// between two requests.
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

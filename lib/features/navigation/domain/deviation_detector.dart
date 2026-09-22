import '../../../core/geo/geo_math.dart';
import '../../../core/geo/geo_point.dart';
import '../../location/domain/fix.dart';

/// Off-route detection (RECALC-01, RECALC-02): the user is off-route after
/// [consecutive] accepted fixes in a row farther than [thresholdMeters] from
/// the active polyline. A fix with accuracy worse than [maxAccuracyMeters]
/// is ignored, as is a fix repeating the previous accepted timestamp
/// (edge case: the same fix arriving twice counts once).
class DeviationDetector {
  DeviationDetector({
    this.thresholdMeters = 50,
    this.consecutive = 3,
    this.maxAccuracyMeters = 30,
  });

  final double thresholdMeters;
  final int consecutive;
  final double maxAccuracyMeters;

  int _strikes = 0;
  DateTime? _lastAt;

  /// Accepted far fixes in a row so far.
  int get strikes => _strikes;

  /// Feeds one fix and returns true while the user is declared off-route.
  /// The verdict holds on further far fixes until [reset].
  bool feed(Fix fix, List<GeoPoint> polyline) {
    if (fix.accuracyMeters > maxAccuracyMeters || fix.at == _lastAt) {
      return _strikes >= consecutive;
    }
    _lastAt = fix.at;
    final far = distanceToPolylineMeters(fix.point, polyline) > thresholdMeters;
    _strikes = far ? _strikes + 1 : 0;
    return _strikes >= consecutive;
  }

  /// Clears the strike count (after each recalculation).
  void reset() {
    _strikes = 0;
  }
}

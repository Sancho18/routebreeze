import '../../../core/geo/geo_math.dart';
import '../../../core/geo/geo_point.dart';
import '../../location/domain/fix.dart';

/// Off route after [consecutive] fixes in a row beyond [thresholdMeters] of
/// the polyline. Fixes worse than [maxAccuracyMeters], or the same fix
/// delivered twice, are ignored.
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

  int get strikes => _strikes;

  /// True while off route; an ignored fix returns false and keeps the strikes.
  bool feed(Fix fix, List<GeoPoint> polyline) {
    if (fix.accuracyMeters > maxAccuracyMeters || fix.at == _lastAt) {
      return false;
    }
    _lastAt = fix.at;
    final far = distanceToPolylineMeters(fix.point, polyline) > thresholdMeters;
    _strikes = far ? _strikes + 1 : 0;
    return _strikes >= consecutive;
  }

  void reset() {
    _strikes = 0;
  }
}

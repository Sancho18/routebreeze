import '../../../core/geo/geo_math.dart';
import '../../../core/geo/geo_point.dart';
import '../../location/domain/fix.dart';

/// Distance traveled, on top of the [meters] it starts from: the straight
/// segments between consecutive fixes of [maxAccuracyMeters] or better. A
/// worse fix is skipped and the next precise one connects to the last
/// precise one.
class Odometer {
  Odometer({int meters = 0, this.maxAccuracyMeters = 30})
    : _meters = meters.toDouble();

  final double maxAccuracyMeters;

  double _meters;
  GeoPoint? _last;

  int get meters => _meters.round();

  void add(Fix fix) {
    if (fix.accuracyMeters > maxAccuracyMeters) return;
    final last = _last;
    if (last != null) _meters += haversineMeters(last, fix.point);
    _last = fix.point;
  }
}

import 'package:equatable/equatable.dart';

import '../../../core/geo/geo_point.dart';

/// One GPS reading: position, horizontal accuracy and when it was taken.
class Fix extends Equatable {
  const Fix(this.point, this.accuracyMeters, this.at);

  final GeoPoint point;
  final double accuracyMeters;
  final DateTime at;

  @override
  List<Object?> get props => [point, accuracyMeters, at];

  @override
  bool get stringify => true;
}

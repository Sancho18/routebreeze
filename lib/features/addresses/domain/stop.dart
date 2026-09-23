import 'package:equatable/equatable.dart';

import '../../../core/geo/geo_point.dart';

/// A resolved delivery address (Place Details result).
class Stop extends Equatable {
  const Stop(this.placeId, this.address, this.point);

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
    json['placeId'] as String,
    json['address'] as String,
    GeoPoint.fromJson(json['point'] as Map<String, dynamic>),
  );

  final String placeId;
  final String address;
  final GeoPoint point;

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'address': address,
    'point': point.toJson(),
  };

  @override
  List<Object?> get props => [placeId, address, point];

  @override
  bool get stringify => true;
}

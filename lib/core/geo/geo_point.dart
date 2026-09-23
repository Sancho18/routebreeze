import 'package:equatable/equatable.dart';

/// A WGS84 coordinate in decimal degrees.
class GeoPoint extends Equatable {
  const GeoPoint(this.lat, this.lng);

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    (json['lat'] as num).toDouble(),
    (json['lng'] as num).toDouble(),
  );

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  List<Object?> get props => [lat, lng];

  @override
  bool get stringify => true;
}

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/geo/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../domain/route_plan.dart';
import '../domain/route_planner.dart';

/// The parts of a `computeRoutes` answer the app uses.
class RouteResponse extends Equatable {
  const RouteResponse({
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.legs,
    required this.optimizedIndex,
  });

  final String encodedPolyline;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteLeg> legs;

  /// `optimizedIntermediateWaypointIndex`; null without intermediates.
  final List<int>? optimizedIndex;

  @override
  List<Object?> get props => [
    encodedPolyline,
    distanceMeters,
    durationSeconds,
    legs,
    optimizedIndex,
  ];

  @override
  bool get stringify => true;
}

/// Routes API `computeRoutes`. Throws a `Failure` on transport or HTTP errors
/// and on an unusable answer.
abstract class RoutesApi {
  Future<RouteResponse> computeRoutes(RouteRequest request);
}

class RoutesApiImpl implements RoutesApi {
  RoutesApiImpl(this._dio);

  final Dio _dio;

  static const String url =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  static const String fieldMask =
      'routes.duration,routes.distanceMeters,'
      'routes.polyline.encodedPolyline,routes.legs.distanceMeters,'
      'routes.legs.duration,routes.optimizedIntermediateWaypointIndex';

  static const Failure invalidResponse = ApiFailure(
    null,
    'Resposta inválida da Routes API',
  );

  @override
  Future<RouteResponse> computeRoutes(RouteRequest request) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        url,
        data: _body(request),
        options: Options(headers: {'X-Goog-FieldMask': fieldMask}),
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
    return _parse(response.data, request.intermediates.length + 1);
  }

  static Map<String, dynamic> _body(RouteRequest request) => {
    'origin': _waypoint(request.origin),
    'destination': _waypoint(request.destination.point),
    if (request.intermediates.isNotEmpty) ...{
      'intermediates': [
        for (final stop in request.intermediates) _waypoint(stop.point),
      ],
      'optimizeWaypointOrder': true,
    },
    'travelMode': 'DRIVE',
    'languageCode': 'pt-BR',
    'regionCode': 'br',
    'units': 'METRIC',
  };

  static Map<String, dynamic> _waypoint(GeoPoint point) => {
    'location': {
      'latLng': {'latitude': point.lat, 'longitude': point.lng},
    },
  };

  /// The first route must carry exactly [expectedLegs] legs (intermediates
  /// + 1), numeric totals and, when present, an optimized index that is a
  /// permutation of the intermediates; anything else is a failed request.
  static RouteResponse _parse(Map<String, dynamic>? data, int expectedLegs) {
    final routes = data?['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw invalidResponse;
    }
    final route = routes.first as Map;
    final legs = route['legs'];
    if (legs is! List || legs.length != expectedLegs) throw invalidResponse;
    final polyline = route['polyline'];
    final encoded = polyline is Map ? polyline['encodedPolyline'] : null;
    if (encoded is! String || encoded.isEmpty) throw invalidResponse;
    final optimized = route['optimizedIntermediateWaypointIndex'];
    return RouteResponse(
      encodedPolyline: encoded,
      distanceMeters: _meters(route['distanceMeters']),
      durationSeconds: _seconds(route['duration']),
      legs: [
        for (final leg in legs)
          if (leg is Map)
            RouteLeg(
              distanceMeters: _meters(leg['distanceMeters']),
              durationSeconds: _seconds(leg['duration']),
            )
          else
            throw invalidResponse,
      ],
      optimizedIndex: optimized is List
          ? _permutation(optimized, expectedLegs - 1)
          : null,
    );
  }

  static List<int> _permutation(List<Object?> index, int n) {
    final parsed = [
      for (final i in index)
        if (i is num) i.toInt() else throw invalidResponse,
    ];
    final valid =
        parsed.length == n &&
        parsed.toSet().length == n &&
        parsed.every((i) => i >= 0 && i < n);
    if (!valid) throw invalidResponse;
    return parsed;
  }

  /// Proto JSON omits zero values: absent → 0; anything but a number fails.
  static int _meters(Object? value) => switch (value) {
    null => 0,
    num v => v.toInt(),
    _ => throw invalidResponse,
  };

  /// `"605s"` (optionally fractional) → 605; absent → 0; anything else
  /// fails.
  static int _seconds(Object? value) {
    if (value == null) return 0;
    if (value is! String || !value.endsWith('s')) throw invalidResponse;
    final seconds = double.tryParse(value.substring(0, value.length - 1));
    if (seconds == null || !seconds.isFinite) throw invalidResponse;
    return seconds.round();
  }
}

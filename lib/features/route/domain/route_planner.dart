import 'package:equatable/equatable.dart';

import '../../../core/geo/geo_math.dart';
import '../../../core/geo/geo_point.dart';
import '../../addresses/domain/stop.dart';

/// What one `computeRoutes` call asks for: a fixed destination plus the
/// intermediates the API may reorder.
class RouteRequest extends Equatable {
  const RouteRequest({
    required this.origin,
    required this.intermediates,
    required this.destination,
  });

  final GeoPoint origin;
  final List<Stop> intermediates;
  final Stop destination;

  @override
  List<Object?> get props => [origin, intermediates, destination];

  @override
  bool get stringify => true;
}

/// Farthest-destination rule: the stop farthest from the origin is the
/// destination; every other stop is an intermediate. Used for the initial plan
/// and for recalculations over the unvisited stops.
class RoutePlanner {
  const RoutePlanner();

  RouteRequest buildRequest(GeoPoint origin, List<Stop> stops) {
    if (stops.isEmpty) {
      throw ArgumentError.value(stops, 'stops', 'must not be empty');
    }
    final destinationIndex = farthestIndex(origin, [
      for (final stop in stops) stop.point,
    ]);
    return RouteRequest(
      origin: origin,
      intermediates: [
        for (var i = 0; i < stops.length; i++)
          if (i != destinationIndex) stops[i],
      ],
      destination: stops[destinationIndex],
    );
  }

  /// Visiting order: intermediates as permuted by [optimizedIndex], then the
  /// destination. A missing index keeps the request order; a non-permutation
  /// throws, since a stop would be dropped or duplicated.
  List<Stop> order(RouteRequest request, List<int>? optimizedIndex) {
    if (optimizedIndex == null || optimizedIndex.isEmpty) {
      return [...request.intermediates, request.destination];
    }
    final n = request.intermediates.length;
    final valid =
        optimizedIndex.length == n &&
        optimizedIndex.toSet().length == n &&
        optimizedIndex.every((i) => i >= 0 && i < n);
    if (!valid) {
      throw ArgumentError.value(
        optimizedIndex,
        'optimizedIndex',
        'must be a permutation of 0..${n - 1}',
      );
    }
    return [
      for (final i in optimizedIndex) request.intermediates[i],
      request.destination,
    ];
  }
}

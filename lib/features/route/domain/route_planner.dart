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
    this.destinationStop,
  });

  final GeoPoint origin;
  final List<Stop> intermediates;
  final GeoPoint destination;

  /// The stop at [destination]; null when the route returns to the start.
  final Stop? destinationStop;

  @override
  List<Object?> get props => [
    origin,
    intermediates,
    destination,
    destinationStop,
  ];

  @override
  bool get stringify => true;
}

/// Farthest-destination rule: the stop farthest from the origin is the
/// destination; every other stop is an intermediate. With a point to return
/// to, that point is the destination and every stop an intermediate. Used for
/// the initial plan and for recalculations over the unvisited stops.
class RoutePlanner {
  const RoutePlanner();

  /// Without [returnTo], [stops] must not be empty; with it, no stops is the
  /// way back alone.
  RouteRequest buildRequest(
    GeoPoint origin,
    List<Stop> stops, {
    GeoPoint? returnTo,
  }) {
    if (returnTo != null) {
      return RouteRequest(
        origin: origin,
        intermediates: stops,
        destination: returnTo,
      );
    }
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
      destination: stops[destinationIndex].point,
      destinationStop: stops[destinationIndex],
    );
  }

  /// Visiting order: intermediates as permuted by [optimizedIndex], then the
  /// destination stop, if any. A missing index keeps the request order; a
  /// non-permutation throws, since a stop would be dropped or duplicated.
  List<Stop> order(RouteRequest request, List<int>? optimizedIndex) {
    if (optimizedIndex == null || optimizedIndex.isEmpty) {
      return [...request.intermediates, ?request.destinationStop];
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
      ?request.destinationStop,
    ];
  }
}

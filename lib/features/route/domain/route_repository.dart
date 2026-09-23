import '../../../core/geo/geo_point.dart';
import '../../../core/geo/polyline_codec.dart';
import '../../addresses/domain/stop.dart';
import '../data/route_storage.dart';
import '../data/routes_api.dart';
import 'route_plan.dart';
import 'route_planner.dart';

/// Computes, persists and restores the active route.
class RouteRepository {
  RouteRepository(
    this._api,
    this._storage, {
    this._planner = const RoutePlanner(),
    this._now = DateTime.now,
  });

  final RoutesApi _api;
  final RouteStorage _storage;
  final RoutePlanner _planner;
  final DateTime Function() _now;

  /// [keepVisited] stay first with their numbers; the new order is numbered
  /// after them (the initial plan is 1..N). The plan is saved before it is
  /// returned; a storage failure does not discard it.
  Future<RoutePlan> plan(
    GeoPoint origin,
    List<Stop> stops, {
    List<RouteStop> keepVisited = const [],
  }) async {
    final request = _planner.buildRequest(origin, stops);
    final response = await _api.computeRoutes(request);
    final ordered = _planner.order(request, response.optimizedIndex);
    final plan = RoutePlan(
      origin: origin,
      stops: [
        ...keepVisited,
        for (var i = 0; i < ordered.length; i++)
          RouteStop(
            stop: ordered[i],
            order: keepVisited.length + i + 1,
            visited: false,
          ),
      ],
      polyline: decodePolyline(response.encodedPolyline),
      distanceMeters: response.distanceMeters,
      durationSeconds: response.durationSeconds,
      legs: response.legs,
      computedAt: _now(),
    );
    try {
      await _storage.save(plan);
    } on Object {
      // The route was already computed (and billed); persistence is best
      // effort here, as in MapCubit's restore.
    }
    return plan;
  }

  Future<void> save(RoutePlan plan) => _storage.save(plan);

  Future<RoutePlan?> loadActive() => _storage.load();

  Future<void> clear() => _storage.clear();
}

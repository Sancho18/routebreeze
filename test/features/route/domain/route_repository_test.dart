import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/data/route_storage.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_planner.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

class MockRoutesApi extends Mock implements RoutesApi {}

class MockRouteStorage extends Mock implements RouteStorage {}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  // Distances from origin: near ≈ 0.6 km, mid ≈ 6 km, far ≈ 20 km.
  const near = Stop('near', 'Rua Perto, 1', GeoPoint(-23.565, -46.66));
  const mid = Stop('mid', 'Rua Meio, 2', GeoPoint(-23.60, -46.70));
  const far = Stop('far', 'Rua Longe, 3', GeoPoint(-23.70, -46.80));
  const decoded = [
    GeoPoint(38.5, -120.2),
    GeoPoint(40.7, -120.95),
    GeoPoint(43.252, -126.453),
    GeoPoint(44, -127),
  ];
  const legs = [
    RouteLeg(distanceMeters: 4000, durationSeconds: 200, endIndex: 1),
    RouteLeg(distanceMeters: 4345, durationSeconds: 205, endIndex: 2),
    RouteLeg(distanceMeters: 4000, durationSeconds: 200, endIndex: 3),
  ];
  final now = DateTime.utc(2026, 9, 22, 10, 30);

  late MockRoutesApi api;
  late MockRouteStorage storage;
  late RouteRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const RouteRequest(
        origin: origin,
        intermediates: [],
        destination: origin,
      ),
    );
    registerFallbackValue(
      RoutePlan(
        origin: origin,
        stops: const [],
        polyline: const [],
        distanceMeters: 0,
        durationSeconds: 0,
        legs: const [],
        computedAt: DateTime.utc(2026),
      ),
    );
  });

  setUp(() {
    api = MockRoutesApi();
    storage = MockRouteStorage();
    repository = RouteRepository(api, storage, now: () => now);
    when(() => storage.save(any())).thenAnswer((_) async {});
    when(() => storage.clear()).thenAnswer((_) async {});
  });

  group('plan', () {
    test('calls the API once with the planner request and returns the '
        'ordered plan numbered 1..N with the route geometry and the leg ends, '
        'saved', () async {
      when(() => api.computeRoutes(any())).thenAnswer(
        (_) async => const RouteResponse(
          polyline: decoded,
          distanceMeters: 12345,
          durationSeconds: 605,
          legs: legs,
          optimizedIndex: [1, 0],
        ),
      );

      final plan = await repository.plan(origin, const [mid, far, near]);

      final expected = RoutePlan(
        origin: origin,
        stops: const [
          RouteStop(stop: near, order: 1),
          RouteStop(stop: mid, order: 2),
          RouteStop(stop: far, order: 3),
        ],
        polyline: decoded,
        distanceMeters: 12345,
        durationSeconds: 605,
        legs: legs,
        computedAt: now,
      );
      expect(plan, expected);
      final sent = verify(() => api.computeRoutes(captureAny())).captured;
      expect(sent, [
        RouteRequest(
          origin: origin,
          intermediates: const [mid, near],
          destination: far.point,
          destinationStop: far,
        ),
      ]);
      expect(verify(() => storage.save(captureAny())).captured, [expected]);
    });

    test('keeps visited stops with their numbers and numbers the new order '
        'after them, requesting only the unvisited stops', () async {
      when(() => api.computeRoutes(any())).thenAnswer(
        (_) async => const RouteResponse(
          polyline: decoded,
          distanceMeters: 8000,
          durationSeconds: 400,
          legs: [
            RouteLeg(distanceMeters: 4000, durationSeconds: 200),
            RouteLeg(distanceMeters: 4000, durationSeconds: 200),
          ],
          optimizedIndex: [0],
        ),
      );
      const visited = RouteStop(
        stop: near,
        order: 1,
        result: StopResult.delivered(),
      );
      const current = GeoPoint(-23.566, -46.661);

      final plan = await repository.plan(
        current,
        const [far, mid],
        keepVisited: const [visited],
      );

      expect(plan.stops, const [
        visited,
        RouteStop(stop: mid, order: 2),
        RouteStop(stop: far, order: 3),
      ]);
      expect(plan.origin, current);
      expect(plan.distanceMeters, 8000);
      expect(plan.durationSeconds, 400);
      final sent = verify(() => api.computeRoutes(captureAny())).captured;
      expect(sent, [
        RouteRequest(
          origin: current,
          intermediates: const [mid],
          destination: far.point,
          destinationStop: far,
        ),
      ]);
      expect(verify(() => storage.save(captureAny())).captured, [plan]);
    });

    test('an origin more than 50 km from every stop still sends one request '
        'and returns the ordered plan (edge case)', () async {
      // ≈ 80 km north of the nearest stop.
      const farOrigin = GeoPoint(-22.85, -46.6559);
      when(() => api.computeRoutes(any())).thenAnswer(
        (_) async => const RouteResponse(
          polyline: decoded,
          distanceMeters: 95000,
          durationSeconds: 5400,
          legs: legs,
          optimizedIndex: [1, 0],
        ),
      );

      final plan = await repository.plan(farOrigin, const [mid, far, near]);

      expect(plan.origin, farOrigin);
      expect(plan.stops.map((s) => s.stop), const [near, mid, far]);
      expect(plan.distanceMeters, 95000);
      verify(() => api.computeRoutes(any())).called(1);
    });

    test('a storage failure does not discard the computed plan', () async {
      when(() => api.computeRoutes(any())).thenAnswer(
        (_) async => const RouteResponse(
          polyline: decoded,
          distanceMeters: 12345,
          durationSeconds: 605,
          legs: legs,
          optimizedIndex: [1, 0],
        ),
      );
      when(() => storage.save(any())).thenThrow(Exception('disk full'));

      final plan = await repository.plan(origin, const [mid, far, near]);

      expect(plan.stops.map((s) => s.stop), const [near, mid, far]);
      expect(plan.polyline, decoded);
      verify(() => storage.save(plan)).called(1);
    });

    test('API failure propagates and nothing is saved', () async {
      when(() => api.computeRoutes(any()))
          .thenThrow(const ApiFailure(null, 'Resposta inválida da Routes API'));

      await expectLater(
        repository.plan(origin, const [mid, far, near]),
        throwsA(const ApiFailure(null, 'Resposta inválida da Routes API')),
      );
      verifyNever(() => storage.save(any()));
    });
  });

  group('persistence', () {
    final plan = RoutePlan(
      origin: origin,
      stops: const [RouteStop(stop: near, order: 1)],
      polyline: decoded,
      distanceMeters: 600,
      durationSeconds: 90,
      legs: const [RouteLeg(distanceMeters: 600, durationSeconds: 90)],
      computedAt: now,
    );

    test('save writes the plan to storage', () async {
      await repository.save(plan);

      expect(verify(() => storage.save(captureAny())).captured, [plan]);
    });

    test('loadActive returns the stored plan or null', () async {
      when(() => storage.load()).thenAnswer((_) async => plan);
      expect(await repository.loadActive(), plan);

      when(() => storage.load()).thenAnswer((_) async => null);
      expect(await repository.loadActive(), isNull);
    });

    test('clear removes the stored plan', () async {
      await repository.clear();

      verify(() => storage.clear()).called(1);
    });
  });
}

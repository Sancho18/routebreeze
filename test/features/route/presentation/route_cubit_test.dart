import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/presentation/route_cubit.dart';

class MockRouteRepository extends Mock implements RouteRepository {}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  const stops = [a, b];
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: a, order: 1, visited: false),
      RouteStop(stop: b, order: 2, visited: false),
    ],
    polyline: const [origin, GeoPoint(-23.60, -46.70)],
    distanceMeters: 6000,
    durationSeconds: 480,
    legs: const [
      RouteLeg(distanceMeters: 600, durationSeconds: 60),
      RouteLeg(distanceMeters: 5400, durationSeconds: 420),
    ],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );
  const failure = ApiFailure(null, 'Resposta inválida da Routes API');

  late MockRouteRepository repository;

  setUp(() {
    repository = MockRouteRepository();
  });

  test('starts idle without a plan or failure', () {
    expect(RouteCubit(repository).state, const RouteState());
    expect(RouteCubit(repository).state.status, RouteStatus.idle);
    expect(RouteCubit(repository).state.plan, isNull);
    expect(RouteCubit(repository).state.failure, isNull);
  });

  group('compute', () {
    blocTest<RouteCubit, RouteState>(
      'loading → ready with the plan from the repository (ROUTE-05, OFFL-03)',
      build: () {
        when(() => repository.plan(origin, stops))
            .thenAnswer((_) async => plan);
        return RouteCubit(repository);
      },
      act: (cubit) => cubit.compute(origin, stops),
      expect: () => [
        const RouteState(status: RouteStatus.loading),
        RouteState(status: RouteStatus.ready, plan: plan),
      ],
      verify: (_) => verify(() => repository.plan(origin, stops)).called(1),
    );

    blocTest<RouteCubit, RouteState>(
      'loading → failure when the request fails (ROUTE-06)',
      build: () {
        when(() => repository.plan(origin, stops)).thenThrow(failure);
        return RouteCubit(repository);
      },
      act: (cubit) => cubit.compute(origin, stops),
      expect: () => [
        const RouteState(status: RouteStatus.loading),
        const RouteState(status: RouteStatus.failure, failure: failure),
      ],
    );

    blocTest<RouteCubit, RouteState>(
      'loading → failure(Unknown) on an unexpected error (ROUTE-06)',
      build: () {
        when(() => repository.plan(origin, stops))
            .thenThrow(const FormatException('bad polyline'));
        return RouteCubit(repository);
      },
      act: (cubit) => cubit.compute(origin, stops),
      expect: () => [
        const RouteState(status: RouteStatus.loading),
        const RouteState(
          status: RouteStatus.failure,
          failure: Unknown(FormatException('bad polyline')),
        ),
      ],
    );
  });

  group('retry', () {
    blocTest<RouteCubit, RouteState>(
      're-runs the last request once: failure → loading → ready',
      build: () {
        var calls = 0;
        when(() => repository.plan(origin, stops)).thenAnswer((_) async {
          if (calls++ == 0) throw failure;
          return plan;
        });
        return RouteCubit(repository);
      },
      act: (cubit) async {
        await cubit.compute(origin, stops);
        await cubit.retry();
      },
      expect: () => [
        const RouteState(status: RouteStatus.loading),
        const RouteState(status: RouteStatus.failure, failure: failure),
        const RouteState(status: RouteStatus.loading),
        RouteState(status: RouteStatus.ready, plan: plan),
      ],
      verify: (_) => verify(() => repository.plan(origin, stops)).called(2),
    );

    blocTest<RouteCubit, RouteState>(
      'does nothing before the first compute',
      build: () => RouteCubit(repository),
      act: (cubit) => cubit.retry(),
      expect: () => const <RouteState>[],
      verify: (_) => verifyZeroInteractions(repository),
    );
  });
}

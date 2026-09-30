import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';
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
      RouteStop(stop: a, order: 1),
      RouteStop(stop: b, order: 2),
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
  const c = Stop('pc', 'Rua C, 3', GeoPoint(-23.58, -46.68));
  final ready = RouteState(status: RouteStatus.ready, plan: plan);

  RoutePlan savedWith(List<Stop> stops) => RoutePlan(
    origin: const GeoPoint(-23.58, -46.67),
    stops: [
      RouteStop(
        stop: stops.first,
        order: 1,
        result: StopResult.delivered(at: DateTime.utc(2026, 9, 22, 10, 50)),
      ),
      for (var i = 1; i < stops.length; i++)
        RouteStop(stop: stops[i], order: i + 1),
    ],
    polyline: const [GeoPoint(-23.58, -46.67), GeoPoint(-23.565, -46.66)],
    distanceMeters: 2500,
    durationSeconds: 300,
    legs: const [RouteLeg(distanceMeters: 2500, durationSeconds: 300)],
    computedAt: DateTime.utc(2026, 9, 22, 10, 45),
    startedAt: DateTime.utc(2026, 9, 22, 10, 35),
    traveledMeters: 850,
  );

  final roundTrip = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: a, order: 1),
      RouteStop(stop: b, order: 2),
    ],
    polyline: const [origin, GeoPoint(-23.60, -46.70), origin],
    distanceMeters: 11000,
    durationSeconds: 900,
    legs: const [
      RouteLeg(distanceMeters: 600, durationSeconds: 60, endIndex: 0),
      RouteLeg(distanceMeters: 5400, durationSeconds: 420, endIndex: 1),
    ],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
    returnTo: origin,
    returnLeg: const RouteLeg(
      distanceMeters: 5000,
      durationSeconds: 420,
      endIndex: 2,
    ),
  );

  late MockRouteRepository repository;

  setUpAll(() => registerFallbackValue(origin));

  setUp(() {
    repository = MockRouteRepository();
  });

  List<Object?> requestedReturns() => verify(
    () =>
        repository.plan(origin, stops, returnTo: captureAny(named: 'returnTo')),
  ).captured;

  test('starts idle without a plan or failure', () {
    expect(RouteCubit(repository).state, const RouteState());
    expect(RouteCubit(repository).state.status, RouteStatus.idle);
    expect(RouteCubit(repository).state.plan, isNull);
    expect(RouteCubit(repository).state.failure, isNull);
  });

  group('compute', () {
    blocTest<RouteCubit, RouteState>(
      'loading → ready with the plan from the repository',
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
      'loading → failure when the request fails',
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
      'loading → failure(Unknown) on an unexpected error',
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
          failure: Unknown('FormatException'),
        ),
      ],
    );

    blocTest<RouteCubit, RouteState>(
      'a round trip asks for a route back to the origin: loading → ready '
      'with the round trip',
      build: () {
        when(() => repository.plan(origin, stops, returnTo: origin))
            .thenAnswer((_) async => roundTrip);
        return RouteCubit(repository);
      },
      act: (cubit) => cubit.compute(origin, stops, roundTrip: true),
      expect: () => [
        const RouteState(status: RouteStatus.loading),
        RouteState(status: RouteStatus.ready, plan: roundTrip),
      ],
      verify: (_) => expect(requestedReturns(), [origin]),
    );

    for (final (name, flag) in [
      ('by default', null),
      ('with roundTrip false', false),
    ]) {
      blocTest<RouteCubit, RouteState>(
        'one-way $name: the request has no point of return',
        build: () {
          when(
            () => repository.plan(
              origin,
              stops,
              returnTo: any(named: 'returnTo'),
            ),
          ).thenAnswer((_) async => plan);
          return RouteCubit(repository);
        },
        act: (cubit) => flag == null
            ? cubit.compute(origin, stops)
            : cubit.compute(origin, stops, roundTrip: flag),
        expect: () => [
          const RouteState(status: RouteStatus.loading),
          RouteState(status: RouteStatus.ready, plan: plan),
        ],
        verify: (_) => expect(requestedReturns(), [null]),
      );
    }
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
      'repeats a round trip: the second request also returns to the origin',
      build: () {
        var calls = 0;
        when(
          () =>
              repository.plan(origin, stops, returnTo: any(named: 'returnTo')),
        ).thenAnswer((_) async {
          if (calls++ == 0) throw failure;
          return roundTrip;
        });
        return RouteCubit(repository);
      },
      act: (cubit) async {
        await cubit.compute(origin, stops, roundTrip: true);
        await cubit.retry();
      },
      expect: () => [
        const RouteState(status: RouteStatus.loading),
        const RouteState(status: RouteStatus.failure, failure: failure),
        const RouteState(status: RouteStatus.loading),
        RouteState(status: RouteStatus.ready, plan: roundTrip),
      ],
      verify: (_) => expect(requestedReturns(), [origin, origin]),
    );

    blocTest<RouteCubit, RouteState>(
      'does nothing before the first compute',
      build: () => RouteCubit(repository),
      act: (cubit) => cubit.retry(),
      expect: () => const <RouteState>[],
      verify: (_) => verifyZeroInteractions(repository),
    );
  });

  group('refreshFromSaved', () {
    // B first: a recalculation reordered the stops before B was delivered.
    final sameStops = savedWith(const [b, a]);

    blocTest<RouteCubit, RouteState>(
      'takes the saved route of the same stops, reordered, with its result, '
      'start and distance as the ready plan',
      build: () {
        when(() => repository.loadActive()).thenAnswer((_) async => sameStops);
        return RouteCubit(repository);
      },
      seed: () => ready,
      act: (cubit) => cubit.refreshFromSaved(),
      expect: () => [RouteState(status: RouteStatus.ready, plan: sameStops)],
      verify: (cubit) {
        final adopted = cubit.state.plan!;
        expect(adopted.stops.map((s) => s.stop), const [b, a]);
        expect(
          adopted.stops.first.result,
          StopResult.delivered(at: DateTime.utc(2026, 9, 22, 10, 50)),
        );
        expect(adopted.stops.last.result, isNull);
        expect(adopted.startedAt, DateTime.utc(2026, 9, 22, 10, 35));
        expect(adopted.traveledMeters, 850);
      },
    );

    for (final (name, stops) in [
      ('another stop in place of one of them', const [a, c]),
      ('one stop more', const [b, a, c]),
    ]) {
      blocTest<RouteCubit, RouteState>(
        'keeps the current plan when the saved route has $name',
        build: () {
          when(() => repository.loadActive())
              .thenAnswer((_) async => savedWith(stops));
          return RouteCubit(repository);
        },
        seed: () => ready,
        act: (cubit) => cubit.refreshFromSaved(),
        expect: () => const <RouteState>[],
        verify: (cubit) {
          verify(() => repository.loadActive()).called(1);
          expect(cubit.state, ready);
        },
      );
    }

    blocTest<RouteCubit, RouteState>(
      'takes the saved round trip of the same stops with its point of return '
      'and way back',
      build: () {
        when(() => repository.loadActive()).thenAnswer(
          (_) async => roundTrip.record(
            'pa',
            StopResult.delivered(at: DateTime.utc(2026, 9, 22, 10, 50)),
          ),
        );
        return RouteCubit(repository);
      },
      seed: () => RouteState(status: RouteStatus.ready, plan: roundTrip),
      act: (cubit) => cubit.refreshFromSaved(),
      verify: (cubit) {
        final adopted = cubit.state.plan!;
        expect(adopted.returnTo, origin);
        expect(
          adopted.returnLeg,
          const RouteLeg(
            distanceMeters: 5000,
            durationSeconds: 420,
            endIndex: 2,
          ),
        );
        expect(
          adopted.stops.first.result,
          StopResult.delivered(at: DateTime.utc(2026, 9, 22, 10, 50)),
        );
      },
    );

    blocTest<RouteCubit, RouteState>(
      'keeps the current plan when nothing is saved',
      build: () {
        when(() => repository.loadActive()).thenAnswer((_) async => null);
        return RouteCubit(repository);
      },
      seed: () => ready,
      act: (cubit) => cubit.refreshFromSaved(),
      expect: () => const <RouteState>[],
      verify: (cubit) {
        verify(() => repository.loadActive()).called(1);
        expect(cubit.state, ready);
      },
    );

    blocTest<RouteCubit, RouteState>(
      'does nothing before a plan exists',
      build: () {
        when(() => repository.loadActive()).thenAnswer((_) async => sameStops);
        return RouteCubit(repository);
      },
      act: (cubit) => cubit.refreshFromSaved(),
      expect: () => const <RouteState>[],
      verify: (cubit) {
        verifyZeroInteractions(repository);
        expect(cubit.state, const RouteState());
      },
    );
  });
}

import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/domain/route_summary.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

class MockLocationService extends Mock implements LocationService {}

class MockRouteRepository extends Mock implements RouteRepository {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  // Route along the equator: origin → A → B. A fix at latitude `lat(m)` is
  // `m` meters from the polyline (and from a stop on the same longitude).
  const origin = GeoPoint(0, -0.02);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(0, 0));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(0, 0.02));
  final t0 = DateTime.utc(2026, 9, 22, 10);
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: a, order: 1),
      RouteStop(stop: b, order: 2),
    ],
    polyline: const [origin, GeoPoint(0, 0), GeoPoint(0, 0.02)],
    distanceMeters: 4448,
    durationSeconds: 400,
    legs: const [
      RouteLeg(distanceMeters: 2224, durationSeconds: 200),
      RouteLeg(distanceMeters: 2224, durationSeconds: 200),
    ],
    computedAt: t0,
  );
  double lat(double meters) => meters / earthRadiusMeters * 180 / math.pi;
  final farPoint = GeoPoint(lat(120), -0.01);
  // South of the route and off the recalculated polyline as well (≈ 160 m).
  final farPoint2 = GeoPoint(lat(-120), 0.01);
  final recalculated = RoutePlan(
    origin: farPoint,
    stops: const [
      RouteStop(stop: b, order: 1),
      RouteStop(stop: a, order: 2),
    ],
    polyline: [farPoint, const GeoPoint(0, 0.02), const GeoPoint(0, 0)],
    distanceMeters: 5000,
    durationSeconds: 450,
    legs: const [],
    computedAt: t0.add(const Duration(minutes: 1)),
  );
  const failure = ApiFailure(null, 'Resposta inválida da Routes API');

  late MockLocationService location;
  late MockRouteRepository routes;
  late MockConnectivityService connectivity;
  late SessionState session;
  late StreamController<Fix> fixes;
  late StreamController<bool> online;
  var seq = 0;

  /// A fix with a fresh timestamp.
  Fix fix(GeoPoint point, {double accuracy = 10}) =>
      Fix(point, accuracy, t0.add(Duration(seconds: ++seq)));
  Fix onRoute({double accuracy = 10}) =>
      fix(const GeoPoint(0, -0.01), accuracy: accuracy);
  Fix far([GeoPoint? point]) => fix(point ?? farPoint);
  Fix atStop(Stop stop) => fix(GeoPoint(lat(30), stop.point.lng));

  setUpAll(() {
    registerFallbackValue(origin);
    registerFallbackValue(const <Stop>[]);
    registerFallbackValue(const <RouteStop>[]);
    registerFallbackValue(plan);
  });

  setUp(() {
    seq = 0;
    location = MockLocationService();
    routes = MockRouteRepository();
    connectivity = MockConnectivityService();
    session = SessionState();
    fixes = StreamController<Fix>.broadcast();
    online = StreamController<bool>.broadcast();
    when(() => location.watch(distanceFilterMeters: 5))
        .thenAnswer((_) => fixes.stream);
    when(() => connectivity.check()).thenAnswer((_) async => true);
    when(() => connectivity.isOnline).thenAnswer((_) => online.stream);
    when(() => routes.save(any())).thenAnswer((_) async {});
    when(() => routes.clear()).thenAnswer((_) async {});
  });

  void stubPlan(Object outcome) {
    final stub = when(
      () => routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
    );
    if (outcome is RoutePlan) {
      stub.thenAnswer((_) async => outcome);
    } else if (outcome is Completer<RoutePlan>) {
      stub.thenAnswer((_) => outcome.future);
    } else {
      stub.thenThrow(outcome);
    }
  }

  /// Builds the cubit inside the fake zone with its clock on `t0 + elapsed`.
  NavigationCubit build(FakeAsync async, [RoutePlan? initial]) =>
      NavigationCubit(
        plan: initial ?? plan,
        location: location,
        routes: routes,
        connectivity: connectivity,
        session: session,
        now: () => t0.add(async.elapsed),
      );

  void emitFix(FakeAsync async, Fix fix) {
    fixes.add(fix);
    async.flushMicrotasks();
  }

  /// "Iniciar" saves the plan with its start; that save is verified here, so
  /// a test sees only the saves that follow it.
  NavigationCubit navigating(FakeAsync async, [RoutePlan? initial]) {
    final cubit = build(async, initial)..prepare();
    async.flushMicrotasks();
    emitFix(async, onRoute());
    cubit.start();
    verify(() => routes.save(any()));
    return cubit;
  }

  void goOffRoute(FakeAsync async, [GeoPoint? point]) {
    for (var i = 0; i < 3; i++) {
      emitFix(async, far(point));
    }
  }

  test('starts idle with the plan, following and online', () {
    final cubit = NavigationCubit(
      plan: plan,
      location: location,
      routes: routes,
      connectivity: connectivity,
      session: session,
    );
    expect(cubit.state, NavigationState(plan: plan));
    expect(cubit.state.phase, NavigationPhase.idle);
    expect(cubit.state.canStart, isFalse);
  });

  group('prepare and start', () {
    test('waits for GPS: "Iniciar" needs a fix of 50 m or better '
        'and start subscribes with a 5 m filter', () {
      fakeAsync((async) {
        final cubit = build(async)..prepare();
        async.flushMicrotasks();

        expect(cubit.state.phase, NavigationPhase.waitingGps);
        expect(cubit.state.canStart, isFalse);
        verify(() => location.watch(distanceFilterMeters: 5)).called(1);

        final imprecise = onRoute(accuracy: 50.1);
        emitFix(async, imprecise);
        expect(cubit.state.fix, imprecise);
        expect(cubit.state.canStart, isFalse);
        cubit.start();
        expect(cubit.state.phase, NavigationPhase.waitingGps);
        expect(session.isNavigationActive, isFalse);

        final precise = onRoute(accuracy: 50);
        emitFix(async, precise);
        expect(cubit.state.fix, precise);
        expect(cubit.state.canStart, isTrue);

        cubit.start();
        expect(cubit.state.phase, NavigationPhase.navigating);
        expect(cubit.state.following, isTrue);
        expect(session.isNavigationActive, isTrue);
        cubit.close();
      });
    });

    test('seeds online from the connectivity check', () {
      when(() => connectivity.check()).thenAnswer((_) async => false);
      fakeAsync((async) {
        final cubit = build(async)..prepare();
        async.flushMicrotasks();

        expect(cubit.state.online, isFalse);
        cubit.close();
      });
    });
  });

  group('arrival', () {
    test('a fix of 10 m accuracy 30 m from the next stop sets arrived and '
        'records nothing; a later fix 100 m away keeps it', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        final before = cubit.state.plan;
        expect(cubit.state.arrived, isFalse);

        final arrival = atStop(a);
        emitFix(async, arrival);

        expect(cubit.state.fix, arrival);
        expect(cubit.state.arrived, isTrue);
        expect(cubit.state.plan, before);
        expect(cubit.state.plan.stops.map((s) => s.result), [null, null]);
        expect(cubit.state.plan.nextStop!.stop, a);
        expect(cubit.state.phase, NavigationPhase.navigating);

        final away = fix(GeoPoint(lat(100), a.point.lng));
        emitFix(async, away);

        expect(cubit.state.fix, away);
        expect(cubit.state.arrived, isTrue);
        expect(cubit.state.plan, before);
        verifyNever(() => routes.save(any()));
        cubit.close();
      });
    });

    test(
      'a fix 30 m from the next stop with accuracy 60 m does not arrive',
      () {
        fakeAsync((async) {
          final cubit = navigating(async);
          final before = cubit.state.plan;

          emitFix(async, fix(GeoPoint(lat(30), a.point.lng), accuracy: 60));

          expect(cubit.state.arrived, isFalse);
          expect(cubit.state.plan, before);
          cubit.close();
        });
      },
    );

    test('fixes at the next stop skip the off-route check: three at a stop '
        '60 m from the line make no request', () {
      final offLine = RoutePlan(
        origin: origin,
        stops: plan.stops,
        polyline: [
          for (final point in plan.polyline) GeoPoint(lat(-60), point.lng),
        ],
        distanceMeters: plan.distanceMeters,
        durationSeconds: plan.durationSeconds,
        legs: plan.legs,
        computedAt: t0,
      );
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async, offLine);

        for (var i = 0; i < 3; i++) {
          emitFix(async, fix(a.point));
        }

        expect(cubit.state.arrived, isTrue);
        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.badge, isNull);
        cubit.close();
      });
    });

    test('recording a result clears arrived', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        emitFix(async, atStop(a));
        expect(cubit.state.arrived, isTrue);

        cubit.recordDelivered();
        async.flushMicrotasks();

        expect(cubit.state.arrived, isFalse);
        expect(cubit.state.plan.nextStop!.stop, b);
        cubit.close();
      });
    });

    test('while arrived, three fixes off the route and away from the stop '
        'request nothing and keep arrived; after a result the same fixes '
        'recalculate', () {
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async);
        emitFix(async, atStop(a));
        expect(cubit.state.arrived, isTrue);
        // 120 m from the line and from A: off the route, not at the stop.
        final walking = GeoPoint(lat(120), a.point.lng);

        for (var i = 0; i < 3; i++) {
          emitFix(async, fix(walking));
        }

        expect(cubit.state.arrived, isTrue);
        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.badge, isNull);
        expect(cubit.state.plan.nextStop!.stop, a);

        cubit.recordDelivered();
        async.flushMicrotasks();
        for (var i = 0; i < 3; i++) {
          emitFix(async, fix(walking));
        }

        verify(
          () => routes.plan(
            walking,
            [b],
            keepVisited: [
              RouteStop(
                stop: a,
                order: 1,
                result: StopResult.delivered(at: t0),
              ),
            ],
          ),
        ).called(1);
        expect(cubit.state.badge, NavigationBadge.recalculated);
        cubit.close();
      });
    });

    test('arrival drops a recalculation deferred offline with its badge: '
        'reconnecting requests nothing; after a result, off-route fixes '
        'recalculate again', () {
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async);
        online.add(false);
        async.flushMicrotasks();
        goOffRoute(async);
        expect(cubit.state.recalcPending, isTrue);
        expect(cubit.state.badge, NavigationBadge.recalcPending);

        emitFix(async, atStop(a));

        expect(cubit.state.arrived, isTrue);
        expect(cubit.state.recalcPending, isFalse);
        expect(cubit.state.badge, isNull);

        online.add(true);
        async.flushMicrotasks();

        expect(cubit.state.online, isTrue);
        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.recalcPending, isFalse);
        expect(cubit.state.badge, isNull);
        expect(cubit.state.arrived, isTrue);
        expect(cubit.state.plan.nextStop!.stop, a);

        cubit.recordDelivered();
        async.flushMicrotasks();
        // 120 m from the line and from A: off the route, not at the stop.
        final walking = GeoPoint(lat(120), a.point.lng);
        for (var i = 0; i < 3; i++) {
          emitFix(async, fix(walking));
        }

        verify(
          () => routes.plan(
            walking,
            [b],
            keepVisited: [
              RouteStop(
                stop: a,
                order: 1,
                result: StopResult.delivered(at: t0),
              ),
            ],
          ),
        ).called(1);
        expect(cubit.state.badge, NavigationBadge.recalculated);
        cubit.close();
      });
    });

    test('an answer in flight at arrival that makes another stop next '
        'clears arrived', () {
      fakeAsync((async) {
        final pending = Completer<RoutePlan>();
        stubPlan(pending);
        final cubit = navigating(async);
        goOffRoute(async);
        expect(cubit.state.recalcInFlight, isTrue);
        emitFix(async, atStop(a));
        expect(cubit.state.arrived, isTrue);

        pending.complete(recalculated);
        async.flushMicrotasks();

        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.plan.polyline, recalculated.polyline);
        expect(cubit.state.plan.nextStop!.stop, b);
        expect(cubit.state.arrived, isFalse);
        cubit.close();
      });
    });

    test('an answer in flight at arrival that keeps the same next stop '
        'keeps arrived', () {
      final sameNext = RoutePlan(
        origin: farPoint,
        stops: const [
          RouteStop(stop: a, order: 1),
          RouteStop(stop: b, order: 2),
        ],
        polyline: [farPoint, const GeoPoint(0, 0), const GeoPoint(0, 0.02)],
        distanceMeters: 4600,
        durationSeconds: 420,
        legs: const [],
        computedAt: t0.add(const Duration(minutes: 1)),
      );
      fakeAsync((async) {
        final pending = Completer<RoutePlan>();
        stubPlan(pending);
        final cubit = navigating(async);
        goOffRoute(async);
        expect(cubit.state.recalcInFlight, isTrue);
        emitFix(async, atStop(a));
        expect(cubit.state.arrived, isTrue);

        pending.complete(sameNext);
        async.flushMicrotasks();

        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.plan.polyline, sameNext.polyline);
        expect(cubit.state.plan.nextStop!.stop, a);
        expect(cubit.state.arrived, isTrue);
        cubit.close();
      });
    });
  });

  group('results', () {
    // A third stop so that two results leave the route unfinished.
    const c = Stop('pc', 'Rua C, 3', GeoPoint(0, 0.04));
    final three = RoutePlan(
      origin: origin,
      stops: const [
        RouteStop(stop: a, order: 1),
        RouteStop(stop: b, order: 2),
        RouteStop(stop: c, order: 3),
      ],
      polyline: const [
        origin,
        GeoPoint(0, 0),
        GeoPoint(0, 0.02),
        GeoPoint(0, 0.04),
      ],
      distanceMeters: 6672,
      durationSeconds: 600,
      legs: const [],
      computedAt: t0,
    );

    test('"Entregue" records the next stop as delivered at the clock time, '
        'makes the following one next and saves the plan with it', () {
      fakeAsync((async) {
        final cubit = navigating(async, three);
        async.elapse(const Duration(seconds: 5));

        cubit.recordDelivered();
        async.flushMicrotasks();

        final saved =
            verify(() => routes.save(captureAny())).captured.single
                as RoutePlan;
        expect(saved.stops.map((s) => s.result), [
          StopResult.delivered(at: t0.add(const Duration(seconds: 5))),
          null,
          null,
        ]);
        expect(cubit.state.plan, saved);
        expect(cubit.state.plan.nextStop!.stop, b);
        expect(cubit.state.phase, NavigationPhase.navigating);
        cubit.close();
      });
    });

    test('a reason records the next stop as not delivered with that reason '
        'at the clock time; the save carries every result so far', () {
      fakeAsync((async) {
        final cubit = navigating(async, three);
        async.elapse(const Duration(seconds: 5));
        cubit.recordDelivered();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));

        cubit.recordFailed(FailureReason.refused);
        async.flushMicrotasks();

        final results = [
          StopResult.delivered(at: t0.add(const Duration(seconds: 5))),
          StopResult.failed(
            FailureReason.refused,
            at: t0.add(const Duration(seconds: 7)),
          ),
          null,
        ];
        final saved = verify(() => routes.save(captureAny())).captured
            .cast<RoutePlan>();
        expect(saved, hasLength(2));
        expect(saved.last.stops.map((s) => s.result), results);
        expect(cubit.state.plan, saved.last);
        expect(cubit.state.plan.nextStop!.stop, c);
        cubit.close();
      });
    });

    test('a tap within 1 s of the previous result is ignored: at +999 ms '
        '"Entregue" and a reason record nothing, at +1000 ms the next stop '
        'is recorded', () {
      fakeAsync((async) {
        final cubit = navigating(async, three);
        cubit.recordDelivered();
        async.flushMicrotasks();
        final first = cubit.state.plan;

        async.elapse(const Duration(milliseconds: 999));
        cubit.recordDelivered();
        cubit.recordFailed(FailureReason.recipientAbsent);
        async.flushMicrotasks();

        expect(cubit.state.plan, first);
        expect(cubit.state.plan.nextStop!.stop, b);

        async.elapse(const Duration(milliseconds: 1));
        cubit.recordFailed(FailureReason.recipientAbsent);
        async.flushMicrotasks();

        expect(cubit.state.plan.stops.map((s) => s.result), [
          StopResult.delivered(at: t0),
          StopResult.failed(
            FailureReason.recipientAbsent,
            at: t0.add(const Duration(seconds: 1)),
          ),
          null,
        ]);
        expect(cubit.state.plan.nextStop!.stop, c);
        final saved = verify(() => routes.save(captureAny())).captured
            .cast<RoutePlan>();
        expect(saved, [first, cubit.state.plan]);
        cubit.close();
      });
    });

    test('the last result completes the route with its summary (counts, '
        'failed stops, meters, start, end at the last result): stream '
        'stopped, storage cleared, navigation active until close', () {
      final start = t0.subtract(const Duration(minutes: 30));
      final resumed = plan.withStart(start).withTraveled(850);
      fakeAsync((async) {
        final cubit = navigating(async, resumed);
        async.elapse(const Duration(seconds: 5));
        cubit.recordFailed(FailureReason.recipientAbsent);
        async.flushMicrotasks();
        expect(cubit.state.summary, isNull);
        async.elapse(const Duration(seconds: 5));

        cubit.recordDelivered();
        async.flushMicrotasks();

        expect(cubit.state.phase, NavigationPhase.completed);
        expect(cubit.state.plan.isComplete, isTrue);
        expect(
          cubit.state.summary,
          RouteSummary(
            delivered: 1,
            failed: [
              RouteStop(
                stop: a,
                order: 1,
                result: StopResult.failed(
                  FailureReason.recipientAbsent,
                  at: t0.add(const Duration(seconds: 5)),
                ),
              ),
            ],
            traveledMeters: 850,
            start: start,
            end: t0.add(const Duration(seconds: 10)),
          ),
        );
        expect(fixes.hasListener, isFalse);
        verify(() => routes.clear()).called(1);
        verify(() => routes.save(any())).called(1);
        expect(session.isNavigationActive, isTrue);

        cubit.close();
        async.flushMicrotasks();

        expect(session.isNavigationActive, isFalse);
      });
    });
  });

  group('distance and start', () {
    // Fixes 0.001° apart on the equator are 111.2 m apart.
    Fix east(double lng) => fix(GeoPoint(0, lng));

    test('no distance while waiting for GPS: only fixes after "Iniciar" '
        'count', () {
      fakeAsync((async) {
        final cubit = build(async)..prepare();
        async.flushMicrotasks();
        emitFix(async, east(-0.013));
        emitFix(async, east(-0.012));
        emitFix(async, east(-0.011));
        cubit.start();
        emitFix(async, east(-0.010));
        emitFix(async, east(-0.009));

        cubit.pause();
        async.flushMicrotasks();

        final saved = verify(() => routes.save(captureAny())).captured
            .cast<RoutePlan>();
        expect(saved.map((p) => p.traveledMeters), [0, 111]);
        cubit.close();
      });
    });

    test('"Iniciar" stamps the start at the clock time and saves it; a '
        'result, pause and "Encerrar" save the start with the distance; '
        'fixes alone write nothing', () {
      fakeAsync((async) {
        final cubit = build(async)..prepare();
        async.flushMicrotasks();
        emitFix(async, onRoute());
        async.elapse(const Duration(seconds: 5));

        cubit.start();
        async.flushMicrotasks();

        final started = t0.add(const Duration(seconds: 5));
        expect(cubit.state.plan.startedAt, started);
        expect(
          verify(() => routes.save(captureAny())).captured.single,
          plan.withStart(started),
        );
        final afterStart = cubit.state.plan;

        emitFix(async, east(-0.009));
        emitFix(async, east(-0.008));
        verifyNever(() => routes.save(any()));
        expect(cubit.state.plan, afterStart);

        async.elapse(const Duration(minutes: 1));
        cubit.recordDelivered();
        async.flushMicrotasks();
        final delivered = plan
            .withStart(started)
            .record(
              'pa',
              StopResult.delivered(at: t0.add(const Duration(seconds: 65))),
            );
        expect(
          verify(() => routes.save(captureAny())).captured.single,
          delivered.withTraveled(111),
        );

        emitFix(async, east(-0.007));
        cubit.pause();
        async.flushMicrotasks();
        expect(
          verify(() => routes.save(captureAny())).captured.single,
          delivered.withTraveled(222),
        );

        cubit.resume();
        emitFix(async, east(-0.006));
        cubit.stop();
        async.flushMicrotasks();
        expect(
          verify(() => routes.save(captureAny())).captured.single,
          delivered.withTraveled(334),
        );
        cubit.close();
      });
    });

    test('a cubit built from a saved plan keeps its first start and '
        'continues its distance up to the summary; background after the end '
        'saves nothing', () {
      final first = t0.subtract(const Duration(hours: 1));
      final resumed = plan.withStart(first).withTraveled(850);
      fakeAsync((async) {
        final cubit = navigating(async, resumed);
        expect(cubit.state.plan.startedAt, first);

        emitFix(async, east(-0.009));
        emitFix(async, east(-0.008));
        cubit.recordDelivered();
        async.flushMicrotasks();

        final saved =
            verify(() => routes.save(captureAny())).captured.single
                as RoutePlan;
        expect(saved.startedAt, first);
        expect(saved.traveledMeters, 961);

        async.elapse(NavigationCubit.recordGuard);
        cubit.recordDelivered();
        async.flushMicrotasks();

        expect(
          cubit.state.summary,
          RouteSummary(
            delivered: 2,
            failed: const [],
            traveledMeters: 961,
            start: first,
            end: t0.add(NavigationCubit.recordGuard),
          ),
        );

        cubit.pause();
        async.flushMicrotasks();
        verifyNever(() => routes.save(any()));
        cubit.close();
      });
    });
  });

  group('recalculation', () {
    test('3 far fixes → one request from the current position through the '
        'unvisited stops; the plan is replaced and "Rota recalculada" '
        'shows for 4 s', () {
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async);

        emitFix(async, far());
        emitFix(async, far());
        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );
        expect(cubit.state.badge, isNull);

        emitFix(async, far());

        verify(
          () => routes.plan(farPoint, [a, b], keepVisited: const <RouteStop>[]),
        ).called(1);
        expect(cubit.state.plan, recalculated.withStart(t0));
        expect(cubit.state.plan.polyline, recalculated.polyline);
        expect(cubit.state.plan.stops.map((s) => s.stop), [b, a]);
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.lastRecalcAt, t0.add(async.elapsed));
        expect(cubit.state.badge, NavigationBadge.recalculated);
        expect(cubit.state.badge!.kind, BadgeKind.recalculated);
        expect(cubit.state.badge!.text, 'Rota recalculada');

        async.elapse(const Duration(seconds: 3));
        expect(cubit.state.badge, NavigationBadge.recalculated);
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.badge, isNull);
        expect(cubit.state.plan, recalculated.withStart(t0));
        cubit.close();
      });
    });

    test(
      'visited stops are kept and only the unvisited ones are requested',
      () {
        stubPlan(recalculated);
        fakeAsync((async) {
          final cubit = navigating(async);
          cubit.recordDelivered();
          async.flushMicrotasks();

          goOffRoute(async);

          verify(
            () => routes.plan(
              farPoint,
              [b],
              keepVisited: [
                RouteStop(
                  stop: a,
                  order: 1,
                  result: StopResult.delivered(at: t0),
                ),
              ],
            ),
          ).called(1);
          cubit.close();
        });
      },
    );

    test('a failed request keeps the plan and shows "Falha ao recalcular" '
        'for 4 s; a new attempt is allowed after 20 s', () {
      stubPlan(failure);
      fakeAsync((async) {
        final cubit = navigating(async);

        goOffRoute(async);

        verify(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        ).called(1);
        expect(cubit.state.plan, plan.withStart(t0));
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.badge, NavigationBadge.recalcFailed);
        expect(cubit.state.badge!.kind, BadgeKind.recalcFailed);
        expect(cubit.state.badge!.text, 'Falha ao recalcular');

        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.badge, isNull);
        expect(cubit.state.plan, plan.withStart(t0));

        async.elapse(const Duration(seconds: 15));
        emitFix(async, far());
        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );

        async.elapse(const Duration(seconds: 1));
        emitFix(async, far());
        verify(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        ).called(1);
        cubit.close();
      });
    });

    test('a second deviation within 20 s of the last recalculation makes no '
        'request; after 20 s it does', () {
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async);
        goOffRoute(async);
        verify(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        ).called(1);

        async.elapse(const Duration(seconds: 10));
        goOffRoute(async, farPoint2);
        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );

        async.elapse(const Duration(seconds: 10));
        emitFix(async, far(farPoint2));
        verify(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        ).called(1);
        cubit.close();
      });
    });

    test('no second request while one is in flight', () {
      fakeAsync((async) {
        final pending = Completer<RoutePlan>();
        stubPlan(pending);
        final cubit = navigating(async);
        goOffRoute(async);
        expect(cubit.state.recalcInFlight, isTrue);

        goOffRoute(async);

        verify(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        ).called(1);
        expect(cubit.state.plan, plan.withStart(t0));

        pending.complete(recalculated);
        async.flushMicrotasks();
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.plan, recalculated.withStart(t0));
        cubit.close();
      });
    });

    test('offline: "Recálculo pendente (sem conexão)" without a request, '
        'then the recalculation runs on reconnect', () {
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async);
        online.add(false);
        async.flushMicrotasks();
        expect(cubit.state.online, isFalse);

        goOffRoute(async);

        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );
        expect(cubit.state.recalcPending, isTrue);
        expect(cubit.state.badge, NavigationBadge.recalcPending);
        expect(cubit.state.badge!.kind, BadgeKind.recalcPending);
        expect(cubit.state.badge!.text, 'Recálculo pendente (sem conexão)');
        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.badge, NavigationBadge.recalcPending);
        expect(cubit.state.plan, plan.withStart(t0));

        online.add(true);
        async.flushMicrotasks();

        expect(cubit.state.online, isTrue);
        verify(
          () => routes.plan(farPoint, [a, b], keepVisited: const <RouteStop>[]),
        ).called(1);
        expect(cubit.state.recalcPending, isFalse);
        expect(cubit.state.plan, recalculated.withStart(t0));
        expect(cubit.state.badge, NavigationBadge.recalculated);
        cubit.close();
      });
    });

    test('a stop visited while a recalculation is in flight stays visited '
        'in the replaced plan with its reason, the start and the current '
        'distance; "Encerrar" then saves them', () {
      final first = t0.subtract(const Duration(hours: 1));
      fakeAsync((async) {
        final pending = Completer<RoutePlan>();
        stubPlan(pending);
        final cubit = navigating(
          async,
          plan.withStart(first).withTraveled(850),
        );
        goOffRoute(async);
        expect(cubit.state.recalcInFlight, isTrue);

        async.elapse(const Duration(seconds: 5));
        cubit.recordFailed(FailureReason.addressNotFound);
        async.flushMicrotasks();
        expect(cubit.state.plan.stops[0].visited, isTrue);
        // 111 m after the result, still waiting for the answer.
        emitFix(async, fix(GeoPoint(lat(120), -0.009)));

        pending.complete(recalculated);
        async.flushMicrotasks();

        final kept = recalculated
            .record(
              'pa',
              StopResult.failed(
                FailureReason.addressNotFound,
                at: t0.add(const Duration(seconds: 5)),
              ),
            )
            .withStart(first)
            .withTraveled(961);
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.plan, kept);
        expect(cubit.state.plan.polyline, recalculated.polyline);
        expect(
          cubit.state.plan.stops.singleWhere((s) => s.stop == a).visited,
          isTrue,
        );
        expect(cubit.state.plan.unvisited.map((s) => s.stop), [b]);
        expect(cubit.state.plan.nextStop!.stop, b);
        final saved = verify(() => routes.save(captureAny())).captured
            .cast<RoutePlan>();
        expect(saved.last, cubit.state.plan);
        expect(
          saved.last.stops.singleWhere((s) => s.stop == a).visited,
          isTrue,
        );

        cubit.stop();
        async.flushMicrotasks();

        expect(verify(() => routes.save(captureAny())).captured.single, kept);
        cubit.close();
      });
    });

    test('completion during an in-flight recalculation is final: the stale '
        'plan is dropped and storage stays cleared', () {
      fakeAsync((async) {
        final pending = Completer<RoutePlan>();
        stubPlan(pending);
        final cubit = navigating(async);
        cubit.recordDelivered();
        async.flushMicrotasks();
        goOffRoute(async);
        expect(cubit.state.recalcInFlight, isTrue);
        async.elapse(NavigationCubit.recordGuard);

        cubit.recordDelivered();
        async.flushMicrotasks();
        expect(cubit.state.phase, NavigationPhase.completed);

        pending.complete(
          recalculated.record('pa', StopResult.delivered(at: t0)),
        );
        async.flushMicrotasks();

        expect(cubit.state.phase, NavigationPhase.completed);
        expect(cubit.state.plan.isComplete, isTrue);
        expect(cubit.state.badge, isNull);
        expect(cubit.state.recalcInFlight, isFalse);
        verify(() => routes.clear()).called(2);
        verify(() => routes.save(any())).called(1);
        cubit.close();
      });
    });

    test('a pending recalculation is dropped when the route completes: '
        'reconnecting makes no request', () {
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async);
        online.add(false);
        async.flushMicrotasks();
        goOffRoute(async);
        expect(cubit.state.recalcPending, isTrue);

        cubit.recordDelivered();
        async.flushMicrotasks();
        async.elapse(NavigationCubit.recordGuard);
        cubit.recordDelivered();
        async.flushMicrotasks();
        expect(cubit.state.phase, NavigationPhase.completed);
        expect(cubit.state.recalcPending, isFalse);
        expect(cubit.state.badge, isNull);

        online.add(true);
        async.flushMicrotasks();

        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );
        expect(cubit.state.badge, isNull);
        expect(cubit.state.phase, NavigationPhase.completed);
        expect(cubit.state.plan.isComplete, isTrue);
        cubit.close();
      });
    });

    test('an imprecise fix never triggers or seeds a recalculation: after a '
        'failure and 20 s, a 120 m fix makes no request and the next '
        'accepted fix is the origin', () {
      stubPlan(failure);
      fakeAsync((async) {
        final cubit = navigating(async);
        goOffRoute(async);
        verify(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        ).called(1);

        async.elapse(const Duration(seconds: 20));
        emitFix(async, fix(farPoint2, accuracy: 120));
        verifyNever(
          () =>
              routes.plan(any(), any(), keepVisited: any(named: 'keepVisited')),
        );

        emitFix(async, far(farPoint2));
        verify(
          () =>
              routes.plan(farPoint2, [a, b], keepVisited: const <RouteStop>[]),
        ).called(1);
        cubit.close();
      });
    });

    test('a pending recalculation starts from the last accepted fix, not '
        'from a later imprecise one', () {
      stubPlan(recalculated);
      fakeAsync((async) {
        final cubit = navigating(async);
        online.add(false);
        async.flushMicrotasks();
        goOffRoute(async);
        expect(cubit.state.recalcPending, isTrue);

        final imprecise = fix(farPoint2, accuracy: 120);
        emitFix(async, imprecise);
        expect(cubit.state.fix, imprecise);
        online.add(true);
        async.flushMicrotasks();

        verify(
          () => routes.plan(farPoint, [a, b], keepVisited: const <RouteStop>[]),
        ).called(1);
        cubit.close();
      });
    });
  });

  group('camera', () {
    test('dragging the map stops following; "Recentralizar" resumes it', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        expect(cubit.state.following, isTrue);

        cubit.onMapDragged();
        expect(cubit.state.following, isFalse);

        cubit.recenter();
        expect(cubit.state.following, isTrue);
        cubit.close();
      });
    });
  });

  group('lifecycle', () {
    test('pause cancels the position stream and keeps the state; resume '
        'resubscribes', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        final before = cubit.state;

        cubit.pause();
        expect(fixes.hasListener, isFalse);
        expect(cubit.state, before);
        expect(session.isNavigationActive, isTrue);

        cubit.resume();
        expect(fixes.hasListener, isTrue);
        verify(() => location.watch(distanceFilterMeters: 5)).called(2);
        final next = onRoute();
        emitFix(async, next);
        expect(cubit.state.fix, next);
        expect(cubit.state.phase, NavigationPhase.navigating);
        cubit.close();
      });
    });

    test('prepare hands pause/resume to the session for the lifecycle gate; '
        'stop clears them', () {
      fakeAsync((async) {
        final cubit = build(async);
        expect(session.onPause, isNull);
        expect(session.onResume, isNull);

        cubit.prepare();
        async.flushMicrotasks();
        expect(session.onPause, isNotNull);
        expect(session.onResume, isNotNull);

        session.onPause!();
        expect(fixes.hasListener, isFalse);
        session.onResume!();
        expect(fixes.hasListener, isTrue);

        cubit.stop();
        expect(session.onPause, isNull);
        expect(session.onResume, isNull);
        cubit.close();
      });
    });

    test('closing a stale cubit leaves the hooks and the active flag of a '
        'cubit prepared after it untouched', () {
      fakeAsync((async) {
        final first = build(async)..prepare();
        async.flushMicrotasks();
        final second = build(async)..prepare();
        async.flushMicrotasks();
        emitFix(async, onRoute());
        second.start();
        expect(session.isNavigationActive, isTrue);

        first.close();
        async.flushMicrotasks();

        expect(session.isNavigationActive, isTrue);
        expect(session.onPause, isNotNull);
        expect(session.onResume, isNotNull);
        session.onPause!();
        expect(fixes.hasListener, isFalse);
        session.onResume!();
        expect(fixes.hasListener, isTrue);
        expect(second.state.phase, NavigationPhase.navigating);

        second.close();
        async.flushMicrotasks();
        expect(session.onPause, isNull);
        expect(session.onResume, isNull);
        expect(session.isNavigationActive, isFalse);
      });
    });

    test('resume without a pause does not subscribe twice', () {
      fakeAsync((async) {
        final cubit = navigating(async);

        cubit.resume();

        verify(() => location.watch(distanceFilterMeters: 5)).called(1);
        cubit.close();
      });
    });

    test('"Encerrar" stops the streams and leaves the route intact', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        cubit.recordDelivered();
        async.flushMicrotasks();

        cubit.stop();

        expect(fixes.hasListener, isFalse);
        expect(online.hasListener, isFalse);
        expect(session.isNavigationActive, isFalse);
        expect(cubit.state.phase, NavigationPhase.idle);
        expect(cubit.state.plan.stops[0].visited, isTrue);
        verifyNever(() => routes.clear());
        cubit.close();
      });
    });

    test('"Encerrar" completes once the route is saved', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        final save = Completer<void>();
        when(() => routes.save(any())).thenAnswer((_) => save.future);
        var done = false;

        cubit.stop().then((_) => done = true);
        async.flushMicrotasks();

        expect(cubit.state.phase, NavigationPhase.idle);
        verify(() => routes.save(any())).called(1);
        expect(done, isFalse);

        save.complete();
        async.flushMicrotasks();
        expect(done, isTrue);
        cubit.close();
      });
    });

    test('close cancels everything', () {
      fakeAsync((async) {
        final cubit = navigating(async);

        cubit.close();
        async.flushMicrotasks();

        expect(fixes.hasListener, isFalse);
        expect(online.hasListener, isFalse);
        expect(session.isNavigationActive, isFalse);
        expect(session.onPause, isNull);
        expect(session.onResume, isNull);
      });
    });
  });

  group('stream error', () {
    test('shows "Perdemos o sinal de GPS" and keeps the last position', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        final last = cubit.state.fix;

        fixes.addError(StateError('gps off'));
        async.flushMicrotasks();

        expect(cubit.state.error, 'Perdemos o sinal de GPS');
        expect(cubit.state.fix, last);
        expect(cubit.state.phase, NavigationPhase.navigating);

        async.elapse(const Duration(seconds: 5));
        final next = onRoute();
        emitFix(async, next);
        expect(cubit.state.error, isNull);
        expect(cubit.state.fix, next);
        cubit.close();
      });
    });

    test('after a stream error the position stream is resubscribed once '
        '5 s later and the next fix clears the error', () {
      fakeAsync((async) {
        final cubit = navigating(async);

        fixes.addError(StateError('gps off'));
        async.flushMicrotasks();

        expect(cubit.state.error, 'Perdemos o sinal de GPS');
        expect(fixes.hasListener, isFalse);
        verify(() => location.watch(distanceFilterMeters: 5)).called(1);

        async.elapse(const Duration(seconds: 4));
        expect(fixes.hasListener, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(fixes.hasListener, isTrue);
        verify(() => location.watch(distanceFilterMeters: 5)).called(1);

        final next = onRoute();
        emitFix(async, next);
        expect(cubit.state.error, isNull);
        expect(cubit.state.fix, next);
        expect(cubit.state.phase, NavigationPhase.navigating);
        cubit.close();
      });
    });

    test('a stream error while waiting for GPS (before "Iniciar") shows the '
        'message and resubscribes 5 s later', () {
      fakeAsync((async) {
        final cubit = build(async)..prepare();
        async.flushMicrotasks();
        expect(cubit.state.phase, NavigationPhase.waitingGps);

        fixes.addError(StateError('gps off'));
        async.flushMicrotasks();

        expect(cubit.state.error, 'Perdemos o sinal de GPS');
        expect(cubit.state.phase, NavigationPhase.waitingGps);
        expect(cubit.state.canStart, isFalse);
        expect(fixes.hasListener, isFalse);

        async.elapse(const Duration(seconds: 5));
        expect(fixes.hasListener, isTrue);
        emitFix(async, onRoute());
        expect(cubit.state.error, isNull);
        expect(cubit.state.canStart, isTrue);
        cubit.close();
      });
    });

    test('a stream that ends is resubscribed on resume', () {
      fakeAsync((async) {
        final cubit = navigating(async);

        fixes.close();
        async.flushMicrotasks();
        expect(cubit.state.error, 'Perdemos o sinal de GPS');

        fixes = StreamController<Fix>.broadcast();
        cubit.resume();

        expect(fixes.hasListener, isTrue);
        verify(() => location.watch(distanceFilterMeters: 5)).called(2);
        cubit.close();
      });
    });

    test('resume after a stream error resubscribes at once', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        fixes.addError(StateError('gps off'));
        async.flushMicrotasks();
        expect(fixes.hasListener, isFalse);

        cubit.resume();

        expect(fixes.hasListener, isTrue);
        verify(() => location.watch(distanceFilterMeters: 5)).called(2);
        async.elapse(const Duration(seconds: 5));
        verifyNever(() => location.watch(distanceFilterMeters: 5));
        cubit.close();
      });
    });

    test('stop cancels the scheduled resubscription', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        fixes.addError(StateError('gps off'));
        async.flushMicrotasks();

        cubit.stop();
        async.elapse(const Duration(seconds: 5));

        expect(fixes.hasListener, isFalse);
        verify(() => location.watch(distanceFilterMeters: 5)).called(1);
        cubit.close();
      });
    });
  });
  group('progress', () {
    // The same route with its leg ends: leg 1 ends on A (vertex 1), leg 2 on
    // B (vertex 2).
    final tracked = RoutePlan(
      origin: origin,
      stops: plan.stops,
      polyline: plan.polyline,
      distanceMeters: plan.distanceMeters,
      durationSeconds: plan.durationSeconds,
      legs: const [
        RouteLeg(distanceMeters: 2224, durationSeconds: 200, endIndex: 1),
        RouteLeg(distanceMeters: 2224, durationSeconds: 200, endIndex: 2),
      ],
      computedAt: t0,
    );
    const stopA = RouteStop(stop: a, order: 1);
    const stopB = RouteStop(stop: b, order: 2);

    test('start measures it from the fix that enabled "Iniciar": half of '
        'leg 1 left (1112 m, 100 s), leg 2 in full, A at t0 + 100 s', () {
      fakeAsync((async) {
        final cubit = navigating(async, tracked);

        expect(
          cubit.state.progress,
          RouteProgress(
            next: stopA,
            toNextMeters: 1112,
            toNextSeconds: 100,
            remainingMeters: 1112 + 2224,
            remainingSeconds: 100 + 200,
            at: t0,
          ),
        );
        expect(
          cubit.state.progress!.nextArrival,
          t0.add(const Duration(seconds: 100)),
        );
        cubit.close();
      });
    });

    test('none while waiting for GPS, even with a precise fix', () {
      fakeAsync((async) {
        final cubit = build(async, tracked)..prepare();
        async.flushMicrotasks();

        emitFix(async, onRoute());

        expect(cubit.state.canStart, isTrue);
        expect(cubit.state.progress, isNull);
        cubit.close();
      });
    });

    test('each fix of 50 m or better updates it with the clock; a worse fix '
        'moves the position but keeps the last progress', () {
      fakeAsync((async) {
        final cubit = navigating(async, tracked);

        async.elapse(const Duration(seconds: 10));
        emitFix(async, fix(const GeoPoint(0, -0.005), accuracy: 50));

        final measured = cubit.state.progress!;
        expect(measured.toNextMeters, 556);
        expect(measured.toNextSeconds, 50);
        expect(measured.at, t0.add(const Duration(seconds: 10)));

        final imprecise = fix(const GeoPoint(0, -0.015), accuracy: 50.1);
        emitFix(async, imprecise);

        expect(cubit.state.fix, imprecise);
        expect(cubit.state.progress, measured);
        cubit.close();
      });
    });

    test('arriving at A keeps it next: nothing of leg 1 left from the '
        'arrival fix, leg 2 in full', () {
      fakeAsync((async) {
        final cubit = navigating(async, tracked);

        emitFix(async, atStop(a));

        expect(
          cubit.state.progress,
          RouteProgress(
            next: stopA,
            toNextMeters: 0,
            toNextSeconds: 0,
            remainingMeters: 2224,
            remainingSeconds: 200,
            at: t0,
          ),
        );
        cubit.close();
      });
    });

    test('"Entregue" measures B from the last precise fix', () {
      fakeAsync((async) {
        final cubit = navigating(async, tracked);

        cubit.recordDelivered();
        async.flushMicrotasks();

        expect(cubit.state.progress!.next, stopB);
        expect(cubit.state.progress!.toNextMeters, 2224);
        cubit.close();
      });
    });

    test('completing the route or "Encerrar" clears it', () {
      fakeAsync((async) {
        final completed = navigating(async, tracked);
        completed.recordDelivered();
        async.flushMicrotasks();
        async.elapse(NavigationCubit.recordGuard);
        completed.recordDelivered();
        async.flushMicrotasks();

        expect(completed.state.phase, NavigationPhase.completed);
        expect(completed.state.progress, isNull);
        completed.close();

        final stopped = navigating(async, tracked);
        expect(stopped.state.progress, isNotNull);

        stopped.stop();

        expect(stopped.state.phase, NavigationPhase.idle);
        expect(stopped.state.progress, isNull);
        stopped.close();
      });
    });

    test('a recalculated plan is measured on its first new leg from the '
        'fix that triggered it', () {
      final replaced = RoutePlan(
        origin: farPoint,
        stops: const [
          RouteStop(stop: b, order: 1),
          RouteStop(stop: a, order: 2),
        ],
        polyline: [farPoint, const GeoPoint(0, 0.02), const GeoPoint(0, 0)],
        distanceMeters: 5224,
        durationSeconds: 450,
        legs: const [
          RouteLeg(distanceMeters: 3000, durationSeconds: 250, endIndex: 1),
          RouteLeg(distanceMeters: 2224, durationSeconds: 200, endIndex: 2),
        ],
        computedAt: t0,
      );
      stubPlan(replaced);
      fakeAsync((async) {
        final cubit = navigating(async, tracked);
        async.elapse(const Duration(seconds: 30));

        goOffRoute(async);

        expect(cubit.state.plan, replaced.withStart(t0));
        expect(
          cubit.state.progress,
          RouteProgress(
            next: const RouteStop(stop: b, order: 1),
            toNextMeters: 3000,
            toNextSeconds: 250,
            remainingMeters: 5224,
            remainingSeconds: 450,
            at: t0.add(const Duration(seconds: 30)),
          ),
        );
        cubit.close();
      });
    });

    test('a plan saved without leg ends (app 0.1.0) navigates without '
        'progress', () {
      fakeAsync((async) {
        final cubit = navigating(async);

        emitFix(async, onRoute());

        expect(cubit.state.phase, NavigationPhase.navigating);
        expect(cubit.state.progress, isNull);
        cubit.close();
      });
    });
  });

  group('round trip', () {
    // The same route back to its origin: after B the line runs back along
    // the equator (leg ends on A, B, and the origin for the way back).
    final roundTrip = RoutePlan(
      origin: origin,
      stops: plan.stops,
      polyline: const [origin, GeoPoint(0, 0), GeoPoint(0, 0.02), origin],
      distanceMeters: 8896,
      durationSeconds: 800,
      legs: const [
        RouteLeg(distanceMeters: 2224, durationSeconds: 200, endIndex: 1),
        RouteLeg(distanceMeters: 2224, durationSeconds: 200, endIndex: 2),
      ],
      computedAt: t0,
      returnTo: origin,
      returnLeg: const RouteLeg(
        distanceMeters: 4448,
        durationSeconds: 400,
        endIndex: 3,
      ),
    );
    final started = t0.subtract(const Duration(minutes: 30));
    final deliveredA = StopResult.delivered(
      at: t0.add(const Duration(seconds: 5)),
    );
    final refusedB = StopResult.failed(
      FailureReason.refused,
      at: t0.add(const Duration(seconds: 10)),
    );

    /// A fix 30 m from the start of the route.
    Fix atStart({double accuracy = 10}) =>
        fix(GeoPoint(lat(30), origin.lng), accuracy: accuracy);

    /// [roundTrip], started 30 min before t0 with 850 m traveled, with A
    /// delivered at t0 + 5 s and B refused at t0 + 10 s: on its way back.
    NavigationCubit returning(FakeAsync async) {
      final cubit = navigating(
        async,
        roundTrip.withStart(started).withTraveled(850),
      );
      async.elapse(const Duration(seconds: 5));
      cubit.recordDelivered();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      cubit.recordFailed(FailureReason.refused);
      async.flushMicrotasks();
      return cubit;
    }

    /// The summary of [returning] ended at [end], [traveled] meters.
    RouteSummary summaryAt(DateTime end, {int traveled = 850}) => RouteSummary(
      delivered: 1,
      failed: [RouteStop(stop: b, order: 2, result: refusedB)],
      traveledMeters: traveled,
      start: started,
      end: end,
    );

    group('way back and completion', () {
      test('the last result leaves it navigating on the way back: no '
          'summary, the stream kept and the plan saved with every result and '
          'the way back, measured from the last precise fix', () {
        fakeAsync((async) {
          final cubit = returning(async);

          expect(cubit.state.phase, NavigationPhase.navigating);
          expect(cubit.state.plan.isReturning, isTrue);
          expect(cubit.state.summary, isNull);
          expect(cubit.state.arrived, isFalse);
          expect(fixes.hasListener, isTrue);
          expect(session.isNavigationActive, isTrue);
          verifyNever(() => routes.clear());
          final saved = verify(() => routes.save(captureAny())).captured
              .cast<RoutePlan>();
          expect(saved, hasLength(2));
          expect(saved.last, cubit.state.plan);
          expect(saved.last.stops.map((s) => s.result), [deliveredA, refusedB]);
          expect(saved.last.returnTo, origin);
          expect(saved.last.returnLeg, roundTrip.returnLeg);
          // The start fix, 3/4 of the way back from B: a quarter is left.
          expect(
            cubit.state.progress,
            RouteProgress(
              next: null,
              toNextMeters: 1112,
              toNextSeconds: 100,
              remainingMeters: 1112,
              remainingSeconds: 100,
              at: t0.add(const Duration(seconds: 10)),
            ),
          );
          cubit.close();
        });
      });

      test('on the way back, a fix of 10 m accuracy 30 m from the start '
          'completes the route with its summary, ended at the clock time of '
          'that fix and with its distance: stream stopped, storage cleared, '
          'navigation active until close', () {
        fakeAsync((async) {
          final cubit = returning(async);
          async.elapse(const Duration(minutes: 12));
          // 111 m before the start, then at the start.
          emitFix(async, fix(GeoPoint(lat(30), origin.lng + 0.001)));
          expect(cubit.state.phase, NavigationPhase.navigating);
          async.elapse(const Duration(minutes: 1));

          emitFix(async, atStart());

          final end = t0.add(const Duration(minutes: 13, seconds: 10));
          expect(cubit.state.phase, NavigationPhase.completed);
          expect(cubit.state.summary, summaryAt(end, traveled: 961));
          expect(
            cubit.state.summary!.duration,
            const Duration(minutes: 43, seconds: 10),
          );
          expect(cubit.state.progress, isNull);
          expect(fixes.hasListener, isFalse);
          verify(() => routes.clear()).called(1);
          expect(session.isNavigationActive, isTrue);

          cubit.close();
          async.flushMicrotasks();

          expect(session.isNavigationActive, isFalse);
        });
      });

      test('on the way back, a fix 30 m from the start with 60 m accuracy '
          'or a precise one 100 m away keeps it navigating', () {
        fakeAsync((async) {
          final cubit = returning(async);
          final before = cubit.state.plan;

          emitFix(async, atStart(accuracy: 60));
          emitFix(async, fix(GeoPoint(lat(100), origin.lng)));

          expect(cubit.state.phase, NavigationPhase.navigating);
          expect(cubit.state.summary, isNull);
          expect(cubit.state.plan, before);
          expect(fixes.hasListener, isTrue);
          verifyNever(() => routes.clear());
          cubit.close();
        });
      });

      test('on the way back, a fix exactly 40 m from the start with 50 m '
          'accuracy completes the route', () {
        fakeAsync((async) {
          final cubit = returning(async);
          async.elapse(const Duration(minutes: 1));

          emitFix(async, fix(GeoPoint(lat(40), origin.lng), accuracy: 50));

          expect(cubit.state.phase, NavigationPhase.completed);
          expect(
            cubit.state.summary,
            summaryAt(t0.add(const Duration(minutes: 1, seconds: 10))),
          );
          verify(() => routes.clear()).called(1);
          cubit.close();
        });
      });

      test('on the way back, a fix 40.1 m from the start with 50 m accuracy, '
          'or 40 m away with 50.1 m accuracy, keeps it navigating', () {
        fakeAsync((async) {
          final cubit = returning(async);
          final before = cubit.state.plan;

          emitFix(async, fix(GeoPoint(lat(40.1), origin.lng), accuracy: 50));
          emitFix(async, fix(GeoPoint(lat(40), origin.lng), accuracy: 50.1));

          expect(cubit.state.phase, NavigationPhase.navigating);
          expect(cubit.state.summary, isNull);
          expect(cubit.state.plan, before);
          expect(fixes.hasListener, isTrue);
          verifyNever(() => routes.clear());
          cubit.close();
        });
      });

      test('a fix at the start while a stop has no result (leaving the '
          'depot, or with one stop left) neither arrives nor completes', () {
        fakeAsync((async) {
          final cubit = navigating(async, roundTrip);

          emitFix(async, atStart());

          expect(cubit.state.phase, NavigationPhase.navigating);
          expect(cubit.state.arrived, isFalse);
          expect(cubit.state.summary, isNull);

          cubit.recordDelivered();
          async.flushMicrotasks();
          emitFix(async, atStart());

          expect(cubit.state.phase, NavigationPhase.navigating);
          expect(cubit.state.arrived, isFalse);
          expect(cubit.state.summary, isNull);
          expect(cubit.state.plan.nextStop!.stop, b);
          verifyNever(() => routes.clear());
          cubit.close();
        });
      });

      test('"Finalizar rota" on the way back completes the route with its '
          'summary, ended at the clock time of the tap; a second tap does '
          'nothing', () {
        fakeAsync((async) {
          final cubit = returning(async);
          async.elapse(const Duration(minutes: 20));

          cubit.finishRoute();
          async.flushMicrotasks();

          final end = t0.add(const Duration(minutes: 20, seconds: 10));
          expect(cubit.state.phase, NavigationPhase.completed);
          expect(cubit.state.summary, summaryAt(end));
          expect(
            cubit.state.summary!.duration,
            const Duration(minutes: 50, seconds: 10),
          );
          expect(cubit.state.progress, isNull);
          expect(fixes.hasListener, isFalse);
          verify(() => routes.clear()).called(1);
          expect(session.isNavigationActive, isTrue);

          async.elapse(const Duration(seconds: 5));
          cubit.finishRoute();
          async.flushMicrotasks();

          expect(cubit.state.summary, summaryAt(end));
          verifyNever(() => routes.clear());
          cubit.close();
        });
      });

      test('"Finalizar rota" within 1 s of the last result is ignored: at '
          '+999 ms it stays on the way back with nothing cleared, at +1000 ms '
          'it completes with the summary ended at that tap', () {
        fakeAsync((async) {
          final cubit = returning(async);
          final onItsWayBack = cubit.state;

          async.elapse(const Duration(milliseconds: 999));
          cubit.finishRoute();
          async.flushMicrotasks();

          expect(cubit.state, onItsWayBack);
          expect(cubit.state.phase, NavigationPhase.navigating);
          expect(cubit.state.plan.isReturning, isTrue);
          expect(cubit.state.summary, isNull);
          expect(fixes.hasListener, isTrue);
          verifyNever(() => routes.clear());

          async.elapse(const Duration(milliseconds: 1));
          cubit.finishRoute();
          async.flushMicrotasks();

          expect(cubit.state.phase, NavigationPhase.completed);
          expect(
            cubit.state.summary,
            summaryAt(t0.add(const Duration(seconds: 11))),
          );
          verify(() => routes.clear()).called(1);
          cubit.close();
        });
      });

      test('"Finalizar rota" on a route continued on its way back completes '
          'at once: no result was recorded since it was opened', () {
        fakeAsync((async) {
          // Killed on its way back and continued 10 min after its last result.
          final continued = roundTrip
              .withStart(started)
              .withTraveled(850)
              .record('pa', deliveredA)
              .record('pb', refusedB);
          async.elapse(const Duration(minutes: 10, seconds: 10));
          final cubit = navigating(async, continued);
          expect(cubit.state.plan.isReturning, isTrue);

          cubit.finishRoute();
          async.flushMicrotasks();

          expect(cubit.state.phase, NavigationPhase.completed);
          expect(
            cubit.state.summary,
            summaryAt(t0.add(const Duration(minutes: 10, seconds: 10))),
          );
          verify(() => routes.clear()).called(1);
          cubit.close();
        });
      });

      test('"Finalizar rota" is ignored before the way back: with a stop '
          'left, on a one-way route and while waiting for GPS', () {
        fakeAsync((async) {
          final oneLeft = navigating(async, roundTrip);
          oneLeft.recordDelivered();
          async.flushMicrotasks();
          final withStopLeft = oneLeft.state;

          oneLeft.finishRoute();
          async.flushMicrotasks();

          expect(oneLeft.state, withStopLeft);
          expect(oneLeft.state.phase, NavigationPhase.navigating);
          oneLeft.close();

          final oneWay = navigating(async);
          final oneWayBefore = oneWay.state;

          oneWay.finishRoute();
          async.flushMicrotasks();

          expect(oneWay.state, oneWayBefore);
          oneWay.close();

          final waiting = build(
            async,
            roundTrip
                .record('pa', StopResult.delivered(at: t0))
                .record('pb', StopResult.delivered(at: t0)),
          )..prepare();
          async.flushMicrotasks();

          waiting.finishRoute();
          async.flushMicrotasks();

          expect(waiting.state.phase, NavigationPhase.waitingGps);
          expect(waiting.state.summary, isNull);
          verifyNever(() => routes.clear());
          waiting.close();
        });
      });
    });

    group('recalculation', () {
      /// Every recalculation answers [answer], whatever its point of return.
      void stubReturn(RoutePlan answer) => when(
        () => routes.plan(
          any(),
          any(),
          keepVisited: any(named: 'keepVisited'),
          returnTo: any(named: 'returnTo'),
        ),
      ).thenAnswer((_) async => answer);

      test('off route with a stop left: one request from the current '
          'position through the stop left and back to the start; the plan '
          'is replaced and the next recalculation still ends at the start', () {
        final delivered = RouteStop(
          stop: a,
          order: 1,
          result: StopResult.delivered(at: t0),
        );
        final answer = RoutePlan(
          origin: farPoint,
          stops: [
            delivered,
            const RouteStop(stop: b, order: 2),
          ],
          polyline: [farPoint, const GeoPoint(0, 0.02), origin],
          distanceMeters: 7200,
          durationSeconds: 640,
          legs: const [
            RouteLeg(distanceMeters: 2750, durationSeconds: 240, endIndex: 1),
          ],
          computedAt: t0.add(const Duration(minutes: 1)),
          returnTo: origin,
          returnLeg: const RouteLeg(
            distanceMeters: 4450,
            durationSeconds: 400,
            endIndex: 2,
          ),
        );
        stubReturn(answer);
        fakeAsync((async) {
          final cubit = navigating(async, roundTrip);
          cubit.recordDelivered();
          async.flushMicrotasks();

          goOffRoute(async);

          verify(
            () => routes.plan(
              farPoint,
              [b],
              keepVisited: [delivered],
              returnTo: origin,
            ),
          ).called(1);
          expect(cubit.state.plan, answer.withStart(t0));
          expect(cubit.state.plan.origin, farPoint);
          expect(cubit.state.plan.returnTo, origin);
          expect(cubit.state.plan.nextStop!.stop, b);
          expect(cubit.state.badge, NavigationBadge.recalculated);

          async.elapse(const Duration(seconds: 20));
          goOffRoute(async, farPoint2);

          verify(
            () => routes.plan(
              farPoint2,
              [b],
              keepVisited: [delivered],
              returnTo: origin,
            ),
          ).called(1);
          cubit.close();
        });
      });

      test('off route on the way back: one request from the current position '
          'with no stop, back to the start; the plan stays on its way back, '
          'and arriving at the start, not at the new origin, completes', () {
        final answer = RoutePlan(
          origin: farPoint,
          stops: [
            RouteStop(stop: a, order: 1, result: deliveredA),
            RouteStop(stop: b, order: 2, result: refusedB),
          ],
          polyline: [farPoint, origin],
          distanceMeters: 1200,
          durationSeconds: 150,
          legs: const [],
          computedAt: t0.add(const Duration(minutes: 1)),
          returnTo: origin,
          returnLeg: const RouteLeg(
            distanceMeters: 1200,
            durationSeconds: 150,
            endIndex: 1,
          ),
        );
        stubReturn(answer);
        fakeAsync((async) {
          final cubit = returning(async);

          goOffRoute(async);

          verify(
            () => routes.plan(
              farPoint,
              const <Stop>[],
              keepVisited: [
                RouteStop(stop: a, order: 1, result: deliveredA),
                RouteStop(stop: b, order: 2, result: refusedB),
              ],
              returnTo: origin,
            ),
          ).called(1);
          expect(cubit.state.plan, answer.withStart(started).withTraveled(850));
          expect(cubit.state.plan.isReturning, isTrue);
          expect(cubit.state.phase, NavigationPhase.navigating);
          expect(cubit.state.badge, NavigationBadge.recalculated);
          expect(
            cubit.state.progress,
            RouteProgress(
              next: null,
              toNextMeters: 1200,
              toNextSeconds: 150,
              remainingMeters: 1200,
              remainingSeconds: 150,
              at: t0.add(const Duration(seconds: 10)),
            ),
          );

          emitFix(async, far());
          expect(cubit.state.phase, NavigationPhase.navigating);

          emitFix(async, atStart());
          expect(cubit.state.phase, NavigationPhase.completed);
          cubit.close();
        });
      });

      test('offline on the way back: "Recálculo pendente (sem conexão)" '
          'without a request, then the request with no stop runs on '
          'reconnect', () {
        final answer = RoutePlan(
          origin: farPoint,
          stops: [
            RouteStop(stop: a, order: 1, result: deliveredA),
            RouteStop(stop: b, order: 2, result: refusedB),
          ],
          polyline: [farPoint, origin],
          distanceMeters: 1200,
          durationSeconds: 150,
          legs: const [],
          computedAt: t0.add(const Duration(minutes: 1)),
          returnTo: origin,
          returnLeg: const RouteLeg(
            distanceMeters: 1200,
            durationSeconds: 150,
            endIndex: 1,
          ),
        );
        stubReturn(answer);
        fakeAsync((async) {
          final cubit = returning(async);
          online.add(false);
          async.flushMicrotasks();

          goOffRoute(async);

          verifyNever(
            () => routes.plan(
              any(),
              any(),
              keepVisited: any(named: 'keepVisited'),
              returnTo: any(named: 'returnTo'),
            ),
          );
          expect(cubit.state.recalcPending, isTrue);
          expect(cubit.state.badge, NavigationBadge.recalcPending);

          online.add(true);
          async.flushMicrotasks();

          verify(
            () => routes.plan(
              farPoint,
              const <Stop>[],
              keepVisited: any(named: 'keepVisited'),
              returnTo: origin,
            ),
          ).called(1);
          expect(cubit.state.recalcPending, isFalse);
          expect(cubit.state.badge, NavigationBadge.recalculated);
          expect(cubit.state.plan.polyline, answer.polyline);
          expect(cubit.state.plan.isReturning, isTrue);
          cubit.close();
        });
      });
    });
  });
}

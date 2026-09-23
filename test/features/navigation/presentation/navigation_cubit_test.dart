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
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';

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
      RouteStop(stop: a, order: 1, visited: false),
      RouteStop(stop: b, order: 2, visited: false),
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
      RouteStop(stop: b, order: 1, visited: false),
      RouteStop(stop: a, order: 2, visited: false),
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
  NavigationCubit build(FakeAsync async) => NavigationCubit(
    plan: plan,
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

  NavigationCubit navigating(FakeAsync async) {
    final cubit = build(async)..prepare();
    async.flushMicrotasks();
    emitFix(async, onRoute());
    cubit.start();
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
    test('within 40 m of the next stop marks it visited and persists the '
        'plan', () {
      fakeAsync((async) {
        final cubit = navigating(async);

        final arrival = atStop(a);
        emitFix(async, arrival);

        expect(cubit.state.fix, arrival);
        expect(cubit.state.plan.stops[0].visited, isTrue);
        expect(cubit.state.plan.stops[1].visited, isFalse);
        expect(cubit.state.plan.nextStop!.stop, b);
        expect(cubit.state.phase, NavigationPhase.navigating);
        final saved =
            verify(() => routes.save(captureAny())).captured.single
                as RoutePlan;
        expect(saved, cubit.state.plan);
        expect(saved.stops[0].visited, isTrue);
        cubit.close();
      });
    });

    test('"Marcar como visitado" marks the next stop exactly like the '
        'automatic case', () {
      fakeAsync((async) {
        final cubit = navigating(async);

        cubit.markNextVisited();
        async.flushMicrotasks();

        expect(cubit.state.plan.stops[0].visited, isTrue);
        expect(cubit.state.plan.nextStop!.stop, b);
        final saved =
            verify(() => routes.save(captureAny())).captured.single
                as RoutePlan;
        expect(saved.stops[0].visited, isTrue);
        expect(saved.stops[1].visited, isFalse);
        cubit.close();
      });
    });

    test('the last stop completes the route: stream stopped, storage '
        'cleared, navigation no longer active', () {
      fakeAsync((async) {
        final cubit = navigating(async);
        emitFix(async, atStop(a));

        emitFix(async, atStop(b));

        expect(cubit.state.phase, NavigationPhase.completed);
        expect(cubit.state.plan.isComplete, isTrue);
        expect(fixes.hasListener, isFalse);
        expect(session.isNavigationActive, isFalse);
        verify(() => routes.clear()).called(1);
        verify(() => routes.save(any())).called(1);
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
        expect(cubit.state.plan, recalculated);
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
        expect(cubit.state.plan, recalculated);
        cubit.close();
      });
    });

    test(
      'visited stops are kept and only the unvisited ones are requested',
      () {
        stubPlan(recalculated);
        fakeAsync((async) {
          final cubit = navigating(async);
          emitFix(async, atStop(a));

          goOffRoute(async);

          verify(
            () => routes.plan(
              farPoint,
              [b],
              keepVisited: const [RouteStop(stop: a, order: 1, visited: true)],
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
        expect(cubit.state.plan, plan);
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.badge, NavigationBadge.recalcFailed);
        expect(cubit.state.badge!.kind, BadgeKind.recalcFailed);
        expect(cubit.state.badge!.text, 'Falha ao recalcular');

        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.badge, isNull);
        expect(cubit.state.plan, plan);

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
        expect(cubit.state.plan, plan);

        pending.complete(recalculated);
        async.flushMicrotasks();
        expect(cubit.state.recalcInFlight, isFalse);
        expect(cubit.state.plan, recalculated);
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
        expect(cubit.state.plan, plan);

        online.add(true);
        async.flushMicrotasks();

        expect(cubit.state.online, isTrue);
        verify(
          () => routes.plan(farPoint, [a, b], keepVisited: const <RouteStop>[]),
        ).called(1);
        expect(cubit.state.recalcPending, isFalse);
        expect(cubit.state.plan, recalculated);
        expect(cubit.state.badge, NavigationBadge.recalculated);
        cubit.close();
      });
    });

    test('a stop visited while a recalculation is in flight stays visited '
        'in the replaced plan', () {
      fakeAsync((async) {
        final pending = Completer<RoutePlan>();
        stubPlan(pending);
        final cubit = navigating(async);
        goOffRoute(async);
        expect(cubit.state.recalcInFlight, isTrue);

        cubit.markNextVisited();
        async.flushMicrotasks();
        expect(cubit.state.plan.stops[0].visited, isTrue);

        pending.complete(recalculated);
        async.flushMicrotasks();

        expect(cubit.state.recalcInFlight, isFalse);
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
        cubit.close();
      });
    });

    test('completion during an in-flight recalculation is final: the stale '
        'plan is dropped and storage stays cleared', () {
      fakeAsync((async) {
        final pending = Completer<RoutePlan>();
        stubPlan(pending);
        final cubit = navigating(async);
        emitFix(async, atStop(a));
        goOffRoute(async);
        expect(cubit.state.recalcInFlight, isTrue);

        emitFix(async, atStop(b));
        expect(cubit.state.phase, NavigationPhase.completed);

        pending.complete(recalculated.markVisited('pa'));
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

        emitFix(async, atStop(a));
        emitFix(async, atStop(b));
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
        emitFix(async, atStop(a));

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
}

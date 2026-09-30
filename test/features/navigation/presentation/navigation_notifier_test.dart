import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/data/background_tracker.dart';
import 'package:routebreeze/features/navigation/data/route_alerts.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/domain/route_summary.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_notifier.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

class _Tracker implements BackgroundTracker {
  final List<(String, String)> updates = [];

  @override
  Future<void> start() async {}

  @override
  Future<void> update(String title, String body) async =>
      updates.add((title, body));

  @override
  Future<void> stop() async {}
}

class _Alerts implements RouteAlerts {
  final List<Object> calls = [];

  @override
  Future<void> show(RouteAlert kind, String title, String body) async =>
      calls.add((kind, title, body));

  @override
  Future<void> clear() async => calls.add('clear');
}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const santos = Stop(
    'pa',
    'Alameda Santos, 1000',
    GeoPoint(-23.5663, -46.6532),
  );
  const augusta = Stop('pb', 'Rua Augusta, 500', GeoPoint(-23.553, -46.653));
  const haddock = Stop(
    'pc',
    'Rua Haddock Lobo, 595',
    GeoPoint(-23.5605, -46.6645),
  );
  const oscar = Stop('pd', 'Rua Oscar Freire, 100', GeoPoint(-23.565, -46.662));

  /// 14:28 on the driver's clock; the fake clock starts here.
  final t0 = DateTime(2026, 9, 28, 14, 28);

  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: santos, order: 1),
      RouteStop(stop: augusta, order: 2),
    ],
    polyline: const [
      origin,
      GeoPoint(-23.5663, -46.6532),
      GeoPoint(-23.553, -46.653),
    ],
    distanceMeters: 3200,
    durationSeconds: 640,
    legs: const [],
    computedAt: t0,
  );

  final recalculated = RoutePlan(
    origin: const GeoPoint(-23.564, -46.654),
    stops: const [
      RouteStop(stop: augusta, order: 1),
      RouteStop(stop: santos, order: 2),
    ],
    polyline: const [GeoPoint(-23.564, -46.654), GeoPoint(-23.553, -46.653)],
    distanceMeters: 3400,
    durationSeconds: 700,
    legs: const [],
    computedAt: t0,
  );

  final roundTrip = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: santos, order: 1),
      RouteStop(stop: augusta, order: 2),
      RouteStop(stop: haddock, order: 3),
      RouteStop(stop: oscar, order: 4),
    ],
    polyline: const [origin, GeoPoint(-23.553, -46.653), origin],
    distanceMeters: 9000,
    durationSeconds: 1800,
    legs: const [],
    computedAt: t0,
    returnTo: origin,
    returnLeg: const RouteLeg(distanceMeters: 3400, durationSeconds: 540),
  );

  final toOscar = roundTrip
      .record('pa', const StopResult.delivered())
      .record('pb', const StopResult.delivered())
      .record('pc', const StopResult.failed(FailureReason.refused));

  final returning = toOscar.record('pd', const StopResult.delivered());

  /// Progress to [next], or along the way back when null, measured [after] t0.
  RouteProgress progress(
    RouteStop? next,
    int meters,
    int seconds, [
    Duration after = Duration.zero,
  ]) => RouteProgress(
    next: next,
    toNextMeters: meters,
    toNextSeconds: seconds,
    remainingMeters: meters + 2000,
    remainingSeconds: seconds + 400,
    at: t0.add(after),
  );

  NavigationState navigating(
    RoutePlan plan, {
    RouteProgress? progress,
    bool arrived = false,
    NavigationBadge? badge,
  }) => NavigationState(
    plan: plan,
    phase: NavigationPhase.navigating,
    progress: progress,
    arrived: arrived,
    badge: badge,
  );

  NavigationState completed(RoutePlan plan) => NavigationState(
    plan: plan,
    phase: NavigationPhase.completed,
    summary: RouteSummary.of(
      plan,
      traveledMeters: 9100,
      end: t0.add(const Duration(minutes: 20)),
    ),
  );

  final toSantos = progress(plan.stops[0], 1234, 250);
  const santosTitle = 'Próxima parada 1 · Alameda Santos, 1000';

  late _Tracker tracker;
  late _Alerts alerts;
  late bool background;
  late StreamController<NavigationState> states;

  setUp(() {
    tracker = _Tracker();
    alerts = _Alerts();
    background = false;
  });

  NavigationNotifier build(FakeAsync async) {
    states = StreamController<NavigationState>();
    return NavigationNotifier(
      states: states.stream,
      initial: NavigationState(plan: plan, phase: NavigationPhase.waitingGps),
      tracker: tracker,
      alerts: alerts,
      inBackground: () => background,
      now: () => t0.add(async.elapsed),
    );
  }

  void emit(FakeAsync async, NavigationState state) {
    states.add(state);
    async.flushMicrotasks();
  }

  group('ongoing notification', () {
    test('"Iniciar" shows the next stop at once: "Próxima parada {n} · '
        '{address}" over "{distance} · {duration} · chegada às {HH:mm}"; '
        'nothing before it', () {
      fakeAsync((async) {
        build(async);
        emit(
          async,
          NavigationState(
            plan: plan,
            phase: NavigationPhase.waitingGps,
            online: false,
          ),
        );
        expect(tracker.updates, isEmpty);

        emit(async, navigating(plan, progress: toSantos));

        expect(tracker.updates, [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
        ]);
      });
    });

    test('without a measured progress the text is "Acompanhando sua '
        'rota"', () {
      fakeAsync((async) {
        build(async);

        emit(async, navigating(plan));

        expect(tracker.updates, [(santosTitle, 'Acompanhando sua rota')]);
      });
    });

    test('arriving shows "Você chegou" at once, 5 s after the last '
        'update', () {
      fakeAsync((async) {
        build(async);
        emit(async, navigating(plan, progress: toSantos));
        async.elapse(const Duration(seconds: 5));

        emit(
          async,
          navigating(
            plan,
            progress: progress(
              plan.stops[0],
              30,
              10,
              const Duration(seconds: 5),
            ),
            arrived: true,
          ),
        );

        expect(tracker.updates, [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
          (santosTitle, 'Você chegou'),
        ]);
      });
    });

    test('a new next stop shows at once, 5 s after the last update', () {
      fakeAsync((async) {
        build(async);
        emit(async, navigating(plan, progress: toSantos));
        async.elapse(const Duration(seconds: 5));

        final delivered = plan.record(
          'pa',
          StopResult.delivered(at: t0.add(const Duration(seconds: 5))),
        );
        emit(
          async,
          navigating(
            delivered,
            progress: progress(
              delivered.stops[1],
              2100,
              420,
              const Duration(seconds: 5),
            ),
          ),
        );

        expect(tracker.updates, [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
          (
            'Próxima parada 2 · Rua Augusta, 500',
            '2,1 km · 7 min · chegada às 14:35',
          ),
        ]);
      });
    });

    test('other progress changes update at most every 15 s: changes at +10 s '
        'and +14 s send nothing, +15 s sends the latest; a change 15 s after '
        'that update goes at once', () {
      fakeAsync((async) {
        build(async);
        emit(async, navigating(plan, progress: toSantos));

        async.elapse(const Duration(seconds: 10));
        emit(
          async,
          navigating(
            plan,
            progress: progress(
              plan.stops[0],
              1100,
              230,
              const Duration(seconds: 10),
            ),
          ),
        );
        async.elapse(const Duration(seconds: 4));
        emit(
          async,
          navigating(
            plan,
            progress: progress(
              plan.stops[0],
              1000,
              210,
              const Duration(seconds: 14),
            ),
          ),
        );
        expect(tracker.updates, [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
        ]);

        async.elapse(const Duration(seconds: 1));
        expect(tracker.updates, [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
          (santosTitle, '1,0 km · 4 min · chegada às 14:31'),
        ]);

        async.elapse(const Duration(seconds: 15));
        emit(
          async,
          navigating(
            plan,
            progress: progress(
              plan.stops[0],
              700,
              150,
              const Duration(seconds: 30),
            ),
          ),
        );
        expect(tracker.updates, [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
          (santosTitle, '1,0 km · 4 min · chegada às 14:31'),
          (santosTitle, '700 m · 3 min · chegada às 14:31'),
        ]);
      });
    });

    test('a progress change 14 s after a new next stop waits the 1 s left '
        'of the 15 s, counted from that update', () {
      fakeAsync((async) {
        build(async);
        emit(async, navigating(plan, progress: toSantos));
        async.elapse(const Duration(seconds: 5));
        final delivered = plan.record(
          'pa',
          StopResult.delivered(at: t0.add(const Duration(seconds: 5))),
        );
        emit(
          async,
          navigating(
            delivered,
            progress: progress(
              delivered.stops[1],
              2100,
              420,
              const Duration(seconds: 5),
            ),
          ),
        );

        async.elapse(const Duration(seconds: 14));
        emit(
          async,
          navigating(
            delivered,
            progress: progress(
              delivered.stops[1],
              1900,
              380,
              const Duration(seconds: 19),
            ),
          ),
        );
        const augustaTitle = 'Próxima parada 2 · Rua Augusta, 500';
        final sent = [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
          (augustaTitle, '2,1 km · 7 min · chegada às 14:35'),
        ];
        expect(tracker.updates, sent);

        async.elapse(const Duration(seconds: 1));
        expect(tracker.updates, [
          ...sent,
          (augustaTitle, '1,9 km · 6 min · chegada às 14:34'),
        ]);
      });
    });

    test('on the way back of a round trip, at once after the last result: '
        '"Retorno ao ponto de partida" over the way back\'s summary', () {
      fakeAsync((async) {
        build(async);
        emit(
          async,
          navigating(toOscar, progress: progress(toOscar.stops[3], 30, 10)),
        );
        async.elapse(const Duration(seconds: 5));

        emit(
          async,
          navigating(
            returning,
            progress: progress(null, 3400, 540, const Duration(seconds: 5)),
          ),
        );

        expect(tracker.updates, [
          (
            'Próxima parada 4 · Rua Oscar Freire, 100',
            '30 m · < 1 min · chegada às 14:28',
          ),
          ('Retorno ao ponto de partida', '3,4 km · 9 min · chegada às 14:37'),
        ]);
      });
    });

    /// Sends two changes that the 15 s throttle holds back.
    void holdBack(FakeAsync async) {
      for (final (at, meters, seconds) in [(5, 1100, 230), (8, 1000, 210)]) {
        async.elapse(Duration(seconds: at) - async.elapsed);
        emit(
          async,
          navigating(
            plan,
            progress: progress(
              plan.stops[0],
              meters,
              seconds,
              Duration(seconds: at),
            ),
          ),
        );
      }
    }

    for (final (end, ended) in [
      ('"Encerrar"', NavigationState(plan: plan)),
      ('the route completing', completed(plan)),
    ]) {
      test('no update after $end, not even the ones the 15 s throttle held '
          'back', () {
        fakeAsync((async) {
          build(async);
          emit(async, navigating(plan, progress: toSantos));
          holdBack(async);
          async.elapse(const Duration(seconds: 2));

          emit(async, ended);
          emit(async, ended.copyWith(online: false));
          async.elapse(const Duration(seconds: 30));

          expect(tracker.updates, [
            (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
          ]);
        });
      });
    }

    test('dispose drops the updates the 15 s throttle held back', () {
      fakeAsync((async) {
        final notifier = build(async);
        emit(async, navigating(plan, progress: toSantos));
        holdBack(async);

        notifier.dispose();
        async.elapse(const Duration(seconds: 30));

        expect(tracker.updates, [
          (santosTitle, '1,2 km · 4 min · chegada às 14:32'),
        ]);
      });
    });
  });

  group('alerts in background', () {
    test('arriving at the next stop shows "Você chegou à parada {n}" / '
        '"{address}. Registre a entrega.", once while arrived', () {
      fakeAsync((async) {
        build(async);
        background = true;
        emit(async, navigating(plan, progress: toSantos));

        emit(async, navigating(plan, progress: toSantos, arrived: true));
        emit(
          async,
          navigating(
            plan,
            progress: progress(
              plan.stops[0],
              20,
              5,
              const Duration(seconds: 3),
            ),
            arrived: true,
          ),
        );

        expect(alerts.calls, [
          (
            RouteAlert.arrival,
            'Você chegou à parada 1',
            'Alameda Santos, 1000. Registre a entrega.',
          ),
        ]);
      });
    });

    test('a successful recalculation shows "Rota recalculada" / "Próxima '
        'parada {n} · {address}", once while its badge shows; a failed one '
        'shows nothing', () {
      fakeAsync((async) {
        build(async);
        background = true;
        emit(async, navigating(plan, progress: toSantos));

        emit(
          async,
          navigating(
            plan,
            progress: toSantos,
            badge: NavigationBadge.recalcFailed,
          ),
        );
        emit(async, navigating(plan, progress: toSantos));
        expect(alerts.calls, isEmpty);

        emit(
          async,
          navigating(recalculated, badge: NavigationBadge.recalculated),
        );
        emit(
          async,
          navigating(
            recalculated,
            progress: progress(recalculated.stops[0], 1500, 300),
            badge: NavigationBadge.recalculated,
          ),
        );

        expect(alerts.calls, [
          (
            RouteAlert.recalculated,
            'Rota recalculada',
            'Próxima parada 1 · Rua Augusta, 500',
          ),
        ]);
      });
    });

    test('on the way back, a recalculation shows "Rota recalculada" / '
        '"Retorno ao ponto de partida"', () {
      fakeAsync((async) {
        build(async);
        background = true;
        emit(async, navigating(returning, progress: progress(null, 3400, 540)));

        emit(
          async,
          navigating(
            returning,
            progress: progress(null, 3600, 600),
            badge: NavigationBadge.recalculated,
          ),
        );

        expect(alerts.calls, [
          (
            RouteAlert.recalculated,
            'Rota recalculada',
            'Retorno ao ponto de partida',
          ),
        ]);
      });
    });

    test('a round trip reaching its start shows "Rota concluída" with the '
        'counts, once, and no "Você chegou à parada"', () {
      fakeAsync((async) {
        build(async);
        background = true;
        emit(async, navigating(returning, progress: progress(null, 3400, 540)));

        emit(async, completed(returning));
        emit(async, completed(returning).copyWith(online: false));

        expect(alerts.calls, [
          (
            RouteAlert.completed,
            'Rota concluída',
            '3 entregues · 1 não entregue',
          ),
        ]);
      });
    });

    test('arriving and a recalculation within the same fix show both '
        'alerts, also when one state brings both', () {
      fakeAsync((async) {
        build(async);
        background = true;
        emit(async, navigating(plan, progress: toSantos));

        emit(async, navigating(plan, progress: toSantos, arrived: true));
        emit(
          async,
          navigating(
            plan,
            progress: toSantos,
            arrived: true,
            badge: NavigationBadge.recalculated,
          ),
        );
        emit(async, navigating(plan, progress: toSantos));
        emit(
          async,
          navigating(
            plan,
            progress: toSantos,
            arrived: true,
            badge: NavigationBadge.recalculated,
          ),
        );

        const arrival = (
          RouteAlert.arrival,
          'Você chegou à parada 1',
          'Alameda Santos, 1000. Registre a entrega.',
        );
        const recalculation = (
          RouteAlert.recalculated,
          'Rota recalculada',
          santosTitle,
        );
        expect(alerts.calls, [arrival, recalculation, arrival, recalculation]);
      });
    });

    test('back in foreground, the alerts are removed', () {
      fakeAsync((async) {
        final notifier = build(async);
        background = true;
        emit(async, navigating(plan, progress: toSantos));
        emit(async, navigating(plan, progress: toSantos, arrived: true));

        background = false;
        notifier.onForeground();
        async.flushMicrotasks();

        expect(alerts.calls, [
          (
            RouteAlert.arrival,
            'Você chegou à parada 1',
            'Alameda Santos, 1000. Registre a entrega.',
          ),
          'clear',
        ]);
      });
    });
  });

  test('in foreground no alert shows: arrival, recalculation and '
      'completion only update the ongoing notification', () {
    fakeAsync((async) {
      build(async);
      emit(async, navigating(toOscar));

      emit(async, navigating(toOscar, arrived: true));
      emit(
        async,
        navigating(toOscar, arrived: true, badge: NavigationBadge.recalculated),
      );
      emit(async, navigating(returning));
      emit(async, completed(returning));

      expect(alerts.calls, isEmpty);
      expect(tracker.updates, [
        ('Próxima parada 4 · Rua Oscar Freire, 100', 'Acompanhando sua rota'),
        ('Próxima parada 4 · Rua Oscar Freire, 100', 'Você chegou'),
        ('Retorno ao ponto de partida', 'Acompanhando sua rota'),
      ]);
    });
  });

  test('an arrival seen in foreground is not alerted once the app goes to '
      'background', () {
    fakeAsync((async) {
      build(async);
      emit(async, navigating(plan, progress: toSantos));
      emit(async, navigating(plan, progress: toSantos, arrived: true));

      background = true;
      emit(
        async,
        navigating(
          plan,
          progress: progress(plan.stops[0], 20, 5, const Duration(seconds: 3)),
          arrived: true,
        ),
      );

      expect(alerts.calls, isEmpty);
    });
  });
}

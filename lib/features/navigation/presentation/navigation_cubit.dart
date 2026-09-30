import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/geo/geo_point.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/session/session_state.dart';
import '../../location/domain/fix.dart';
import '../../location/domain/location_service.dart';
import '../../route/domain/route_plan.dart';
import '../../route/domain/route_repository.dart';
import '../../route/domain/stop_result.dart';
import '../data/background_tracker.dart';
import '../domain/deviation_detector.dart';
import '../domain/odometer.dart';
import '../domain/progress_estimator.dart';
import '../domain/recalc_policy.dart';
import '../domain/route_summary.dart';

enum NavigationPhase { idle, waitingGps, navigating, completed }

enum BadgeKind { recalculated, recalcFailed, recalcPending }

/// Transient status shown over the map.
class NavigationBadge extends Equatable {
  const NavigationBadge(this.kind, this.text);

  final BadgeKind kind;
  final String text;

  static const recalculated = NavigationBadge(
    BadgeKind.recalculated,
    'Rota recalculada',
  );
  static const recalcFailed = NavigationBadge(
    BadgeKind.recalcFailed,
    'Falha ao recalcular',
  );
  static const recalcPending = NavigationBadge(
    BadgeKind.recalcPending,
    'Recálculo pendente (sem conexão)',
  );

  @override
  List<Object?> get props => [kind, text];
}

class NavigationState extends Equatable {
  const NavigationState({
    required this.plan,
    this.phase = NavigationPhase.idle,
    this.fix,
    this.following = true,
    this.badge,
    this.online = true,
    this.recalcPending = false,
    this.recalcInFlight = false,
    this.error,
    this.lastRecalcAt,
    this.progress,
    this.arrived = false,
    this.summary,
  });

  final NavigationPhase phase;
  final RoutePlan plan;

  /// Last known position; kept through stream errors.
  final Fix? fix;

  /// Camera follows the position until the user drags the map.
  final bool following;
  final NavigationBadge? badge;
  final bool online;

  /// Off route while offline: the recalculation runs on reconnect.
  final bool recalcPending;
  final bool recalcInFlight;

  final String? error;
  final DateTime? lastRecalcAt;

  /// Null unless navigating; measured from the last fix of
  /// [NavigationCubit.maxStartAccuracyMeters] or better.
  final RouteProgress? progress;

  /// The driver reached the next stop; kept until a result is recorded.
  final bool arrived;

  /// Set when the route completes.
  final RouteSummary? summary;

  bool get canStart =>
      phase == NavigationPhase.waitingGps &&
      fix != null &&
      fix!.accuracyMeters <= NavigationCubit.maxStartAccuracyMeters;

  NavigationState copyWith({
    NavigationPhase? phase,
    RoutePlan? plan,
    Fix? fix,
    bool? following,
    NavigationBadge? badge,
    bool clearBadge = false,
    bool? online,
    bool? recalcPending,
    bool? recalcInFlight,
    String? error,
    bool clearError = false,
    DateTime? lastRecalcAt,
    RouteProgress? progress,
    bool clearProgress = false,
    bool? arrived,
    RouteSummary? summary,
  }) => NavigationState(
    phase: phase ?? this.phase,
    plan: plan ?? this.plan,
    fix: fix ?? this.fix,
    following: following ?? this.following,
    badge: clearBadge ? null : badge ?? this.badge,
    online: online ?? this.online,
    recalcPending: recalcPending ?? this.recalcPending,
    recalcInFlight: recalcInFlight ?? this.recalcInFlight,
    error: clearError ? null : error ?? this.error,
    lastRecalcAt: lastRecalcAt ?? this.lastRecalcAt,
    progress: clearProgress ? null : progress ?? this.progress,
    arrived: arrived ?? this.arrived,
    summary: summary ?? this.summary,
  );

  @override
  List<Object?> get props => [
    phase,
    plan,
    fix,
    following,
    badge,
    online,
    recalcPending,
    recalcInFlight,
    error,
    lastRecalcAt,
    progress,
    arrived,
    summary,
  ];

  @override
  bool get stringify => true;
}

/// Live navigation over one [RoutePlan].
class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit({
    required RoutePlan plan,
    required this._location,
    required this._routes,
    required this._connectivity,
    required this._session,
    required this._tracker,
    DeviationDetector? deviation,
    ArrivalDetector? arrival,
    RecalcPolicy? policy,
    this._estimator = const ProgressEstimator(),
    DateTime Function()? now,
  }) : _deviation = deviation ?? DeviationDetector(),
       _arrival = arrival ?? ArrivalDetector(),
       _policy = policy ?? RecalcPolicy(),
       _now = now ?? DateTime.now,
       _odometer = Odometer(meters: plan.traveledMeters),
       super(NavigationState(plan: plan));

  final LocationService _location;
  final RouteRepository _routes;
  final ConnectivityService _connectivity;
  final SessionState _session;
  final BackgroundTracker _tracker;
  final DeviationDetector _deviation;
  final ArrivalDetector _arrival;
  final RecalcPolicy _policy;
  final ProgressEstimator _estimator;
  final DateTime Function() _now;

  /// Written to the plan only when the plan is saved, not on every fix.
  final Odometer _odometer;

  static const double maxStartAccuracyMeters = 50;

  /// Skipping moves under 5 m saves battery.
  static const int distanceFilterMeters = 5;

  static const Duration badgeDuration = Duration(seconds: 4);

  static const String gpsLostMessage = 'Perdemos o sinal de GPS';

  static const Duration resubscribeDelay = Duration(seconds: 5);

  /// A result or "Finalizar rota" tapped within this of the previous result
  /// is a double tap and is ignored.
  static const Duration recordGuard = Duration(seconds: 1);

  StreamSubscription<Fix>? _positions;
  StreamSubscription<bool>? _online;
  Timer? _badgeTimer;
  Timer? _resubscribeTimer;

  /// Origin of a recalculation deferred while offline.
  Fix? _lastAccepted;

  Fix? _lastPrecise;

  DateTime? _lastRecordAt;

  void prepare() {
    emit(state.copyWith(phase: NavigationPhase.waitingGps));
    _session
      ..onPause = pause
      ..onResume = resume;
    _subscribe();
    _connectivity.check().then((online) {
      if (!isClosed) onOnlineChanged(online);
    });
    _online ??= _connectivity.isOnline.listen(onOnlineChanged);
  }

  /// Starts navigating, with positions in background until navigation ends.
  void start() {
    if (!state.canStart) return;
    _session.isNavigationActive = true;
    final plan = _traveled(state.plan.withStart(_now()));
    emit(
      _measured(
        state.copyWith(
          phase: NavigationPhase.navigating,
          following: true,
          plan: plan,
        ),
      ),
    );
    unawaited(_tracker.start());
    _subscribe();
    unawaited(_routes.save(plan));
  }

  /// Stops tracking and keeps the route. While navigating, the future
  /// completes once the route is saved.
  Future<void> stop() {
    final save = state.phase == NavigationPhase.navigating
        ? _routes.save(_traveled(state.plan))
        : Future<void>.value();
    _cancelAll();
    emit(_measured(state.copyWith(phase: NavigationPhase.idle)));
    return save;
  }

  Future<void> recordDelivered() =>
      _record((at) => StopResult.delivered(at: at));

  Future<void> recordFailed(FailureReason reason) =>
      _record((at) => StopResult.failed(reason, at: at));

  /// Completes a round trip on its way back; ignored otherwise. The button
  /// takes the place of the result buttons, so [recordGuard] applies too.
  Future<void> finishRoute() async {
    if (state.phase != NavigationPhase.navigating || !state.plan.isReturning) {
      return;
    }
    final now = _now();
    final last = _lastRecordAt;
    if (last != null && now.difference(last) < recordGuard) return;
    await _complete(_traveled(state.plan), end: now);
  }

  void recenter() => emit(state.copyWith(following: true));

  void onMapDragged() => emit(state.copyWith(following: false));

  /// The app went to background. Positions pause until [resume], except
  /// while navigating.
  void pause() {
    if (state.phase == NavigationPhase.navigating) {
      unawaited(_routes.save(_traveled(state.plan)));
      return;
    }
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _positions?.cancel();
    _positions = null;
  }

  void resume() {
    if (_positions != null) return;
    if (state.phase == NavigationPhase.navigating ||
        state.phase == NavigationPhase.waitingGps) {
      _subscribe();
    }
  }

  /// Runs a pending recalculation when connectivity returns.
  void onOnlineChanged(bool online) {
    emit(state.copyWith(online: online));
    final fix = _lastAccepted;
    if (online &&
        state.phase == NavigationPhase.navigating &&
        state.recalcPending &&
        !state.recalcInFlight &&
        fix != null) {
      _recalculate(fix.point);
    }
  }

  @override
  Future<void> close() {
    _cancelAll();
    return super.close();
  }

  void _subscribe() {
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _positions?.cancel();
    _positions = _location
        .watch(
          distanceFilterMeters: distanceFilterMeters,
          background: state.phase == NavigationPhase.navigating,
        )
        .listen(_onFix, onError: _onStreamError, onDone: _onStreamEnded);
  }

  /// Clears the session hooks only while they are this cubit's: a stale
  /// cubit closing after a newer one prepared must keep the newer hooks.
  void _cancelAll() {
    if (state.phase == NavigationPhase.navigating) unawaited(_tracker.stop());
    if (_session.onPause == pause) {
      _session
        ..onPause = null
        ..onResume = null
        ..isNavigationActive = false;
    }
    _positions?.cancel();
    _positions = null;
    _online?.cancel();
    _online = null;
    _badgeTimer?.cancel();
    _badgeTimer = null;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
  }

  void _onFix(Fix fix) {
    final precise = fix.accuracyMeters <= maxStartAccuracyMeters;
    if (precise) _lastPrecise = fix;
    final next = state.copyWith(fix: fix, clearError: true);
    emit(precise ? _measured(next) : next);
    if (state.phase == NavigationPhase.navigating) unawaited(_navigate(fix));
  }

  NavigationState _measured(NavigationState next) {
    final fix = _lastPrecise;
    final progress = next.phase == NavigationPhase.navigating && fix != null
        ? _estimator.estimate(next.plan, fix.point, _now())
        : null;
    return next.copyWith(progress: progress, clearProgress: progress == null);
  }

  RoutePlan _traveled(RoutePlan plan) => plan.withTraveled(_odometer.meters);

  void _onStreamError(Object error) => _onStreamEnded();

  void _onStreamEnded() {
    _positions?.cancel();
    _positions = null;
    emit(state.copyWith(error: gpsLostMessage));
    if (state.phase == NavigationPhase.navigating ||
        state.phase == NavigationPhase.waitingGps) {
      _resubscribeTimer?.cancel();
      _resubscribeTimer = Timer(resubscribeDelay, resume);
    }
  }

  /// While arrived, the driver may walk off the road to deliver, so no
  /// deviation is checked. Arrival drops a recalculation deferred offline:
  /// the deviation it answered is over.
  Future<void> _navigate(Fix fix) async {
    _odometer.add(fix);
    if (fix.accuracyMeters <= _deviation.maxAccuracyMeters) _lastAccepted = fix;
    final plan = state.plan;
    if (plan.isReturning && _arrival.isNear(fix, plan.returnTo!)) {
      await _complete(_traveled(plan), end: _now());
      return;
    }
    final next = plan.nextStop;
    if (next != null && _arrival.isArrived(fix, next.stop)) {
      emit(
        state.copyWith(
          arrived: true,
          recalcPending: false,
          clearBadge: state.recalcPending,
        ),
      );
      return;
    }
    if (state.arrived) return;
    final offRoute = _deviation.feed(fix, state.plan.polyline);
    final decision = _policy.decide(
      offRoute: offRoute,
      inFlight: state.recalcInFlight,
      online: state.online,
      now: _now(),
      lastRecalcAt: state.lastRecalcAt,
    );
    switch (decision) {
      case RecalcDecision.run:
        await _recalculate(fix.point);
      case RecalcDecision.deferOffline:
        _badgeTimer?.cancel();
        emit(
          state.copyWith(
            recalcPending: true,
            badge: NavigationBadge.recalcPending,
          ),
        );
      case RecalcDecision.wait || RecalcDecision.none:
        break;
    }
  }

  Future<void> _record(StopResult Function(DateTime at) result) async {
    final next = state.plan.nextStop;
    final now = _now();
    final last = _lastRecordAt;
    if (next == null || (last != null && now.difference(last) < recordGuard)) {
      return;
    }
    _lastRecordAt = now;
    final plan = _traveled(state.plan.record(next.stop.placeId, result(now)));
    _deviation.reset();
    if (plan.isComplete && !plan.isRoundTrip) {
      await _complete(plan, end: now);
    } else {
      emit(_measured(state.copyWith(plan: plan, arrived: false)));
      await _routes.save(plan);
    }
  }

  /// Keeps the navigation active until [close] or [stop], so no re-lock
  /// hides the summary.
  Future<void> _complete(RoutePlan plan, {required DateTime end}) async {
    unawaited(_tracker.stop());
    _positions?.cancel();
    _positions = null;
    _badgeTimer?.cancel();
    emit(
      _measured(
        state.copyWith(
          plan: plan,
          phase: NavigationPhase.completed,
          recalcPending: false,
          clearBadge: true,
          arrived: false,
          summary: RouteSummary.of(
            plan,
            traveledMeters: _odometer.meters,
            end: end,
          ),
        ),
      ),
    );
    await _routes.clear();
  }

  /// Replans from [origin] through the unvisited stops, and back to the start
  /// on a round trip. Results recorded while the request is in flight are
  /// kept; an answer that arrives after completion is dropped.
  Future<void> _recalculate(GeoPoint origin) async {
    final plan = state.plan;
    if (plan.unvisited.isEmpty && !plan.isReturning) return;
    emit(state.copyWith(recalcInFlight: true, recalcPending: false));
    NavigationBadge badge;
    RoutePlan? replaced;
    try {
      replaced = await _routes.plan(
        origin,
        [for (final stop in plan.unvisited) stop.stop],
        keepVisited: [
          for (final stop in plan.stops)
            if (stop.visited) stop,
        ],
        returnTo: plan.returnTo,
      );
      badge = NavigationBadge.recalculated;
    } on Object {
      badge = NavigationBadge.recalcFailed;
    }
    if (isClosed) return;
    if (state.phase == NavigationPhase.completed) {
      if (replaced != null) await _routes.clear();
      if (!isClosed) emit(state.copyWith(recalcInFlight: false));
      return;
    }
    if (replaced != null) {
      _deviation.reset();
      final merged = _traveled(replaced.withProgressFrom(state.plan));
      if (merged != replaced) {
        await _routes.save(merged);
        if (isClosed) return;
        replaced = merged;
      }
    }
    final sameNext =
        replaced == null ||
        replaced.nextStop?.stop == state.plan.nextStop?.stop;
    emit(
      _measured(
        state.copyWith(
          plan: replaced,
          recalcInFlight: false,
          lastRecalcAt: _now(),
          badge: badge,
          arrived: state.arrived && sameNext,
        ),
      ),
    );
    _badgeTimer?.cancel();
    _badgeTimer = Timer(badgeDuration, () {
      if (!isClosed) emit(state.copyWith(clearBadge: true));
    });
  }
}

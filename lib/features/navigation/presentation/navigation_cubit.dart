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
import '../domain/deviation_detector.dart';
import '../domain/recalc_policy.dart';

enum NavigationPhase { idle, waitingGps, navigating, completed }

enum BadgeKind { recalculated, recalcFailed, recalcPending }

/// Transient status shown over the map (RECALC-04, RECALC-05, RECALC-06).
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
  });

  final NavigationPhase phase;
  final RoutePlan plan;

  /// Last known position; kept through stream errors.
  final Fix? fix;

  /// Camera follows the position until the user drags the map (NAV-03).
  final bool following;
  final NavigationBadge? badge;
  final bool online;

  /// Off-route while offline: recalculate on reconnect (RECALC-06).
  final bool recalcPending;
  final bool recalcInFlight;

  /// "Perdemos o sinal de GPS" after a stream error.
  final String? error;
  final DateTime? lastRecalcAt;

  /// "Iniciar" is enabled only on a fix of 50 m or better (NAV-01).
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
  ];

  @override
  bool get stringify => true;
}

/// Live navigation over one [RoutePlan] (NAV-01..NAV-08): position stream,
/// arrival detection, off-route detection with bounded recalculation
/// (RECALC-03..RECALC-07), offline deferral and persistence (OFFL-03,
/// OFFL-05).
class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit({
    required RoutePlan plan,
    required this._location,
    required this._routes,
    required this._connectivity,
    required this._session,
    DeviationDetector? deviation,
    ArrivalDetector? arrival,
    RecalcPolicy? policy,
    DateTime Function()? now,
  }) : _deviation = deviation ?? DeviationDetector(),
       _arrival = arrival ?? ArrivalDetector(),
       _policy = policy ?? RecalcPolicy(),
       _now = now ?? DateTime.now,
       super(NavigationState(plan: plan));

  final LocationService _location;
  final RouteRepository _routes;
  final ConnectivityService _connectivity;
  final SessionState _session;
  final DeviationDetector _deviation;
  final ArrivalDetector _arrival;
  final RecalcPolicy _policy;
  final DateTime Function() _now;

  /// Accuracy gate for "Iniciar" (NAV-01).
  static const double maxStartAccuracyMeters = 50;

  /// Position stream distance filter (NAV-02).
  static const int distanceFilterMeters = 5;

  /// How long a result badge stays visible (RECALC-04, RECALC-05).
  static const Duration badgeDuration = Duration(seconds: 4);

  static const String gpsLostMessage = 'Perdemos o sinal de GPS';

  /// Delay before listening again after the position stream errors or ends.
  static const Duration resubscribeDelay = Duration(seconds: 5);

  StreamSubscription<Fix>? _positions;
  StreamSubscription<bool>? _online;
  Timer? _badgeTimer;
  Timer? _resubscribeTimer;

  /// Last fix accepted by the off-route check (RECALC-02); the origin of a
  /// recalculation deferred while offline.
  Fix? _lastAccepted;

  /// Starts watching the position and connectivity; "Iniciar" waits for a
  /// fix of 50 m or better.
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

  void start() {
    if (!state.canStart) return;
    _session.isNavigationActive = true;
    emit(state.copyWith(phase: NavigationPhase.navigating, following: true));
  }

  /// Stops the streams and leaves the route intact (NAV-07).
  void stop() {
    _cancelAll();
    _session.isNavigationActive = false;
    emit(state.copyWith(phase: NavigationPhase.idle));
  }

  /// "Marcar como visitado" for the next stop (NAV-05).
  Future<void> markNextVisited() async {
    final next = state.plan.nextStop;
    if (next != null) await _visit(next);
  }

  void recenter() => emit(state.copyWith(following: true));

  void onMapDragged() => emit(state.copyWith(following: false));

  /// Pauses the position stream in background (NAV-08); state is kept.
  void pause() {
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _positions?.cancel();
    _positions = null;
  }

  /// Resumes the position stream on foreground (NAV-08).
  void resume() {
    if (_positions != null) return;
    if (state.phase == NavigationPhase.navigating ||
        state.phase == NavigationPhase.waitingGps) {
      _subscribe();
    }
  }

  /// Runs a pending recalculation when connectivity returns (RECALC-06).
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
    _session.isNavigationActive = false;
    return super.close();
  }

  void _subscribe() {
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _positions?.cancel();
    _positions = _location
        .watch(distanceFilterMeters: distanceFilterMeters)
        .listen(_onFix, onError: _onStreamError, onDone: _onStreamEnded);
  }

  void _cancelAll() {
    _session
      ..onPause = null
      ..onResume = null;
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
    emit(state.copyWith(fix: fix, clearError: true));
    if (state.phase == NavigationPhase.navigating) unawaited(_navigate(fix));
  }

  void _onStreamError(Object error) => _onStreamEnded();

  /// The stream errored or ended (edge case): keep the last position, show
  /// the message and listen again after [resubscribeDelay] while tracking.
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

  Future<void> _navigate(Fix fix) async {
    if (fix.accuracyMeters <= _deviation.maxAccuracyMeters) _lastAccepted = fix;
    final next = state.plan.nextStop;
    if (next != null && _arrival.isArrived(fix, next.stop)) {
      return _visit(next);
    }
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

  /// Marks [next] visited and persists (OFFL-03); when every stop is
  /// visited the stream stops and storage is cleared (NAV-06, OFFL-05).
  Future<void> _visit(RouteStop next) async {
    final plan = state.plan.markVisited(next.stop.placeId);
    _deviation.reset();
    if (plan.isComplete) {
      _positions?.cancel();
      _positions = null;
      _badgeTimer?.cancel();
      _session.isNavigationActive = false;
      emit(
        state.copyWith(
          plan: plan,
          phase: NavigationPhase.completed,
          recalcPending: false,
          clearBadge: true,
        ),
      );
      await _routes.clear();
    } else {
      emit(state.copyWith(plan: plan));
      await _routes.save(plan);
    }
  }

  /// One request from [origin] through the unvisited stops (RECALC-03);
  /// the visited ones keep their numbers. Stops visited while the request
  /// is in flight stay visited in the answer; an answer that arrives after
  /// the route completed is dropped and storage cleared again (OFFL-05).
  Future<void> _recalculate(GeoPoint origin) async {
    final plan = state.plan;
    if (plan.unvisited.isEmpty) return;
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
      final visitedNow = [
        for (final stop in state.plan.stops)
          if (stop.visited) stop.stop.placeId,
      ];
      final merged = visitedNow.fold(replaced, (p, id) => p.markVisited(id));
      if (merged != replaced) {
        await _routes.save(merged);
        if (isClosed) return;
        replaced = merged;
      }
    }
    emit(
      state.copyWith(
        plan: replaced,
        recalcInFlight: false,
        lastRecalcAt: _now(),
        badge: badge,
      ),
    );
    _badgeTimer?.cancel();
    _badgeTimer = Timer(badgeDuration, () {
      if (!isClosed) emit(state.copyWith(clearBadge: true));
    });
  }
}

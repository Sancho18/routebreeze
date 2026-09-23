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
  });

  final NavigationPhase phase;
  final RoutePlan plan;

  /// Last known position; kept through stream errors.
  final Fix? fix;

  /// Camera follows the position until the user drags the map.
  final bool following;
  final NavigationBadge? badge;
  final bool online;

  /// Off-route while offline: recalculate on reconnect.
  final bool recalcPending;
  final bool recalcInFlight;

  final String? error;
  final DateTime? lastRecalcAt;

  /// "Iniciar" is enabled only on a fix of 50 m or better.
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

/// Live navigation over one [RoutePlan]: position stream, arrival,
/// off-route recalculation and offline deferral.
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

  static const double maxStartAccuracyMeters = 50;

  /// Position stream distance filter; skipping sub-5 m moves saves battery.
  static const int distanceFilterMeters = 5;

  static const Duration badgeDuration = Duration(seconds: 4);

  static const String gpsLostMessage = 'Perdemos o sinal de GPS';

  static const Duration resubscribeDelay = Duration(seconds: 5);

  StreamSubscription<Fix>? _positions;
  StreamSubscription<bool>? _online;
  Timer? _badgeTimer;
  Timer? _resubscribeTimer;

  /// Last fix accepted by the off-route check; the origin of a
  /// recalculation deferred while offline.
  Fix? _lastAccepted;

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

  /// Stops the streams and leaves the route intact.
  void stop() {
    _cancelAll();
    emit(state.copyWith(phase: NavigationPhase.idle));
  }

  Future<void> markNextVisited() async {
    final next = state.plan.nextStop;
    if (next != null) await _visit(next);
  }

  void recenter() => emit(state.copyWith(following: true));

  void onMapDragged() => emit(state.copyWith(following: false));

  /// Pauses the position stream while the app is in the background; state
  /// is kept.
  void pause() {
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
        .watch(distanceFilterMeters: distanceFilterMeters)
        .listen(_onFix, onError: _onStreamError, onDone: _onStreamEnded);
  }

  /// Cancels every subscription and timer. The session hooks and the active
  /// flag are cleared only while they are this cubit's: a stale cubit closing
  /// after a newer one prepared must not remove the newer one's hooks.
  void _cancelAll() {
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
    emit(state.copyWith(fix: fix, clearError: true));
    if (state.phase == NavigationPhase.navigating) unawaited(_navigate(fix));
  }

  void _onStreamError(Object error) => _onStreamEnded();

  /// Keeps the last position, shows the message and listens again after
  /// [resubscribeDelay] while tracking.
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

  /// Once every stop is visited the stream stops and storage is cleared.
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

  /// One request from [origin] through the unvisited stops; the visited
  /// ones keep their numbers. Stops visited while the request is in flight
  /// stay visited in the answer; an answer that arrives after the route
  /// completed is dropped and storage cleared again.
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

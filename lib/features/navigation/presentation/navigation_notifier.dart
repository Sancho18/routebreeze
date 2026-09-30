import 'dart:async';

import '../data/background_tracker.dart';
import '../data/route_alerts.dart';
import 'navigation_cubit.dart';
import 'notification_copy.dart';
import 'route_summary_sheet.dart';

/// The ongoing notification's texts for a state, with the key whose change
/// sends them at once: the next stop, the arrival and the way back.
typedef _Ongoing = ({
  (String?, bool, bool) key,
  ({String title, String body}) copy,
});

/// Keeps the driver informed outside the app while navigating: the ongoing
/// notification follows the next stop, and arrival, recalculation and
/// completion are alerted while the app is in background.
class NavigationNotifier {
  NavigationNotifier({
    required Stream<NavigationState> states,
    required NavigationState initial,
    required this._tracker,
    required this._alerts,
    required this._inBackground,
    DateTime Function()? now,
  }) : _previous = initial,
       _now = now ?? DateTime.now {
    _states = states.listen(_onState);
  }

  /// Progress changes update the ongoing notification at most this often; a
  /// new next stop, an arrival or the way back update it at once.
  static const Duration throttle = Duration(seconds: 15);

  final BackgroundTracker _tracker;
  final RouteAlerts _alerts;
  final bool Function() _inBackground;
  final DateTime Function() _now;
  late final StreamSubscription<NavigationState> _states;

  NavigationState _previous;

  /// What the ongoing notification shows, and since when; null outside a
  /// navigation.
  _Ongoing? _sent;
  DateTime? _sentAt;

  /// The texts of the last state, sent by [_pending] once [throttle] has
  /// passed since [_sentAt].
  _Ongoing? _latest;
  Timer? _pending;

  /// The app is back in foreground, where the screen shows what the alerts
  /// said.
  void onForeground() => unawaited(_alerts.clear());

  /// Stops following the navigation; an update held back is dropped.
  Future<void> dispose() {
    _end();
    return _states.cancel();
  }

  void _onState(NavigationState state) {
    final previous = _previous;
    _previous = state;
    if (_inBackground()) _alert(previous, state);
    if (state.phase == NavigationPhase.navigating) {
      _updateOngoing(state);
    } else {
      _end();
    }
  }

  /// Shows the events [state] brings over [previous]. The next stop stays
  /// the arrived one until a result is recorded.
  void _alert(NavigationState previous, NavigationState state) {
    if (!previous.arrived && state.arrived) {
      _show(RouteAlert.arrival, arrivalCopy(state.plan.nextStop!));
    }
    if (previous.badge != NavigationBadge.recalculated &&
        state.badge == NavigationBadge.recalculated) {
      _show(
        RouteAlert.recalculated,
        recalculatedCopy(next: state.plan.nextStop),
      );
    }
    if (previous.phase != NavigationPhase.completed &&
        state.phase == NavigationPhase.completed) {
      _show(
        RouteAlert.completed,
        completedCopy(RouteSummarySheet.counts(state.summary!)),
      );
    }
  }

  void _show(RouteAlert kind, ({String title, String body}) copy) =>
      unawaited(_alerts.show(kind, copy.title, copy.body));

  void _updateOngoing(NavigationState state) {
    final plan = state.plan;
    final next = plan.nextStop;
    final latest = _latest = (
      key: (next?.stop.placeId, state.arrived, plan.isReturning),
      copy: ongoingCopy(
        next: next,
        progress: state.progress,
        arrived: state.arrived,
        returning: plan.isReturning,
      ),
    );
    final sent = _sent;
    if (sent == null || latest.key != sent.key) return _send();
    if (latest.copy == sent.copy || _pending != null) return;
    final wait = throttle - _now().difference(_sentAt!);
    if (wait > Duration.zero) {
      _pending = Timer(wait, _send);
    } else {
      _send();
    }
  }

  void _send() {
    _pending?.cancel();
    _pending = null;
    final latest = _sent = _latest!;
    _sentAt = _now();
    unawaited(_tracker.update(latest.copy.title, latest.copy.body));
  }

  void _end() {
    _pending?.cancel();
    _pending = null;
    _sent = null;
  }
}

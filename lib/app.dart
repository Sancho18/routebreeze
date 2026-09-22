import 'package:flutter/material.dart' hide LockState;

import 'core/di/injector.dart';
import 'core/session/session_state.dart';
import 'core/theme/rb_theme.dart';
import 'features/lock/domain/relock_policy.dart';
import 'features/lock/presentation/lock_cubit.dart';
import 'features/addresses/presentation/addresses_screen.dart';
import 'features/location/domain/fix.dart';
import 'features/location/presentation/map_screen.dart';
import 'features/addresses/domain/stop.dart';
import 'features/lock/presentation/lock_screen.dart';
import 'features/navigation/presentation/navigation_screen.dart';
import 'features/route/domain/route_plan.dart';
import 'features/route/presentation/route_screen.dart';

/// Root widget: theme, named routes and the lifecycle re-lock gate.
///
/// [now] is the clock used by the gate (tests inject a fake one).
class RouteBreezeApp extends StatefulWidget {
  const RouteBreezeApp({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  State<RouteBreezeApp> createState() => _RouteBreezeAppState();
}

class _RouteBreezeAppState extends State<RouteBreezeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RouteBreeze',
      theme: buildRbTheme(),
      navigatorKey: _navigatorKey,
      initialRoute: '/lock',
      routes: {
        '/lock': (context) => LockScreen(
          onUnlocked: () => Navigator.of(context).pushReplacementNamed('/map'),
        ),
        '/map': (context) => MapScreen(
          onContinue: (start) =>
              Navigator.of(context).pushNamed('/addresses', arguments: start),
        ),
        '/addresses': (context) {
          final start = ModalRoute.of(context)!.settings.arguments! as Fix;
          return AddressesScreen(
            start: start.point,
            onConfirmed: (stops) => Navigator.of(context)
                .pushNamed('/route', arguments: (start: start, stops: stops)),
          );
        },
        '/route': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments!
                  as ({Fix start, List<Stop> stops});
          return RouteScreen(
            start: args.start,
            stops: args.stops,
            onStart: (plan) => Navigator.of(context).pushNamed(
              '/navigation',
              arguments: (plan: plan, start: args.start),
            ),
          );
        },
        '/navigation': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments!
                  as ({RoutePlan plan, Fix start});
          return NavigationScreen(
            plan: args.plan,
            onExit: () => Navigator.of(context).pop(),
            // The cubit already cleared the persisted route (OFFL-05).
            onNewRoute: () => Navigator.of(context).pushNamedAndRemoveUntil(
              '/addresses',
              (route) => route.settings.name == '/map',
              arguments: args.start,
            ),
          );
        },
      },
      builder: (_, child) => AppLifecycleGate(
        navigatorKey: _navigatorKey,
        now: widget.now,
        child: child!,
      ),
    );
  }
}

/// Records when the app leaves the foreground and, on return, re-locks
/// per [RelockPolicy] (LOCK-07, LOCK-08).
class AppLifecycleGate extends StatefulWidget {
  const AppLifecycleGate({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.now = DateTime.now,
    this.policy = const RelockPolicy(),
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final DateTime Function() now;
  final RelockPolicy policy;

  @override
  State<AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends State<AppLifecycleGate>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _pausedAt ??= widget.now();
      case AppLifecycleState.resumed:
        final pausedAt = _pausedAt;
        _pausedAt = null;
        if (pausedAt != null) _onResumed(widget.now().difference(pausedAt));
      default:
        break;
    }
  }

  void _onResumed(Duration inBackground) {
    final lockCubit = getIt<LockCubit>();
    if (lockCubit.state.status != LockStatus.unlocked) return;
    final relock = widget.policy.shouldRelock(
      inBackground: inBackground,
      navigationActive: getIt<SessionState>().isNavigationActive,
    );
    if (!relock) return;
    lockCubit.lock();
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/lock',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

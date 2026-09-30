import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';

import 'core/di/injector.dart';
import 'core/session/session_state.dart';
import 'core/theme/rb_palette.dart';
import 'core/theme/rb_theme.dart';
import 'core/theme/system_bars.dart';
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

/// Root widget: light and dark themes following the device, named routes,
/// the system bar style and the lifecycle re-lock gate.
///
/// [now] is the clock used by the gate (tests inject a fake one);
/// [navigatorObservers] are forwarded to the root navigator.
class RouteBreezeApp extends StatefulWidget {
  const RouteBreezeApp({
    super.key,
    this.now = DateTime.now,
    this.navigatorObservers = const [],
  });

  final DateTime Function() now;
  final List<NavigatorObserver> navigatorObservers;

  @override
  State<RouteBreezeApp> createState() => _RouteBreezeAppState();
}

class _RouteBreezeAppState extends State<RouteBreezeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  Widget _lockScreen(BuildContext context) => LockScreen(
    onUnlocked: () => Navigator.of(context).pushReplacementNamed('/map'),
  );

  /// Screens behind the lock render the Lock screen until it is unlocked,
  /// so a route reached by any other path shows no route data.
  WidgetBuilder _guarded(WidgetBuilder builder) =>
      (context) => getIt<LockCubit>().state.status == LockStatus.unlocked
      ? builder(context)
      : _lockScreen(context);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RouteBreeze',
      // Debug builds on the simulator, used for the README images, show the
      // app as released.
      debugShowCheckedModeBanner: false,
      theme: buildRbTheme(),
      darkTheme: buildRbTheme(RbPalette.dark),
      themeMode: ThemeMode.system,
      navigatorKey: _navigatorKey,
      navigatorObservers: widget.navigatorObservers,
      initialRoute: '/lock',
      // The platform may hand over its own initial route (Android `route`
      // intent extra, deep link); the app always starts locked.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/lock'),
          builder: _lockScreen,
        ),
      ],
      routes: {
        '/lock': _lockScreen,
        '/map': _guarded(
          (context) => MapScreen(
            onContinue: (start) =>
                Navigator.of(context).pushNamed('/addresses', arguments: start),
            onResume: (plan, start) => Navigator.of(
              context,
            ).pushNamed('/navigation', arguments: (plan: plan, start: start)),
          ),
        ),
        '/addresses': _guarded((context) {
          final start = ModalRoute.of(context)!.settings.arguments! as Fix;
          return AddressesScreen(
            start: start.point,
            onConfirmed: (stops, roundTrip) => Navigator.of(context).pushNamed(
              '/route',
              arguments: (start: start, stops: stops, roundTrip: roundTrip),
            ),
          );
        }),
        '/route': _guarded((context) {
          final args =
              ModalRoute.of(context)!.settings.arguments!
                  as ({Fix start, List<Stop> stops, bool roundTrip});
          return RouteScreen(
            start: args.start,
            stops: args.stops,
            roundTrip: args.roundTrip,
            onStart: (plan) => Navigator.of(context).pushNamed(
              '/navigation',
              arguments: (plan: plan, start: args.start),
            ),
          );
        }),
        '/navigation': _guarded((context) {
          final args =
              ModalRoute.of(context)!.settings.arguments!
                  as ({RoutePlan plan, Fix start});
          return NavigationScreen(
            plan: args.plan,
            onExit: () => Navigator.of(context).pop(),
            // "Nova rota" goes back to the Map screen so the next route starts
            // from a fresh position; the cubit already cleared the persisted one.
            onNewRoute: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/map', (_) => false),
          );
        }),
      },
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: rbSystemBarsFor(Theme.of(context).brightness),
        child: AppLifecycleGate(
          navigatorKey: _navigatorKey,
          now: widget.now,
          child: child!,
        ),
      ),
    );
  }
}

/// Records when the app leaves the foreground and, on return, re-locks
/// per [RelockPolicy]. Tells the live navigation when the app goes to
/// background and comes back; the navigation keeps its position stream
/// while navigating and pauses it while waiting for GPS.
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
        if (_pausedAt == null) {
          _pausedAt = widget.now();
          getIt<SessionState>().onPause?.call();
        }
      case AppLifecycleState.resumed:
        final pausedAt = _pausedAt;
        _pausedAt = null;
        if (pausedAt != null) _onResumed(widget.now().difference(pausedAt));
      default:
        break;
    }
  }

  void _onResumed(Duration inBackground) {
    final session = getIt<SessionState>();
    final lockCubit = getIt<LockCubit>();
    final relock =
        lockCubit.state.status == LockStatus.unlocked &&
        widget.policy.shouldRelock(
          inBackground: inBackground,
          navigationActive: session.isNavigationActive,
        );
    if (!relock) {
      session.onResume?.call();
      return;
    }
    lockCubit.lock();
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/lock',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/app.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/addresses/presentation/addresses_screen.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/lock/presentation/lock_screen.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_screen.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

class MockLocationService extends Mock implements LocationService {}

class MockNavigationCubit extends MockCubit<NavigationState>
    implements NavigationCubit {}

/// Collects the names of the routes pushed on the root navigator.
class _RecordingObserver extends NavigatorObserver {
  final pushed = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
  }
}

void main() {
  late MockLocalAuthService auth;
  late MockLocationService location;
  late DateTime clock;

  setUp(() async {
    await configureDependencies(apiKey: 'test-key');
    auth = MockLocalAuthService();
    getIt.unregister<LocalAuthService>();
    getIt.registerSingleton<LocalAuthService>(auth);
    // The Map screen must not reach the platform: report the service off.
    location = MockLocationService();
    when(() => location.checkAccess())
        .thenAnswer((_) async => LocationAccess.serviceDisabled);
    getIt.unregister<LocationService>();
    getIt.registerSingleton<LocationService>(location);
    // First prompt succeeds; a re-prompt after re-lock is canceled so the
    // Lock screen stays visible.
    var prompts = 0;
    when(() => auth.authenticate()).thenAnswer(
      (_) async => prompts++ == 0 ? AuthResult.success : AuthResult.canceled,
    );
    clock = DateTime(2026, 9, 22, 10);
  });

  tearDown(resetDependencies);

  Future<void> setLifecycle(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );

  Future<void> bootAndUnlock(WidgetTester tester) async {
    await tester.pumpWidget(RouteBreezeApp(now: () => clock));
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
  }

  Future<void> backgroundFor(WidgetTester tester, Duration duration) async {
    await setLifecycle(tester, AppLifecycleState.paused);
    clock = clock.add(duration);
    await setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  group('RouteBreezeApp', () {
    testWidgets('boots on the Lock screen and opens the map after unlocking', (
      tester,
    ) async {
      await bootAndUnlock(tester);
      verify(() => auth.authenticate()).called(1);
    });

    testWidgets('a platform initial route cannot skip the lock (LOCK-01)', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/map';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );

      await tester.pumpWidget(RouteBreezeApp(now: () => clock));

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(MapScreen), findsNothing);
    });

    testWidgets('a platform initial route is replaced by "/lock" as the first '
        'route, not merely guarded (LOCK-01)', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/map';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      // The prompt never answers, so the only route is the initial one.
      when(() => auth.authenticate())
          .thenAnswer((_) => Completer<AuthResult>().future);
      final observer = _RecordingObserver();

      await tester.pumpWidget(
        RouteBreezeApp(now: () => clock, navigatorObservers: [observer]),
      );

      expect(find.byType(LockScreen), findsOneWidget);
      // `onGenerateInitialRoutes` replaced the platform route with `/lock`;
      // the `_guarded` fallback alone would have pushed a `/map` route that
      // merely rendered the Lock screen.
      expect(observer.pushed.first, '/lock');
      expect(observer.pushed, isNot(contains('/map')));
    });

    testWidgets('a route pushed while locked shows the Lock screen, not the '
        'screen behind it (LOCK-01)', (tester) async {
      // The prompt never answers: the app stays locked.
      when(() => auth.authenticate())
          .thenAnswer((_) => Completer<AuthResult>().future);
      await tester.pumpWidget(RouteBreezeApp(now: () => clock));
      await tester.pump();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.pushNamed('/map'));
      // The spinner never settles: pump the route transition instead.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(MapScreen), findsNothing);
    });

    testWidgets('30 s in background re-locks and prompts again', (
      tester,
    ) async {
      await bootAndUnlock(tester);

      await backgroundFor(tester, const Duration(seconds: 30));

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(MapScreen), findsNothing);
      expect(find.text('Autenticação cancelada'), findsOneWidget);
      verify(() => auth.authenticate()).called(2);
    });

    testWidgets('29 s in background keeps the map', (tester) async {
      await bootAndUnlock(tester);

      await backgroundFor(tester, const Duration(seconds: 29));

      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);
      verify(() => auth.authenticate()).called(1);
    });

    testWidgets('does not re-lock while a navigation is active', (
      tester,
    ) async {
      await bootAndUnlock(tester);
      getIt<SessionState>().isNavigationActive = true;

      await backgroundFor(tester, const Duration(minutes: 5));

      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);
      verify(() => auth.authenticate()).called(1);
    });

    testWidgets('"Nova rota" after completion returns to a fresh Map screen '
        'that acquires the position again (NAV-06, ROUTE-01)', (tester) async {
      const origin = GeoPoint(-23.5614, -46.6559);
      final start = Fix(origin, 8, DateTime.utc(2026, 9, 22, 10));
      final completed = RoutePlan(
        origin: origin,
        stops: const [
          RouteStop(
            stop: Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66)),
            order: 1,
            visited: true,
          ),
        ],
        polyline: const [origin, GeoPoint(-23.565, -46.66)],
        distanceMeters: 600,
        durationSeconds: 90,
        legs: const [RouteLeg(distanceMeters: 600, durationSeconds: 90)],
        computedAt: DateTime.utc(2026, 9, 22, 10),
      );
      final navigation = MockNavigationCubit();
      whenListen(
        navigation,
        const Stream<NavigationState>.empty(),
        initialState: NavigationState(
          plan: completed,
          phase: NavigationPhase.completed,
          fix: start,
        ),
      );
      getIt.unregister<NavigationCubit>();
      getIt.registerFactoryParam<NavigationCubit, RoutePlan, void>(
        (_, _) => navigation,
      );
      await bootAndUnlock(tester);
      verify(() => location.checkAccess()).called(1);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.pushNamed(
          '/navigation',
          arguments: (plan: completed, start: start),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(NavigationScreen.completedTitle), findsOneWidget);

      await tester.tap(find.text(NavigationScreen.newRouteLabel));
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(NavigationScreen), findsNothing);
      expect(find.byType(AddressesScreen), findsNothing);
      verify(() => location.checkAccess()).called(1);
    });

    testWidgets('background pauses the navigation and foreground resumes it '
        '(NAV-08)', (tester) async {
      await bootAndUnlock(tester);
      final events = <String>[];
      final session = getIt<SessionState>();
      session.isNavigationActive = true;
      session.onPause = () {
        events.add('pause');
      };
      session.onResume = () {
        events.add('resume');
      };

      await setLifecycle(tester, AppLifecycleState.inactive);
      await setLifecycle(tester, AppLifecycleState.paused);
      expect(events, ['pause']);

      clock = clock.add(const Duration(minutes: 5));
      await setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(events, ['pause', 'resume']);
      expect(find.byType(MapScreen), findsOneWidget);
    });
  });
}

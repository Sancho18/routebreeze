import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/app.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/lock/presentation/lock_screen.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  late MockLocalAuthService auth;
  late DateTime clock;

  setUp(() async {
    await configureDependencies(apiKey: 'test-key');
    auth = MockLocalAuthService();
    getIt.unregister<LocalAuthService>();
    getIt.registerSingleton<LocalAuthService>(auth);
    // The Map screen must not reach the platform: report the service off.
    final location = MockLocationService();
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
  });
}

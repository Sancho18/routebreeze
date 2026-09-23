// Journey through the named routes of RouteBreezeApp with real cubits and
// fake services: LOCK-02, MAP-02, MAP-07, ADDR-02, ADDR-03, ADDR-10,
// ROUTE-03, ROUTE-04, ROUTE-06, NAV-01, NAV-02, NAV-07 and OFFL-04.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/app.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/addresses/domain/suggestion.dart';
import 'package:routebreeze/features/addresses/presentation/addresses_screen.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/lock/presentation/lock_screen.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_screen.dart';
import 'package:routebreeze/features/route/data/route_storage.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_planner.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';

import 'helpers/fake_google_map.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

class MockLocationService extends Mock implements LocationService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockPlacesApi extends Mock implements PlacesApi {}

class MockRoutesApi extends Mock implements RoutesApi {}

class MockRouteStorage extends Mock implements RouteStorage {}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  final start = Fix(origin, 8, DateTime.utc(2026, 9, 22, 10));
  const points = {
    'Rua A': GeoPoint(-23.565, -46.66),
    'Rua B': GeoPoint(-23.60, -46.70),
    'Rua C': GeoPoint(-23.57, -46.65),
  };
  final response = RouteResponse(
    encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [
      RouteLeg(distanceMeters: 4000, durationSeconds: 200),
      RouteLeg(distanceMeters: 4000, durationSeconds: 200),
      RouteLeg(distanceMeters: 4345, durationSeconds: 205),
    ],
    // Typed A, B, C: B is the farthest (destination); C goes before A.
    optimizedIndex: const [1, 0],
  );

  late MockLocationService location;
  late MockRoutesApi routes;
  late MockRouteStorage storage;
  late StreamController<Fix> positions;
  late StreamController<bool> online;

  setUpAll(() {
    registerFallbackValue(origin);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(
      const RouteRequest(
        origin: origin,
        intermediates: [],
        destination: Stop('x', 'x', origin),
      ),
    );
    registerFallbackValue(
      RoutePlan(
        origin: origin,
        stops: const [],
        polyline: const [],
        distanceMeters: 0,
        durationSeconds: 0,
        legs: const [],
        computedAt: DateTime.utc(2026),
      ),
    );
  });

  setUp(() async {
    await configureDependencies(apiKey: 'test-key');
    positions = StreamController<Fix>.broadcast();
    online = StreamController<bool>.broadcast();

    final auth = MockLocalAuthService();
    when(() => auth.authenticate()).thenAnswer((_) async => AuthResult.success);

    location = MockLocationService();
    when(() => location.checkAccess())
        .thenAnswer((_) async => LocationAccess.granted);
    when(() => location.currentFix(timeout: any(named: 'timeout')))
        .thenAnswer((_) async => start);
    when(
      () => location.watch(
        distanceFilterMeters: any(named: 'distanceFilterMeters'),
      ),
    ).thenAnswer((_) => positions.stream);

    final connectivity = MockConnectivityService();
    when(() => connectivity.check()).thenAnswer((_) async => true);
    when(() => connectivity.isOnline).thenAnswer((_) => online.stream);

    final places = MockPlacesApi();
    when(
      () => places.autocomplete(
        input: any(named: 'input'),
        sessionToken: any(named: 'sessionToken'),
        bias: any(named: 'bias'),
      ),
    ).thenAnswer((invocation) async {
      final input = invocation.namedArguments[#input] as String;
      return [Suggestion('id-$input', input, 'São Paulo')];
    });
    when(
      () => places.details(
        placeId: any(named: 'placeId'),
        sessionToken: any(named: 'sessionToken'),
      ),
    ).thenAnswer((invocation) async {
      final placeId = invocation.namedArguments[#placeId] as String;
      final name = placeId.substring('id-'.length);
      return Stop(placeId, '$name, São Paulo', points[name]!);
    });

    routes = MockRoutesApi();
    when(() => routes.computeRoutes(any())).thenAnswer((_) async => response);

    storage = MockRouteStorage();
    when(() => storage.load()).thenAnswer((_) async => null);
    when(() => storage.save(any())).thenAnswer((_) async {});
    when(() => storage.clear()).thenAnswer((_) async {});

    getIt
      ..unregister<LocalAuthService>()
      ..registerSingleton<LocalAuthService>(auth)
      ..unregister<LocationService>()
      ..registerSingleton<LocationService>(location)
      ..unregister<ConnectivityService>()
      ..registerSingleton<ConnectivityService>(connectivity)
      ..unregister<PlacesApi>()
      ..registerSingleton<PlacesApi>(places)
      ..unregister<RoutesApi>()
      ..registerSingleton<RoutesApi>(routes)
      ..unregister<RouteStorage>()
      ..registerSingleton<RouteStorage>(storage);
  });

  tearDown(() async {
    await positions.close();
    await online.close();
    await resetDependencies();
  });

  Future<FakeGoogleMapPlatform> bootToMap(WidgetTester tester) async {
    final platform = FakeGoogleMapPlatform.install(tester);
    await tester.pumpWidget(RouteBreezeApp(now: () => DateTime(2026, 9, 22)));
    expect(find.byType(LockScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    return platform;
  }

  /// Types [name] in field [index], waits the debounce and picks the
  /// suggestion (ADDR-02, ADDR-03).
  Future<void> pickAddress(WidgetTester tester, int index, String name) async {
    await tester.enterText(find.byType(TextField).at(index), name);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
    expect(find.text('$name, São Paulo'), findsOneWidget);
  }

  testWidgets('unlock, start fix, three addresses, optimized route, live '
      'navigation and "Encerrar" back to the route', (tester) async {
    final platform = await bootToMap(tester);

    // MAP-02: the map is on the start fix at zoom 16.
    expect(platform.maps.single.initialCameraPosition['zoom'], 16.0);
    // MAP-07: the start is known, so the action is enabled.
    await tester.tap(find.text(MapScreen.continueLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AddressesScreen), findsOneWidget);
    expect(find.text(AddressesScreen.title), findsOneWidget);

    await pickAddress(tester, 0, 'Rua A');
    await pickAddress(tester, 1, 'Rua B');
    await pickAddress(tester, 2, 'Rua C');

    // ADDR-10 → ROUTE-01: one request with the origin and the three stops.
    await tester.tap(find.text(AddressesScreen.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(RouteScreen), findsOneWidget);
    expect(find.text('Ordem otimizada'), findsOneWidget);
    expect(find.text('12,3 km · 10 min'), findsOneWidget);
    // ROUTE-02/ROUTE-07: optimized order C, A, then the farthest stop B.
    final listed = tester
        .widgetList<Text>(find.textContaining(', São Paulo'))
        .map((t) => t.data)
        .toList();
    expect(listed, [
      'Rua C, São Paulo',
      'Rua A, São Paulo',
      'Rua B, São Paulo',
    ]);
    verify(() => storage.save(any())).called(1);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationScreen), findsOneWidget);
    // NAV-01: no fix yet.
    expect(find.text(NavigationScreen.waitingGpsCaption), findsOneWidget);
    verify(() => location.watch(distanceFilterMeters: 5)).called(1);

    positions.add(Fix(origin, 8, DateTime.utc(2026, 9, 22, 10, 1)));
    await tester.pumpAndSettle();
    expect(find.text(NavigationScreen.waitingGpsCaption), findsNothing);
    await tester.tap(find.text(NavigationScreen.startLabel));
    await tester.pumpAndSettle();
    expect(find.text(NavigationScreen.stopLabel), findsOneWidget);

    // NAV-07: "Encerrar" returns to the Route screen with the route intact.
    await tester.tap(find.text(NavigationScreen.stopLabel));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationScreen), findsNothing);
    expect(find.byType(RouteScreen), findsOneWidget);
    expect(find.text('Ordem otimizada'), findsOneWidget);
    expect(find.text('12,3 km · 10 min'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
  });

  testWidgets('a failed route calculation shows "Tentar novamente" and the '
      'AppBar back returns to the intact address form (ROUTE-06)', (
    tester,
  ) async {
    await bootToMap(tester);
    await tester.tap(find.text(MapScreen.continueLabel));
    await tester.pumpAndSettle();
    await pickAddress(tester, 0, 'Rua A');
    await pickAddress(tester, 1, 'Rua B');
    await pickAddress(tester, 2, 'Rua C');

    when(() => routes.computeRoutes(any()))
        .thenAnswer((_) async => throw const ApiFailure(500, 'boom'));
    await tester.tap(find.text(AddressesScreen.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(RouteScreen), findsOneWidget);
    expect(find.text(RouteScreen.failureMessage), findsOneWidget);
    expect(find.text(RouteScreen.retryLabel), findsOneWidget);
    verifyNever(() => storage.save(any()));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(RouteScreen), findsNothing);
    expect(find.byType(AddressesScreen), findsOneWidget);
    expect(find.text('Rua A, São Paulo'), findsOneWidget);
    expect(find.text('Rua B, São Paulo'), findsOneWidget);
    expect(find.text('Rua C, São Paulo'), findsOneWidget);
    final confirm = tester.widget<RbPrimaryButton>(
      find.widgetWithText(RbPrimaryButton, AddressesScreen.confirmLabel),
    );
    expect(confirm.enabled, isTrue);
  });

  testWidgets('a persisted, unfinished route is offered after unlocking and '
      '"Continuar" opens the navigation with it (OFFL-04)', (tester) async {
    final persisted = RoutePlan(
      origin: origin,
      stops: const [
        RouteStop(
          stop: Stop('id-Rua A', 'Rua A, São Paulo', GeoPoint(-23.565, -46.66)),
          order: 1,
          visited: true,
        ),
        RouteStop(
          stop: Stop('id-Rua B', 'Rua B, São Paulo', GeoPoint(-23.60, -46.70)),
          order: 2,
          visited: false,
        ),
      ],
      polyline: const [origin, GeoPoint(-23.60, -46.70)],
      distanceMeters: 8000,
      durationSeconds: 900,
      legs: const [],
      computedAt: DateTime.utc(2026, 9, 22, 9),
    );
    when(() => storage.load()).thenAnswer((_) async => persisted);

    await bootToMap(tester);
    expect(find.text(MapScreen.resumeTitle), findsOneWidget);

    await tester.tap(find.text(MapScreen.resumeAccept));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationScreen), findsOneWidget);
    expect(find.text('Rua A, São Paulo'), findsOneWidget);
    expect(find.text('Rua B, São Paulo'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(AddressesScreen), findsNothing);
  });
}

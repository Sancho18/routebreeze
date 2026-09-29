// Journey through the named routes of RouteBreezeApp with real cubits and
// fake services.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/app.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/session/session_state.dart';
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
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_screen.dart';
import 'package:routebreeze/features/navigation/presentation/next_stop_card.dart';
import 'package:routebreeze/features/navigation/presentation/return_card.dart';
import 'package:routebreeze/features/navigation/presentation/route_summary_sheet.dart';
import 'package:routebreeze/features/route/data/route_storage.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_planner.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const response = RouteResponse(
    polyline: [
      GeoPoint(38.5, -120.2),
      GeoPoint(40.7, -120.95),
      GeoPoint(43.252, -126.453),
    ],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: [
      RouteLeg(distanceMeters: 4000, durationSeconds: 200, endIndex: 1),
      RouteLeg(distanceMeters: 4000, durationSeconds: 200, endIndex: 1),
      RouteLeg(distanceMeters: 4345, durationSeconds: 205, endIndex: 2),
    ],
    // Typed A, B, C: B is the farthest (destination); C goes before A.
    optimizedIndex: [1, 0],
  );
  // The same stops as a round trip: A, B and C are intermediates, optimized
  // as C, A, B, and a fourth leg goes back to the start.
  const roundTripResponse = RouteResponse(
    polyline: [
      origin,
      GeoPoint(-23.57, -46.65),
      GeoPoint(-23.565, -46.66),
      GeoPoint(-23.60, -46.70),
      origin,
    ],
    distanceMeters: 15000,
    durationSeconds: 1500,
    legs: [
      RouteLeg(distanceMeters: 1500, durationSeconds: 180, endIndex: 1),
      RouteLeg(distanceMeters: 1200, durationSeconds: 150, endIndex: 2),
      RouteLeg(distanceMeters: 6300, durationSeconds: 570, endIndex: 3),
      RouteLeg(distanceMeters: 6000, durationSeconds: 600, endIndex: 4),
    ],
    optimizedIndex: [2, 0, 1],
  );

  late MockLocalAuthService auth;
  late MockLocationService location;
  late MockConnectivityService connectivity;
  late MockPlacesApi places;
  late MockRoutesApi routes;
  late MockRouteStorage storage;
  late StreamController<Fix> positions;
  late StreamController<bool> online;

  /// Clock of the lifecycle gate and of the navigation.
  late DateTime clock;

  /// What [storage] holds once [storeAsJson] backs it: the route as JSON
  /// text, as on the device.
  String? stored;

  /// Puts the fakes in place of the device and network services; the
  /// navigation runs on [clock].
  void registerFakes() {
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
      ..registerSingleton<RouteStorage>(storage)
      ..unregister<NavigationCubit>()
      ..registerFactoryParam<NavigationCubit, RoutePlan, void>(
        (plan, _) => NavigationCubit(
          plan: plan,
          location: getIt<LocationService>(),
          routes: getIt<RouteRepository>(),
          connectivity: getIt<ConnectivityService>(),
          session: getIt<SessionState>(),
          now: () => clock,
        ),
      );
  }

  setUpAll(() {
    registerFallbackValue(origin);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(
      const RouteRequest(
        origin: origin,
        intermediates: [],
        destination: origin,
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
    // First use: no round-trip choice saved.
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(apiKey: 'test-key');
    positions = StreamController<Fix>.broadcast();
    online = StreamController<bool>.broadcast();
    clock = DateTime(2026, 9, 22);
    stored = null;

    auth = MockLocalAuthService();
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

    connectivity = MockConnectivityService();
    when(() => connectivity.check()).thenAnswer((_) async => true);
    when(() => connectivity.isOnline).thenAnswer((_) => online.stream);

    places = MockPlacesApi();
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

    registerFakes();
  });

  tearDown(() async {
    await positions.close();
    await online.close();
    await resetDependencies();
  });

  Future<FakeGoogleMapPlatform> bootToMap(WidgetTester tester) async {
    final platform = FakeGoogleMapPlatform.install(tester);
    await tester.pumpWidget(RouteBreezeApp(now: () => clock));
    expect(find.byType(LockScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    return platform;
  }

  Future<void> setLifecycle(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );

  /// Types [name] in field [index], waits the debounce and picks the
  /// suggestion.
  Future<void> pickAddress(WidgetTester tester, int index, String name) async {
    await tester.enterText(find.byType(TextField).at(index), name);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
    expect(find.text('$name, São Paulo'), findsOneWidget);
  }

  /// Backs [storage] with [stored], starting from [plan] or empty: saves
  /// write the route as JSON text and loads read it back, as on the device.
  void storeAsJson([RoutePlan? plan]) {
    stored = plan == null ? null : jsonEncode(plan.toJson());
    when(() => storage.load()).thenAnswer(
      (_) async => switch (stored) {
        final json? => RoutePlan.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        ),
        null => null,
      },
    );
    when(() => storage.save(any())).thenAnswer((invocation) async {
      final saved = invocation.positionalArguments.single as RoutePlan;
      stored = jsonEncode(saved.toJson());
    });
    when(() => storage.clear()).thenAnswer((_) async {
      stored = null;
    });
  }

  /// Ends the app and opens it again over the same storage, as after the
  /// system killed it, up to the map.
  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await resetDependencies();
    await configureDependencies(apiKey: 'test-key');
    registerFakes();
    await bootToMap(tester);
  }

  /// Continues [plan] from the storage and taps "Iniciar" on a precise fix.
  Future<void> resumeAndStart(WidgetTester tester, RoutePlan plan) async {
    storeAsJson(plan);
    await bootToMap(tester);
    await tester.tap(find.text(MapScreen.resumeAccept));
    await tester.pumpAndSettle();
    positions.add(Fix(origin, 8, DateTime.utc(2026, 9, 22, 10, 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(NavigationScreen.startLabel));
    await tester.pumpAndSettle();
    expect(find.text(NavigationScreen.stopLabel), findsOneWidget);
  }

  /// The position of "Voltar ao ponto de partida" on the addresses screen.
  bool roundTripSwitch(WidgetTester tester) => tester
      .widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, AddressesScreen.roundTripLabel),
      )
      .value;

  /// From the map through the addresses "Rua A", "Rua B" and "Rua C" to the
  /// route screen, optimized as C, A, B; with [roundTrip], "Voltar ao ponto
  /// de partida" is turned on before confirming.
  Future<void> openRoute(WidgetTester tester, {bool roundTrip = false}) async {
    await bootToMap(tester);
    await tester.tap(find.text(MapScreen.continueLabel));
    await tester.pumpAndSettle();
    await pickAddress(tester, 0, 'Rua A');
    await pickAddress(tester, 1, 'Rua B');
    await pickAddress(tester, 2, 'Rua C');
    if (roundTrip) {
      await tester.tap(find.text(AddressesScreen.roundTripLabel));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(AddressesScreen.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(RouteScreen), findsOneWidget);
  }

  /// "Iniciar" on the route screen, a precise fix, then "Iniciar" on the
  /// navigation at the current [clock].
  Future<void> navigateFromRoute(WidgetTester tester) async {
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationScreen), findsOneWidget);
    positions.add(Fix(origin, 8, DateTime.utc(2026, 9, 22, 10, 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(NavigationScreen.startLabel));
    await tester.pumpAndSettle();
    expect(find.text(NavigationScreen.stopLabel), findsOneWidget);
  }

  /// [finder] inside the sheet row of the stop [placeId].
  Finder inRow(String placeId, Finder finder) => find.descendant(
    of: find.byKey(RouteSheet.stopKey(placeId)),
    matching: finder,
  );

  /// Degrees of latitude spanning [meters].
  double lat(double meters) => meters / earthRadiusMeters * 180 / math.pi;

  // Three stops due east of each other with one polyline segment per leg:
  // from a fix due north of a stop, the whole next leg is ahead.
  const stopA = Stop('id-Rua A', 'Rua A, São Paulo', GeoPoint(-23.56, -46.66));
  const stopB = Stop('id-Rua B', 'Rua B, São Paulo', GeoPoint(-23.56, -46.65));
  const stopC = Stop('id-Rua C', 'Rua C, São Paulo', GeoPoint(-23.56, -46.64));
  final threeStops = RoutePlan(
    origin: const GeoPoint(-23.56, -46.67),
    stops: const [
      RouteStop(stop: stopA, order: 1),
      RouteStop(stop: stopB, order: 2),
      RouteStop(stop: stopC, order: 3),
    ],
    polyline: const [
      GeoPoint(-23.56, -46.67),
      GeoPoint(-23.56, -46.66),
      GeoPoint(-23.56, -46.65),
      GeoPoint(-23.56, -46.64),
    ],
    distanceMeters: 3300,
    durationSeconds: 720,
    legs: const [
      RouteLeg(distanceMeters: 1000, durationSeconds: 180, endIndex: 1),
      RouteLeg(distanceMeters: 1100, durationSeconds: 240, endIndex: 2),
      RouteLeg(distanceMeters: 1200, durationSeconds: 300, endIndex: 3),
    ],
    computedAt: DateTime.utc(2026, 9, 22, 9),
  );

  testWidgets('unlock, start fix, three addresses, optimized route, live '
      'navigation and "Encerrar" back to the route', (tester) async {
    final platform = await bootToMap(tester);

    expect(platform.maps.single.initialCameraPosition['zoom'], 16.0);
    await tester.tap(find.text(MapScreen.continueLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AddressesScreen), findsOneWidget);
    expect(find.text(AddressesScreen.title), findsOneWidget);

    await pickAddress(tester, 0, 'Rua A');
    await pickAddress(tester, 1, 'Rua B');
    await pickAddress(tester, 2, 'Rua C');

    await tester.tap(find.text(AddressesScreen.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(RouteScreen), findsOneWidget);
    expect(find.text('Ordem otimizada'), findsOneWidget);
    expect(find.text('12,3 km · 10 min'), findsOneWidget);
    // Optimized order C, A, then the farthest stop B as the destination.
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
    expect(find.text(NavigationScreen.waitingGpsCaption), findsOneWidget);
    verify(() => location.watch(distanceFilterMeters: 5)).called(1);

    positions.add(Fix(origin, 8, DateTime.utc(2026, 9, 22, 10, 1)));
    await tester.pumpAndSettle();
    expect(find.text(NavigationScreen.waitingGpsCaption), findsNothing);
    await tester.tap(find.text(NavigationScreen.startLabel));
    await tester.pumpAndSettle();
    expect(find.text(NavigationScreen.stopLabel), findsOneWidget);

    // "Encerrar" returns to the Route screen with the route intact.
    await tester.tap(find.text(NavigationScreen.stopLabel));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationScreen), findsNothing);
    expect(find.byType(RouteScreen), findsOneWidget);
    expect(find.text('Ordem otimizada'), findsOneWidget);
    expect(find.text('12,3 km · 10 min'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
  });

  testWidgets('with "Voltar ao ponto de partida" on, the route screen asks '
      'for one route from the start back to it with every stop as an '
      'intermediate and lists them as optimized, C, A, B', (tester) async {
    when(() => routes.computeRoutes(any()))
        .thenAnswer((_) async => roundTripResponse);

    await openRoute(tester, roundTrip: true);

    final request =
        verify(() => routes.computeRoutes(captureAny())).captured.single
            as RouteRequest;
    expect(
      request,
      RouteRequest(
        origin: origin,
        intermediates: [
          Stop('id-Rua A', 'Rua A, São Paulo', points['Rua A']!),
          Stop('id-Rua B', 'Rua B, São Paulo', points['Rua B']!),
          Stop('id-Rua C', 'Rua C, São Paulo', points['Rua C']!),
        ],
        destination: origin,
      ),
    );
    final listed = tester
        .widgetList<Text>(find.textContaining(', São Paulo'))
        .map((t) => t.data)
        .toList();
    expect(listed, [
      'Rua C, São Paulo',
      'Rua A, São Paulo',
      'Rua B, São Paulo',
    ]);
    expect(find.text('15,0 km · 25 min'), findsOneWidget);
  });

  testWidgets('"Voltar ao ponto de partida" is off on first use; confirmed '
      'on, it is saved and the addresses screen opens with it on after a '
      'restart', (tester) async {
    when(() => routes.computeRoutes(any()))
        .thenAnswer((_) async => roundTripResponse);
    await bootToMap(tester);
    await tester.tap(find.text(MapScreen.continueLabel));
    await tester.pumpAndSettle();
    expect(roundTripSwitch(tester), isFalse);

    await pickAddress(tester, 0, 'Rua A');
    await pickAddress(tester, 1, 'Rua B');
    await pickAddress(tester, 2, 'Rua C');
    await tester.tap(find.text(AddressesScreen.roundTripLabel));
    await tester.pumpAndSettle();
    expect(roundTripSwitch(tester), isTrue);
    await tester.tap(find.text(AddressesScreen.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(RouteScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('round_trip'), isTrue);

    await restart(tester);
    await tester.tap(find.text(MapScreen.continueLabel));
    await tester.pumpAndSettle();

    expect(find.byType(AddressesScreen), findsOneWidget);
    expect(roundTripSwitch(tester), isTrue);
  });

  testWidgets('a round trip: after the third result the return card and '
      '"Finalizar rota" take over, and "Finalizar rota" shows the summary '
      'timed up to it', (tester) async {
    when(() => routes.computeRoutes(any()))
        .thenAnswer((_) async => roundTripResponse);
    storeAsJson();
    await openRoute(tester, roundTrip: true);
    clock = DateTime(2026, 9, 22, 9);
    await navigateFromRoute(tester);

    for (final minute in [10, 20, 30]) {
      clock = DateTime(2026, 9, 22, 9, minute);
      await tester.tap(find.text(RouteSheet.deliveredLabel));
      await tester.pumpAndSettle();
    }

    expect(find.byType(NextStopCard), findsNothing);
    expect(find.byType(ReturnCard), findsOneWidget);
    expect(find.text(ReturnCard.title), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(3));
    expect(find.text(RouteSheet.returnLabel), findsOneWidget);
    expect(find.text(RouteSheet.deliveredLabel), findsNothing);
    expect(find.text(RouteSheet.notDeliveredLabel), findsNothing);
    final saved = RoutePlan.fromJson(
      jsonDecode(stored!) as Map<String, dynamic>,
    );
    expect(saved.isReturning, isTrue);
    expect(saved.returnTo, origin);

    clock = DateTime(2026, 9, 22, 9, 45);
    await tester.tap(find.text(NavigationScreen.finishLabel));
    await tester.pumpAndSettle();

    expect(find.byType(RouteSheet), findsNothing);
    expect(find.byType(ReturnCard), findsNothing);
    expect(find.text(RouteSummarySheet.title), findsOneWidget);
    expect(find.text('3 entregues'), findsOneWidget);
    expect(find.text('0 m percorridos · 45 min'), findsOneWidget);
    expect(find.text('Início às 09:00 · fim às 09:45'), findsOneWidget);
    expect(stored, isNull);
  });

  testWidgets('a failed route calculation shows "Tentar novamente" and the '
      'AppBar back returns to the intact address form', (tester) async {
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
      '"Continuar" opens the navigation with it', (tester) async {
    final persisted = RoutePlan(
      origin: origin,
      stops: const [
        RouteStop(
          stop: Stop('id-Rua A', 'Rua A, São Paulo', GeoPoint(-23.565, -46.66)),
          order: 1,
          result: StopResult.delivered(),
        ),
        RouteStop(
          stop: Stop('id-Rua B', 'Rua B, São Paulo', GeoPoint(-23.60, -46.70)),
          order: 2,
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

  testWidgets('a completed route stays on screen after 31 s in background: '
      'no lock screen over it', (tester) async {
    final persisted = RoutePlan(
      origin: origin,
      stops: const [
        RouteStop(
          stop: Stop('id-Rua A', 'Rua A, São Paulo', GeoPoint(-23.565, -46.66)),
          order: 1,
        ),
      ],
      polyline: const [origin, GeoPoint(-23.565, -46.66)],
      distanceMeters: 600,
      durationSeconds: 90,
      legs: const [],
      computedAt: DateTime.utc(2026, 9, 22, 9),
    );
    when(() => storage.load()).thenAnswer((_) async => persisted);
    await bootToMap(tester);
    await tester.tap(find.text(MapScreen.resumeAccept));
    await tester.pumpAndSettle();
    positions.add(Fix(origin, 8, DateTime.utc(2026, 9, 22, 10, 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(NavigationScreen.startLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RouteSheet.deliveredLabel));
    await tester.pumpAndSettle();
    expect(find.text(RouteSummarySheet.title), findsOneWidget);

    await setLifecycle(tester, AppLifecycleState.paused);
    clock = clock.add(const Duration(seconds: 31));
    await setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationScreen), findsOneWidget);
    expect(find.text(RouteSummarySheet.title), findsOneWidget);
    expect(find.text(RouteSummarySheet.newRouteLabel), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(MapScreen), findsNothing);
  });

  testWidgets('a 3-stop route: "Entregue", then "Não entregue" → "Recusado" '
      'show a check and an "×" with "Recusado" in the list and move the '
      'card to the third stop; after a restart, "Continuar" shows the same '
      'results', (tester) async {
    await resumeAndStart(tester, threeStops);

    await tester.tap(find.text(RouteSheet.deliveredLabel));
    await tester.pumpAndSettle();
    clock = clock.add(const Duration(seconds: 2));
    await tester.tap(find.text(RouteSheet.notDeliveredLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recusado'));
    await tester.pumpAndSettle();

    void expectResults() {
      expect(inRow('id-Rua A', find.byIcon(Icons.check)), findsOneWidget);
      expect(inRow('id-Rua B', find.byIcon(Icons.close)), findsOneWidget);
      expect(inRow('id-Rua B', find.text('Recusado')), findsOneWidget);
      expect(inRow('id-Rua C', find.text('3')), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    }

    expectResults();
    expect(
      tester.widget<NextStopCard>(find.byType(NextStopCard)).stop,
      const RouteStop(stop: stopC, order: 3),
    );

    await restart(tester);
    expect(find.text(MapScreen.resumeTitle), findsOneWidget);
    await tester.tap(find.text(MapScreen.resumeAccept));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationScreen), findsOneWidget);
    expectResults();
  });

  testWidgets('a fix 30 m from the next stop shows "Você chegou" and records '
      'nothing; "Entregue" moves the card to the next stop with its distance '
      'and time', (tester) async {
    await resumeAndStart(tester, threeStops);
    clock = DateTime(2026, 9, 22, 14, 28);
    final card = find.byType(NextStopCard);

    positions.add(
      Fix(
        GeoPoint(-23.56 + lat(30), -46.66),
        8,
        DateTime.utc(2026, 9, 22, 10, 2),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<NextStopCard>(card).stop,
      const RouteStop(stop: stopA, order: 1),
    );
    expect(
      find.descendant(of: card, matching: find.text('Você chegou')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tap(find.text(RouteSheet.deliveredLabel));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NextStopCard>(card).stop,
      const RouteStop(stop: stopB, order: 2),
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('1,1 km · 4 min · chegada às 14:32'),
      ),
      findsOneWidget,
    );
    expect(find.text('Você chegou'), findsNothing);
    expect(inRow('id-Rua A', find.byIcon(Icons.check)), findsOneWidget);
  });

  testWidgets('a 4-stop route finished with one "Não entregue" shows the '
      'summary; "Nova rota" opens the map with no saved route', (tester) async {
    final fourStops = RoutePlan(
      origin: const GeoPoint(-23.56, -46.67),
      stops: const [
        RouteStop(stop: stopA, order: 1),
        RouteStop(stop: stopB, order: 2),
        RouteStop(stop: stopC, order: 3),
        RouteStop(
          stop: Stop('id-Rua D', 'Rua D, São Paulo', GeoPoint(-23.56, -46.63)),
          order: 4,
        ),
      ],
      polyline: const [
        GeoPoint(-23.56, -46.67),
        GeoPoint(-23.56, -46.66),
        GeoPoint(-23.56, -46.65),
        GeoPoint(-23.56, -46.64),
        GeoPoint(-23.56, -46.63),
      ],
      distanceMeters: 4600,
      durationSeconds: 1080,
      legs: const [],
      computedAt: DateTime.utc(2026, 9, 22, 8),
    ).withStart(DateTime(2026, 9, 22, 8, 40)).withTraveled(12430);
    clock = DateTime(2026, 9, 22, 9, 41);
    await resumeAndStart(tester, fourStops);

    /// Taps [label] with the clock on [minute] past nine.
    Future<void> recordAt(int minute, String label) async {
      clock = DateTime(2026, 9, 22, 9, minute);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await recordAt(42, RouteSheet.deliveredLabel);
    await recordAt(43, RouteSheet.deliveredLabel);
    await recordAt(44, RouteSheet.notDeliveredLabel);
    await tester.tap(find.text('Endereço não encontrado'));
    await tester.pumpAndSettle();
    await recordAt(45, RouteSheet.deliveredLabel);

    expect(find.byType(RouteSheet), findsNothing);
    expect(find.text('Rota concluída'), findsOneWidget);
    expect(find.text('3 entregues · 1 não entregue'), findsOneWidget);
    expect(find.text('12,4 km percorridos · 1 h 05 min'), findsOneWidget);
    expect(find.text('Início às 08:40 · fim às 09:45'), findsOneWidget);
    expect(find.text('Parada 3 · Rua C, São Paulo'), findsOneWidget);
    expect(find.text('Endereço não encontrado'), findsOneWidget);

    await tester.tap(find.text(RouteSummarySheet.newRouteLabel));
    await tester.pumpAndSettle();

    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(NavigationScreen), findsNothing);
    expect(find.text(MapScreen.resumeTitle), findsNothing);
    expect(stored, isNull);
  });

  group('back on the route screen', () {
    // The typed "Rua A", second in the optimized order C, A, B.
    final secondStop = RouteStop(
      stop: Stop('id-Rua A', 'Rua A, São Paulo', points['Rua A']!),
      order: 2,
    );

    testWidgets('two backs from the navigation while the stop save runs land '
        'on the route screen', (tester) async {
      storeAsJson();
      await openRoute(tester);
      await navigateFromRoute(tester);
      // The stop save waits here, as a slow write on the device would.
      final writing = Completer<void>();
      when(() => storage.save(any())).thenAnswer((invocation) async {
        await writing.future;
        final saved = invocation.positionalArguments.single as RoutePlan;
        stored = jsonEncode(saved.toJson());
      });

      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      writing.complete();
      await tester.pumpAndSettle();

      expect(find.byType(RouteScreen), findsOneWidget);
      expect(find.byType(NavigationScreen), findsNothing);
      expect(find.byType(AddressesScreen), findsNothing);
    });

    testWidgets('the system back on the summary opens the map with no saved '
        'route, like "Nova rota", instead of the route screen', (tester) async {
      storeAsJson();
      await openRoute(tester);
      clock = DateTime(2026, 9, 22, 9);
      await navigateFromRoute(tester);
      for (final minute in [1, 2, 3]) {
        clock = DateTime(2026, 9, 22, 9, minute);
        await tester.tap(find.text(RouteSheet.deliveredLabel));
        await tester.pumpAndSettle();
      }
      expect(find.text('Rota concluída'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(RouteScreen), findsNothing);
      expect(find.byType(NavigationScreen), findsNothing);
      expect(find.text(MapScreen.resumeTitle), findsNothing);
      expect(stored, isNull);
    });

    testWidgets('"Encerrar" returns to the route with stop 1 delivered and '
        '"Iniciar" continues from stop 2: the summary counts every result '
        'with the first start and the distance driven before "Encerrar"', (
      tester,
    ) async {
      storeAsJson();
      await openRoute(tester);

      clock = DateTime(2026, 9, 22, 9);
      await navigateFromRoute(tester);
      // 100 m driven before the first result.
      positions
        ..add(Fix(origin, 8, DateTime.utc(2026, 9, 22, 10, 2)))
        ..add(
          Fix(
            GeoPoint(origin.lat + lat(100), origin.lng),
            8,
            DateTime.utc(2026, 9, 22, 10, 3),
          ),
        );
      await tester.pumpAndSettle();
      clock = DateTime(2026, 9, 22, 9, 5);
      await tester.tap(find.text(RouteSheet.deliveredLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(NavigationScreen.stopLabel));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationScreen), findsNothing);
      expect(find.byType(RouteScreen), findsOneWidget);
      expect(inRow('id-Rua C', find.byIcon(Icons.check)), findsOneWidget);
      expect(inRow('id-Rua A', find.text('2')), findsOneWidget);
      expect(inRow('id-Rua B', find.text('3')), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      clock = DateTime(2026, 9, 22, 9, 10);
      await navigateFromRoute(tester);
      expect(
        tester.widget<NextStopCard>(find.byType(NextStopCard)).stop,
        secondStop,
      );

      clock = DateTime(2026, 9, 22, 9, 15);
      await tester.tap(find.text(RouteSheet.deliveredLabel));
      await tester.pumpAndSettle();
      clock = DateTime(2026, 9, 22, 9, 25);
      await tester.tap(find.text(RouteSheet.notDeliveredLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recusado'));
      await tester.pumpAndSettle();

      expect(find.text(RouteSummarySheet.title), findsOneWidget);
      expect(find.text('2 entregues · 1 não entregue'), findsOneWidget);
      expect(find.text('100 m percorridos · 25 min'), findsOneWidget);
      expect(find.text('Início às 09:00 · fim às 09:25'), findsOneWidget);
      expect(find.text('Parada 3 · Rua B, São Paulo'), findsOneWidget);
      expect(find.text('Recusado'), findsOneWidget);
    });

    testWidgets('the system back from the navigation also returns to the '
        'route with stop 1 delivered, and "Iniciar" continues from stop 2', (
      tester,
    ) async {
      storeAsJson();
      await openRoute(tester);
      await navigateFromRoute(tester);
      await tester.tap(find.text(RouteSheet.deliveredLabel));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationScreen), findsNothing);
      expect(find.byType(RouteScreen), findsOneWidget);
      expect(inRow('id-Rua C', find.byIcon(Icons.check)), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await navigateFromRoute(tester);
      expect(
        tester.widget<NextStopCard>(find.byType(NextStopCard)).stop,
        secondStop,
      );
    });
  });
}

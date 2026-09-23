// Smoke test of the main flow on a device: unlock → map ready → three
// addresses picked from suggestions → optimized route with three numbered
// stops. Device and network boundaries (biometrics, GPS, connectivity,
// Places, Routes) are fakes registered over the production wiring; the
// `GoogleMap` widgets are real, so the run needs the API key:
//
//   flutter test integration_test -d <deviceId> --dart-define-from-file=env.json
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routebreeze/app.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/core/widgets/rb_route_loader.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/addresses/domain/suggestion.dart';
import 'package:routebreeze/features/addresses/presentation/addresses_screen.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/route/data/route_storage.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_planner.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';

const GeoPoint start = GeoPoint(-23.5645, -46.6527);

/// The three stops in the order they are typed (A, B, C). Rua Augusta is
/// the farthest from [start], so the planner makes it the destination and
/// sends Paulista and Oscar Freire as intermediates, in that order.
const Stop paulista = Stop(
  'pl-paulista',
  'Av. Paulista, 1000 - Bela Vista, São Paulo',
  GeoPoint(-23.5658, -46.6500),
);
const Stop augusta = Stop(
  'pl-augusta',
  'Rua Augusta, 500 - Consolação, São Paulo',
  GeoPoint(-23.5530, -46.6530),
);
const Stop oscarFreire = Stop(
  'pl-oscar-freire',
  'Rua Oscar Freire, 100 - Jardins, São Paulo',
  GeoPoint(-23.5650, -46.6620),
);

/// start → Oscar Freire → Paulista → Augusta, Google polyline encoding.
const String encodedPolyline = 'bmynCjzv{GbBby@~C_jA_oAvQ';

class FakeLocalAuthService implements LocalAuthService {
  @override
  Future<AuthResult> authenticate() async => AuthResult.success;
}

class FakeLocationService implements LocationService {
  @override
  Future<LocationAccess> checkAccess() async => LocationAccess.granted;

  @override
  Future<LocationAccess> requestPermission() async => LocationAccess.granted;

  @override
  Future<Fix> currentFix({Duration timeout = const Duration(seconds: 15)}) =>
      Future.value(Fix(start, 10, DateTime.now()));

  @override
  Stream<Fix> watch({int distanceFilterMeters = 5}) => const Stream.empty();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class FakeConnectivityService implements ConnectivityService {
  @override
  Stream<bool> get isOnline => const Stream.empty();

  @override
  Future<bool> check() async => true;
}

/// One suggestion per known street; details resolve by placeId.
class FakePlacesApi implements PlacesApi {
  static const Map<String, Stop> byPlaceId = {
    'pl-paulista': paulista,
    'pl-augusta': augusta,
    'pl-oscar-freire': oscarFreire,
  };

  @override
  Future<List<Suggestion>> autocomplete({
    required String input,
    required String sessionToken,
    required GeoPoint bias,
  }) async {
    final query = input.toLowerCase();
    return [
      for (final stop in byPlaceId.values)
        if (stop.address.toLowerCase().contains(query))
          Suggestion(
            stop.placeId,
            stop.address.split(' - ').first,
            'São Paulo',
          ),
    ];
  }

  @override
  Future<Stop> details({
    required String placeId,
    required String sessionToken,
  }) async => byPlaceId[placeId]!;
}

/// Fixed answer: the API "reorders" the intermediates (index [1, 0]).
class FakeRoutesApi implements RoutesApi {
  RouteRequest? lastRequest;

  @override
  Future<RouteResponse> computeRoutes(RouteRequest request) async {
    lastRequest = request;
    return const RouteResponse(
      encodedPolyline: encodedPolyline,
      distanceMeters: 4200,
      durationSeconds: 900,
      legs: [
        RouteLeg(distanceMeters: 1100, durationSeconds: 240),
        RouteLeg(distanceMeters: 1400, durationSeconds: 300),
        RouteLeg(distanceMeters: 1700, durationSeconds: 360),
      ],
      optimizedIndex: [1, 0],
    );
  }
}

void _replace<T extends Object>(T instance) {
  getIt
    ..unregister<T>()
    ..registerSingleton<T>(instance);
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for $finder to go away');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder primaryButton(String label) =>
    find.widgetWithText(RbPrimaryButton, label);

Finder enabledPrimaryButton(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is RbPrimaryButton && widget.label == label && widget.enabled,
);

/// Types [query] into the [index]-th field, waits past the debounce and
/// picks the single suggestion.
Future<void> pickAddress(WidgetTester tester, int index, String query) async {
  await tester.enterText(find.byType(TextField).at(index), query);
  await tester.pump(const Duration(milliseconds: 400));
  final suggestion = find.byType(ListTile);
  await pumpUntil(tester, suggestion);
  expect(suggestion, findsOneWidget);
  await tester.tap(suggestion);
  await pumpUntil(
    tester,
    find.text(
      FakePlacesApi.byPlaceId.values
          .firstWhere((stop) => stop.address.contains(query))
          .address,
    ),
  );
}

/// The number badge shown on the sheet row of [stop].
String orderOf(WidgetTester tester, Stop stop) {
  final row = find.byKey(RouteSheet.stopKey(stop.placeId));
  expect(row, findsOneWidget);
  final badge = tester.widget<Text>(
    find.descendant(of: row, matching: find.byType(Text)).first,
  );
  return badge.data!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeRoutesApi routesApi;

  setUp(() async {
    await configureDependencies();
    routesApi = FakeRoutesApi();
    _replace<LocalAuthService>(FakeLocalAuthService());
    _replace<LocationService>(FakeLocationService());
    _replace<ConnectivityService>(FakeConnectivityService());
    _replace<PlacesApi>(FakePlacesApi());
    _replace<RoutesApi>(routesApi);
    // A route left by an earlier run would trigger "Continuar rota?".
    await getIt<RouteStorage>().clear();
  });

  tearDown(() async {
    await getIt<RouteStorage>().clear();
    await resetDependencies();
  });

  testWidgets('unlock → map → three addresses → optimized route', (
    tester,
  ) async {
    await tester.pumpWidget(const RouteBreezeApp());

    // Lock: the prompt runs on the first frame and succeeds.
    await pumpUntil(tester, find.byType(MapScreen));

    // Map: start fix accepted, the loading fades and "Para onde vamos?"
    // becomes enabled.
    await pumpUntil(tester, enabledPrimaryButton(MapScreen.continueLabel));
    await pumpUntilGone(tester, find.byType(RbRouteLoader));
    await tester.tap(primaryButton(MapScreen.continueLabel));
    await pumpUntil(tester, find.byType(AddressesScreen));
    expect(find.text(AddressesScreen.title), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    // Addresses: one suggestion picked per field, in typed order A, B, C.
    await pickAddress(tester, 0, 'Av. Paulista');
    await pickAddress(tester, 1, 'Rua Augusta');
    await pickAddress(tester, 2, 'Rua Oscar Freire');
    await pumpUntil(tester, enabledPrimaryButton(AddressesScreen.confirmLabel));
    await tester.ensureVisible(primaryButton(AddressesScreen.confirmLabel));
    await tester.tap(primaryButton(AddressesScreen.confirmLabel));

    // Route: one computeRoutes call, farthest stop as destination.
    await pumpUntil(tester, find.byType(RouteScreen));
    await pumpUntil(tester, find.text(RouteSheet.heading));
    final request = routesApi.lastRequest!;
    expect(request.origin, start);
    expect(request.destination, augusta);
    expect(request.intermediates, [paulista, oscarFreire]);

    // Sheet: three rows numbered in the optimized order, destination last.
    expect(orderOf(tester, oscarFreire), '1');
    expect(orderOf(tester, paulista), '2');
    expect(orderOf(tester, augusta), '3');
    expect(find.text('4,2 km · 15 min'), findsOneWidget);
    expect(primaryButton('Iniciar'), findsOneWidget);
  });
}

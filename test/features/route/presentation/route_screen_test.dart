import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/core/widgets/rb_feedback.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';
import 'package:routebreeze/features/route/presentation/route_cubit.dart';
import 'package:routebreeze/features/route/presentation/route_map_objects.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';

class MockRouteCubit extends MockCubit<RouteState> implements RouteCubit {}

class MockConnectivityService extends Mock implements ConnectivityService {}

/// Canvas drawing needs real async; the fake answers with a hue per number.
class FakeMapMarkers extends MapMarkers {
  @override
  Future<BitmapDescriptor> numbered(int n, {double pixelRatio = 3}) async =>
      BitmapDescriptor.defaultMarkerWithHue(n * 10);
}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  const stops = [a, b];
  final start = Fix(origin, 12, DateTime.utc(2026, 9, 22, 10));
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: b, order: 1, visited: false),
      RouteStop(stop: a, order: 2, visited: false),
    ],
    polyline: const [origin, GeoPoint(-23.60, -46.70)],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );
  const mapKey = Key('map-placeholder');

  late MockRouteCubit cubit;
  late MockConnectivityService connectivity;
  late StreamController<bool> online;
  late List<RouteMapObjects> mapsBuilt;
  late List<RoutePlan> started;

  setUp(() {
    cubit = MockRouteCubit();
    connectivity = MockConnectivityService();
    online = StreamController<bool>();
    mapsBuilt = [];
    started = [];
    when(() => cubit.compute(any(), any())).thenAnswer((_) async {});
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => connectivity.check()).thenAnswer((_) async => true);
    when(() => connectivity.isOnline).thenAnswer((_) => online.stream);
  });

  tearDown(() => online.close());

  setUpAll(() {
    registerFallbackValue(origin);
    registerFallbackValue(const <Stop>[]);
  });

  Future<void> pumpScreen(WidgetTester tester, RouteState state) async {
    whenListen(cubit, const Stream<RouteState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: RouteScreen(
          start: start,
          stops: stops,
          cubit: cubit,
          connectivity: connectivity,
          markers: FakeMapMarkers(),
          mapBuilder: (_, objects) {
            mapsBuilt.add(objects);
            return const SizedBox.expand(key: mapKey);
          },
          onStart: started.add,
        ),
      ),
    );
    await tester.pump();
  }

  group('RouteScreen', () {
    testWidgets('computes the route on open and shows the loading indicator '
        'with its caption (ROUTE-05)', (tester) async {
      await pumpScreen(tester, const RouteState(status: RouteStatus.loading));

      verify(() => cubit.compute(origin, stops)).called(1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final caption = tester.widget<Text>(
        find.text('Calculando a melhor rota...'),
      );
      expect(caption.style!.fontSize, 13);
      expect(caption.style!.color, RbColors.inkMuted);
      expect(find.byType(RouteSheet), findsNothing);
      expect(find.byKey(mapKey), findsNothing);
      expect(mapsBuilt, isEmpty);
    });

    testWidgets('failure shows the copy in danger with "Tentar novamente" '
        'that retries, and a way back to Addresses (ROUTE-06)', (tester) async {
      await pumpScreen(
        tester,
        const RouteState(
          status: RouteStatus.failure,
          failure: ApiFailure(null, 'Resposta inválida da Routes API'),
        ),
      );

      final message = tester.widget<Text>(
        find.text('Não foi possível calcular a rota.'),
      );
      expect(message.style!.color, RbColors.danger);
      expect(message.style!.fontSize, 15);
      expect(find.byType(RouteSheet), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
      verify(() => cubit.retry()).called(1);
    });

    testWidgets('ready draws the map objects for the plan and shows the '
        'sheet; "Iniciar" hands the plan over (ROUTE-03, ROUTE-04)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RouteState(status: RouteStatus.ready, plan: plan),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(mapKey), findsOneWidget);
      final objects = mapsBuilt.last;
      expect(objects.markers.map((m) => m.markerId.value), {
        'start',
        'stop-pb',
        'stop-pa',
      });
      final first = objects.markers.singleWhere(
        (m) => m.markerId.value == 'stop-pb',
      );
      expect(first.icon.toJson(), ['defaultMarker', 10.0]);
      final second = objects.markers.singleWhere(
        (m) => m.markerId.value == 'stop-pa',
      );
      expect(second.icon.toJson(), ['defaultMarker', 20.0]);
      final line = objects.polylines.single;
      expect(line.color, RbColors.brand);
      expect(line.width, 5);
      expect(line.points, const [
        LatLng(-23.5614, -46.6559),
        LatLng(-23.60, -46.70),
      ]);
      expect(objects.bounds.southwest, const LatLng(-23.60, -46.70));
      expect(objects.bounds.northeast, const LatLng(-23.5614, -46.6559));

      final sheet = tester.widget<RouteSheet>(find.byType(RouteSheet));
      expect(sheet.plan, plan);
      expect(sheet.startEnabled, isTrue);
      expect(find.text('Ordem otimizada'), findsOneWidget);
      expect(find.text('12,3 km · 10 min'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Iniciar'));
      expect(started, [plan]);
    });

    testWidgets('offline shows the "Sem conexão" danger banner on top and '
        'hides it once back online (OFFL-01)', (tester) async {
      await pumpScreen(
        tester,
        RouteState(status: RouteStatus.ready, plan: plan),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão'), findsNothing);

      online.add(false);
      await tester.pumpAndSettle();

      final banner = tester.widget<RbBanner>(
        find.widgetWithText(RbBanner, 'Sem conexão'),
      );
      expect(banner.tone, RbTone.danger);
      expect(
        tester.getTopLeft(find.byType(RbBanner)).dy,
        lessThan(tester.getTopLeft(find.byKey(mapKey)).dy),
      );
      expect(find.byType(RouteSheet), findsOneWidget);

      online.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão'), findsNothing);
    });

    testWidgets('an offline initial check shows the banner without waiting '
        'for a change (OFFL-01)', (tester) async {
      when(() => connectivity.check()).thenAnswer((_) async => false);

      await pumpScreen(tester, const RouteState(status: RouteStatus.loading));
      await tester.pump();

      expect(find.text('Sem conexão'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

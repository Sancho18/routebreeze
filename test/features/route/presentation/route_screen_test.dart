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
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';
import 'package:routebreeze/features/route/presentation/route_cubit.dart';
import 'package:routebreeze/features/route/presentation/route_map_objects.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';
import 'package:routebreeze/features/route/presentation/stop_badge.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

class MockRouteCubit extends MockCubit<RouteState> implements RouteCubit {}

class MockRouteRepository extends Mock implements RouteRepository {}

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
      RouteStop(stop: b, order: 1),
      RouteStop(stop: a, order: 2),
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
  late List<EdgeInsets> paddings;
  late List<RoutePlan> started;

  setUp(() {
    cubit = MockRouteCubit();
    connectivity = MockConnectivityService();
    online = StreamController<bool>();
    mapsBuilt = [];
    paddings = [];
    started = [];
    when(() => cubit.compute(any(), any())).thenAnswer((_) async {});
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.refreshFromSaved()).thenAnswer((_) async {});
    when(() => connectivity.check()).thenAnswer((_) async => true);
    when(() => connectivity.isOnline).thenAnswer((_) => online.stream);
  });

  tearDown(() => online.close());

  setUpAll(() {
    registerFallbackValue(origin);
    registerFallbackValue(const <Stop>[]);
  });

  /// Pumps the screen in [state]: in a bare `MaterialApp`, or in the app
  /// themes when [mode] is given. [settle] pumps once more, so a ready map
  /// gets its marker icons.
  Future<void> pumpScreen(
    WidgetTester tester,
    RouteState state, {
    ThemeMode? mode,
    bool settle = true,
  }) async {
    whenListen(cubit, const Stream<RouteState>.empty(), initialState: state);
    final screen = RouteScreen(
      start: start,
      stops: stops,
      cubit: cubit,
      connectivity: connectivity,
      markers: FakeMapMarkers(),
      mapBuilder: (_, objects, padding) {
        mapsBuilt.add(objects);
        paddings.add(padding);
        return const SizedBox.expand(key: mapKey);
      },
      onStart: (plan) async => started.add(plan),
    );
    await tester.pumpWidget(
      mode == null ? MaterialApp(home: screen) : themedApp(screen, mode: mode),
    );
    if (settle) await tester.pump();
  }

  group('RouteScreen', () {
    testWidgets('computes the route on open and shows the loading indicator '
        'with its caption', (tester) async {
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
        'that retries, and a way back to Addresses', (tester) async {
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
      expect(message.style!.color, const Color(0xFFD01E23));
      expect(message.style!.fontSize, 15);
      expect(find.byType(RouteSheet), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
      verify(() => cubit.retry()).called(1);
    });

    testWidgets('ready draws the map objects for the plan and shows the '
        'sheet; "Iniciar" hands the plan over', (tester) async {
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

    testWidgets('when the navigation opened by "Iniciar" closes, the sheet '
        'shows the saved route of the same stops ("Parada 1, entregue") and '
        '"Iniciar" hands that route over', (tester) async {
      final semantics = tester.ensureSemantics();
      final saved = plan
          .withStart(DateTime.utc(2026, 9, 22, 10, 35))
          .record(
            'pb',
            StopResult.delivered(at: DateTime.utc(2026, 9, 22, 10, 50)),
          )
          .withTraveled(850);
      final repository = MockRouteRepository();
      when(() => repository.plan(origin, stops)).thenAnswer((_) async => plan);
      when(() => repository.loadActive()).thenAnswer((_) async => saved);
      final routeCubit = RouteCubit(repository);
      addTearDown(routeCubit.close);
      final navigation = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: RouteScreen(
            start: start,
            stops: stops,
            cubit: routeCubit,
            connectivity: connectivity,
            markers: FakeMapMarkers(),
            mapBuilder: (_, _, _) => const SizedBox.expand(key: mapKey),
            onStart: (plan) {
              started.add(plan);
              return navigation.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      String firstBadge() => tester
          .getSemantics(
            find.descendant(
              of: find.byKey(RouteSheet.stopKey('pb')),
              matching: find.byType(StopBadge),
            ),
          )
          .label;
      expect(firstBadge(), 'Parada 1');

      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Iniciar'));
      await tester.pumpAndSettle();
      expect(started, [plan]);
      verifyNever(() => repository.loadActive());
      expect(firstBadge(), 'Parada 1');

      navigation.complete();
      await tester.pumpAndSettle();

      verify(() => repository.loadActive()).called(1);
      expect(tester.widget<RouteSheet>(find.byType(RouteSheet)).plan, saved);
      expect(firstBadge(), 'Parada 1, entregue');

      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Iniciar'));
      await tester.pumpAndSettle();
      expect(started, [plan, saved]);
      semantics.dispose();
    });

    testWidgets('the map is padded at the bottom by the sheet, so the route '
        'is fitted in the part left visible', (tester) async {
      await pumpScreen(
        tester,
        RouteState(status: RouteStatus.ready, plan: plan),
      );
      await tester.pumpAndSettle();

      expect(
        paddings.last,
        EdgeInsets.only(bottom: tester.getSize(find.byType(RouteSheet)).height),
      );
    });

    testWidgets('offline shows the "Sem conexão" danger banner on top and '
        'hides it once back online', (tester) async {
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
        'for a change', (tester) async {
      when(() => connectivity.check()).thenAnswer((_) async => false);

      await pumpScreen(tester, const RouteState(status: RouteStatus.loading));
      await tester.pump();

      expect(find.text('Sem conexão'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('RouteScreen in dark mode', () {
    Color background(WidgetTester tester) => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(Scaffold),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    testWidgets('loading on #0F1115 with the caption in #A4ACB9', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const RouteState(status: RouteStatus.loading),
        mode: ThemeMode.dark,
      );

      expect(background(tester), const Color(0xFF0F1115));
      expect(
        tester
            .widget<Text>(find.text('Calculando a melhor rota...'))
            .style!
            .color,
        const Color(0xFFA4ACB9),
      );
    });

    testWidgets('failure on #0F1115 with the message in #EB7074 and '
        '"Tentar novamente" in #7EA6F8', (tester) async {
      await pumpScreen(
        tester,
        const RouteState(
          status: RouteStatus.failure,
          failure: ApiFailure(null, 'Resposta inválida da Routes API'),
        ),
        mode: ThemeMode.dark,
      );

      expect(background(tester), const Color(0xFF0F1115));
      expect(
        tester
            .widget<Text>(find.text('Não foi possível calcular a rota.'))
            .style!
            .color,
        const Color(0xFFEB7074),
      );
      final retry = tester.widget<RichText>(
        find.descendant(
          of: find.widgetWithText(TextButton, 'Tentar novamente'),
          matching: find.byType(RichText),
        ),
      );
      expect(retry.text.style!.color, const Color(0xFF7EA6F8));
    });

    testWidgets('ready: the map area is #0F1115 until the marker icons exist', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RouteState(status: RouteStatus.ready, plan: plan),
        mode: ThemeMode.dark,
        settle: false,
      );

      expect(find.byKey(mapKey), findsNothing);
      final placeholder = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(FutureBuilder<RouteMapObjects>),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(placeholder.color, const Color(0xFF0F1115));
    });
  });

  group('RouteScreen accessibility', () {
    final ready = RouteState(status: RouteStatus.ready, plan: plan);
    // Each state with a text that proves it is on screen, and whether the
    // connectivity check answers online.
    final states = <String, (RouteState, String, bool)>{
      'loading': (
        const RouteState(status: RouteStatus.loading),
        RouteScreen.loadingMessage,
        true,
      ),
      'failure': (
        const RouteState(
          status: RouteStatus.failure,
          failure: ApiFailure(null, 'Resposta inválida da Routes API'),
        ),
        RouteScreen.failureMessage,
        true,
      ),
      'ready with the sheet': (ready, RouteSheet.heading, true),
      'offline': (ready, RouteScreen.offlineBanner, false),
    };

    Future<void> pumpState(
      WidgetTester tester,
      (RouteState, String, bool) entry,
      ThemeMode mode,
    ) async {
      final (state, text, isOnline) = entry;
      when(() => connectivity.check()).thenAnswer((_) async => isOnline);
      await pumpScreen(tester, state, mode: mode);
      // The loading spinner never settles.
      if (state.status != RouteStatus.loading) await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final MapEntry(key: name, value: entry) in states.entries) {
        testWidgets('$name meets the contrast, tap target and label '
            'guidelines in ${mode.name} mode', (tester) async {
          await pumpState(tester, entry, mode);

          await expectAccessibleGuidelines(tester);
        });
      }
    }

    for (final MapEntry(key: name, value: entry) in states.entries) {
      testWidgets('$name lays out at 200% text on a 360×800 phone', (
        tester,
      ) async {
        await setLargeTextPhone(tester);
        await pumpState(tester, entry, ThemeMode.light);

        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
      });
    }
  });
}

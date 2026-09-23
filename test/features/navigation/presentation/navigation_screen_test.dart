import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/core/widgets/rb_feedback.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_screen.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';

class MockNavigationCubit extends MockCubit<NavigationState>
    implements NavigationCubit {}

/// Canvas drawing needs real async; the fake answers with a hue per number
/// and a fixed hue for the position dot.
class FakeMapMarkers extends MapMarkers {
  static const double positionHue = 200;

  @override
  Future<BitmapDescriptor> numbered(int n, {double pixelRatio = 3}) async =>
      BitmapDescriptor.defaultMarkerWithHue(n * 10);

  @override
  Future<BitmapDescriptor> position({double pixelRatio = 3}) async =>
      BitmapDescriptor.defaultMarkerWithHue(positionHue);
}

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(stop: a, order: 1, visited: false),
      RouteStop(stop: b, order: 2, visited: false),
    ],
    polyline: const [origin, GeoPoint(-23.60, -46.70)],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );
  final fix = Fix(
    const GeoPoint(-23.562, -46.656),
    50,
    DateTime.utc(2026, 9, 22, 10, 31),
  );
  const mapKey = Key('map-placeholder');

  late MockNavigationCubit cubit;
  late List<NavigationMapModel> mapsBuilt;
  late int exits;
  late int newRoutes;

  setUp(() {
    mapsBuilt = [];
    exits = 0;
    newRoutes = 0;
  });

  /// A fresh mock and screen key per pump: a kept `State` would keep the
  /// previous cubit and state.
  Future<void> pumpScreen(WidgetTester tester, NavigationState state) async {
    cubit = MockNavigationCubit();
    when(() => cubit.markNextVisited()).thenAnswer((_) async {});
    whenListen(
      cubit,
      const Stream<NavigationState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NavigationScreen(
          key: UniqueKey(),
          plan: plan,
          cubit: cubit,
          markers: FakeMapMarkers(),
          mapBuilder: (_, model) {
            mapsBuilt.add(model);
            return const SizedBox.expand(key: mapKey);
          },
          onExit: () => exits++,
          onNewRoute: () => newRoutes++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RbPrimaryButton primary(WidgetTester tester, String label) => tester
      .widget<RbPrimaryButton>(find.widgetWithText(RbPrimaryButton, label));

  Set<String> markerIds(NavigationMapModel model) =>
      model.markers.map((m) => m.markerId.value).toSet();

  group('NavigationScreen', () {
    testWidgets('prepares on open; without a good fix it shows '
        '"Aguardando sinal de GPS" and keeps "Iniciar" disabled', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        NavigationState(plan: plan, phase: NavigationPhase.waitingGps),
      );

      verify(() => cubit.prepare()).called(1);
      expect(primary(tester, 'Iniciar').enabled, isFalse);
      final caption = tester.widget<Text>(find.text('Aguardando sinal de GPS'));
      expect(caption.style!.fontSize, 13);
      expect(caption.style!.color, RbColors.inkMuted);
      expect(find.text('Marcar como visitado'), findsNothing);
      expect(find.text('Encerrar'), findsNothing);
      expect(find.text('Recentralizar'), findsNothing);
      expect(find.byType(RbBanner), findsNothing);

      expect(find.byKey(mapKey), findsOneWidget);
      final model = mapsBuilt.last;
      expect(markerIds(model), {'start', 'stop-pa', 'stop-pb'});
      expect(model.target, const LatLng(-23.5614, -46.6559));
      expect(model.following, isTrue);
      final line = model.polylines.single;
      expect(line.color, RbColors.brand);
      expect(line.width, 5);
      expect(line.points, const [
        LatLng(-23.5614, -46.6559),
        LatLng(-23.60, -46.70),
      ]);
    });

    testWidgets('a fix of 50 m enables "Iniciar", which starts the cubit, '
        'and draws the current-position marker', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.waitingGps,
          fix: fix,
        ),
      );

      expect(primary(tester, 'Iniciar').enabled, isTrue);
      expect(primary(tester, 'Iniciar').color, RbColors.brand);
      expect(find.text('Marcar como visitado'), findsNothing);
      expect(find.text('Aguardando sinal de GPS'), findsNothing);
      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Iniciar'));
      verify(() => cubit.start()).called(1);

      final model = mapsBuilt.last;
      expect(markerIds(model), {'start', 'stop-pa', 'stop-pb', 'me'});
      final me = model.markers.singleWhere((m) => m.markerId.value == 'me');
      expect(me.position, const LatLng(-23.562, -46.656));
      expect(me.icon.toJson(), ['defaultMarker', FakeMapMarkers.positionHue]);
      expect(me.anchor, const Offset(0.5, 0.5));
      expect(model.target, const LatLng(-23.562, -46.656));
    });

    testWidgets('navigating: "Encerrar" stops and exits, "Marcar como '
        'visitado" marks the next stop, visited stops leave the map', (
      tester,
    ) async {
      final visited = plan.markVisited('pa');
      await pumpScreen(
        tester,
        NavigationState(
          plan: visited,
          phase: NavigationPhase.navigating,
          fix: fix,
        ),
      );

      expect(find.text('Iniciar'), findsNothing);
      expect(find.text('Aguardando sinal de GPS'), findsNothing);
      expect(primary(tester, 'Encerrar').enabled, isTrue);
      expect(primary(tester, 'Encerrar').color, RbColors.danger);
      expect(tester.widget<RouteSheet>(find.byType(RouteSheet)).plan, visited);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Visitado'), findsNothing);

      final markVisited = find.widgetWithText(
        RbPrimaryButton,
        'Marcar como visitado',
      );
      expect(primary(tester, 'Marcar como visitado').color, RbColors.brand);
      expect(
        tester.getBottomLeft(markVisited).dy,
        lessThan(
          tester
              .getTopLeft(find.widgetWithText(RbPrimaryButton, 'Encerrar'))
              .dy,
        ),
      );
      await tester.tap(markVisited);
      verify(() => cubit.markNextVisited()).called(1);

      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Encerrar'));
      verify(() => cubit.stop()).called(1);
      expect(exits, 1);

      final model = mapsBuilt.last;
      expect(markerIds(model), {'start', 'stop-pb', 'me'});
      final second = model.markers.singleWhere(
        (m) => m.markerId.value == 'stop-pb',
      );
      expect(second.icon.toJson(), ['defaultMarker', 20.0]);
    });

    testWidgets('shows the badge text per kind: warning for recalculated and '
        'pending, danger for failed', (tester) async {
      const cases = [
        (NavigationBadge.recalculated, 'Rota recalculada', RbColors.warning),
        (NavigationBadge.recalcFailed, 'Falha ao recalcular', RbColors.danger),
        (
          NavigationBadge.recalcPending,
          'Recálculo pendente (sem conexão)',
          RbColors.warning,
        ),
      ];
      for (final (badge, text, color) in cases) {
        await pumpScreen(
          tester,
          NavigationState(
            plan: plan,
            phase: NavigationPhase.navigating,
            fix: fix,
            badge: badge,
          ),
        );

        expect(find.byType(RbStatusChip), findsOneWidget);
        final label = tester.widget<Text>(find.text(text));
        expect(label.style!.color, color);
        expect(label.style!.fontSize, 13);
      }
    });

    testWidgets('no badge → no chip', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(plan: plan, phase: NavigationPhase.navigating),
      );

      expect(find.byType(RbStatusChip), findsNothing);
    });

    testWidgets('offline shows the "Sem conexão" banner in danger', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          online: false,
        ),
      );

      final banner = tester.widget<RbBanner>(find.byType(RbBanner));
      expect(banner.text, 'Sem conexão');
      expect(banner.tone, RbTone.danger);
      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Sem conexão'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.color, RbColors.danger);
    });

    testWidgets('a stream error shows "Perdemos o sinal de GPS" in danger', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          error: 'Perdemos o sinal de GPS',
        ),
      );

      final text = tester.widget<Text>(find.text('Perdemos o sinal de GPS'));
      expect(text.style!.color, RbColors.danger);
      expect(markerIds(mapsBuilt.last), contains('me'));
    });

    testWidgets('a recalculation badge and the GPS error show together, '
        'badge above the error', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          badge: NavigationBadge.recalculated,
          error: 'Perdemos o sinal de GPS',
        ),
      );

      final chip = find.widgetWithText(RbStatusChip, 'Rota recalculada');
      final error = find.text('Perdemos o sinal de GPS');
      expect(chip, findsOneWidget);
      expect(error, findsOneWidget);
      expect(
        tester.getBottomLeft(chip).dy,
        lessThanOrEqualTo(tester.getTopLeft(error).dy - RbSpace.s2),
      );
    });

    testWidgets('"Recentralizar" appears only while not following and '
        'recenters', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          following: false,
        ),
      );

      expect(find.text('Recentralizar'), findsOneWidget);
      expect(mapsBuilt.last.following, isFalse);
      await tester.tap(find.text('Recentralizar'));
      verify(() => cubit.recenter()).called(1);

      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          following: true,
        ),
      );

      expect(find.text('Recentralizar'), findsNothing);
      expect(mapsBuilt.last.following, isTrue);
    });

    testWidgets('dragging the map while following reports onMapDragged; a '
        'tap or a tiny move does not', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          following: true,
        ),
      );

      // The placeholder map has no hittable content; the detector above it
      // still receives the pointer events. Touch the upper part of the map,
      // away from the sheet that covers its lower half.
      final point =
          tester.getTopLeft(find.byKey(mapKey)) + const Offset(120, 120);
      await tester.tapAt(point);
      await tester.dragFrom(point, const Offset(4, 4));
      await tester.pump();
      verifyNever(() => cubit.onMapDragged());

      await tester.dragFrom(point, const Offset(0, -80));
      await tester.pump();
      verify(() => cubit.onMapDragged()).called(1);
    });

    testWidgets('dragging the map while not following reports nothing', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          following: false,
        ),
      );

      await tester.dragFrom(
        tester.getTopLeft(find.byKey(mapKey)) + const Offset(120, 120),
        const Offset(0, -80),
      );
      await tester.pump();

      verifyNever(() => cubit.onMapDragged());
    });

    testWidgets('completed replaces the sheet with "Rota concluída" in '
        'success and "Nova rota"', (tester) async {
      final done = plan.markVisited('pa').markVisited('pb');
      await pumpScreen(
        tester,
        NavigationState(
          plan: done,
          phase: NavigationPhase.completed,
          fix: fix,
          following: false,
        ),
      );

      final title = tester.widget<Text>(find.text('Rota concluída'));
      expect(title.style!.color, RbColors.success);
      expect(title.style!.fontSize, 17);
      expect(find.byType(RouteSheet), findsNothing);
      expect(find.text('Encerrar'), findsNothing);
      expect(find.text('Recentralizar'), findsNothing);

      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Nova rota'));
      expect(newRoutes, 1);
      expect(markerIds(mapsBuilt.last), {'start', 'me'});
    });
  });
}

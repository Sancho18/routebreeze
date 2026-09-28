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
import 'package:routebreeze/features/navigation/data/navigation_app_launcher.dart';
import 'package:routebreeze/features/navigation/domain/navigation_app.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_screen.dart';
import 'package:routebreeze/features/navigation/presentation/next_stop_card.dart';
import 'package:routebreeze/features/navigation/presentation/open_in_app_sheet.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

class MockNavigationCubit extends MockCubit<NavigationState>
    implements NavigationCubit {}

class MockNavigationAppLauncher extends Mock implements NavigationAppLauncher {}

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
  late MockNavigationAppLauncher launcher;
  late List<NavigationMapModel> mapsBuilt;
  late int exits;
  late int newRoutes;

  setUpAll(() {
    registerFallbackValue(NavigationApp.waze);
    registerFallbackValue(a);
  });

  setUp(() {
    launcher = MockNavigationAppLauncher();
    mapsBuilt = [];
    exits = 0;
    newRoutes = 0;
  });

  /// A fresh mock and screen key per pump: a kept `State` would keep the
  /// previous cubit and state. The screen is in a bare `MaterialApp`, or in
  /// the app themes when [mode] is given; [settle] waits for the marker
  /// icons and the map.
  Future<void> pumpScreen(
    WidgetTester tester,
    NavigationState state, {
    ThemeMode? mode,
    bool settle = true,
  }) async {
    cubit = MockNavigationCubit();
    when(() => cubit.markNextVisited()).thenAnswer((_) async {});
    whenListen(
      cubit,
      const Stream<NavigationState>.empty(),
      initialState: state,
    );
    final screen = NavigationScreen(
      key: UniqueKey(),
      plan: plan,
      cubit: cubit,
      markers: FakeMapMarkers(),
      appLauncher: launcher,
      mapBuilder: (_, model) {
        mapsBuilt.add(model);
        return const SizedBox.expand(key: mapKey);
      },
      onExit: () => exits++,
      onNewRoute: () => newRoutes++,
    );
    await tester.pumpWidget(
      mode == null ? MaterialApp(home: screen) : themedApp(screen, mode: mode),
    );
    if (settle) await tester.pumpAndSettle();
  }

  RbPrimaryButton primary(WidgetTester tester, String label) => tester
      .widget<RbPrimaryButton>(find.widgetWithText(RbPrimaryButton, label));

  /// The painted fill of the primary button labeled [label].
  Color? fillOf(WidgetTester tester, String label) => tester
      .widget<Material>(
        find
            .descendant(
              of: find.widgetWithText(RbPrimaryButton, label),
              matching: find.byType(Material),
            )
            .first,
      )
      .color;

  Set<String> markerIds(NavigationMapModel model) =>
      model.markers.map((m) => m.markerId.value).toSet();

  /// A point on the map between the next stop card and the sheet, where the
  /// map itself (not an overlay) takes the touch.
  Offset visibleMap(WidgetTester tester) => Offset(
    120,
    (tester.getBottomLeft(find.byType(NextStopCard)).dy +
            tester.getTopLeft(find.byType(RouteSheet)).dy) /
        2,
  );

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
      expect(fillOf(tester, 'Iniciar'), RbColors.brand);
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
      expect(primary(tester, 'Encerrar').color, const Color(0xFFD01E23));
      expect(tester.widget<RouteSheet>(find.byType(RouteSheet)).plan, visited);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Visitado'), findsNothing);

      final markVisited = find.widgetWithText(
        RbPrimaryButton,
        'Marcar como visitado',
      );
      expect(
        tester
            .widget<Material>(
              find
                  .descendant(of: markVisited, matching: find.byType(Material))
                  .first,
            )
            .color,
        RbColors.brand,
      );
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
        (NavigationBadge.recalculated, 'Rota recalculada', Color(0xFF996206)),
        (
          NavigationBadge.recalcFailed,
          'Falha ao recalcular',
          Color(0xFFD01E23),
        ),
        (
          NavigationBadge.recalcPending,
          'Recálculo pendente (sem conexão)',
          Color(0xFF996206),
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
      expect(box.color, const Color(0xFFD01E23));
    });

    testWidgets('a stream error shows "Perdemos o sinal de GPS" in danger, '
        'announced as a live region', (tester) async {
      final semantics = tester.ensureSemantics();
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
      expect(text.style!.color, const Color(0xFFD01E23));
      expect(markerIds(mapsBuilt.last), contains('me'));
      expect(
        tester
            .getSemantics(find.byType(RbInlineError))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      semantics.dispose();
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

    testWidgets('"Recentralizar" has its label in #1B63F3 and its icon in '
        'brand #2A6DF4', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          following: false,
        ),
        mode: ThemeMode.light,
      );

      RichText rendered(Finder finder) => tester.widget<RichText>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      );
      expect(
        rendered(find.text('Recentralizar')).text.style!.color,
        const Color(0xFF1B63F3),
      );
      expect(
        rendered(find.byIcon(Icons.my_location)).text.style!.color,
        const Color(0xFF2A6DF4),
      );
    });

    testWidgets('a touch beside "Recentralizar" reaches the map', (
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

      final button = tester.getRect(find.byType(FloatingActionButton));
      final beside = Offset(button.left - 40, button.center.dy);
      // The detector above the map: the placeholder itself is not hittable.
      final mapListener = tester.renderObject(
        find
            .ancestor(of: find.byKey(mapKey), matching: find.byType(Listener))
            .first,
      );
      expect(
        tester
            .hitTestOnBinding(beside)
            .path
            .any((entry) => entry.target == mapListener),
        isTrue,
      );
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
      // still receives the pointer events. Touch the map between the card
      // and the sheet, which cover its edges.
      final point = visibleMap(tester);
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

      await tester.dragFrom(visibleMap(tester), const Offset(0, -80));
      await tester.pump();

      verifyNever(() => cubit.onMapDragged());
    });

    testWidgets('completed replaces the sheet with "Rota concluída" in '
        'successStrong and "Nova rota"', (tester) async {
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
      expect(title.style!.color, const Color(0xFF0D7F4A));
      expect(title.style!.fontSize, 17);
      expect(find.byType(RouteSheet), findsNothing);
      expect(find.text('Encerrar'), findsNothing);
      expect(find.text('Recentralizar'), findsNothing);

      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Nova rota'));
      expect(newRoutes, 1);
      expect(markerIds(mapsBuilt.last), {'start', 'me'});
    });
    group('next stop and what is left', () {
      final progress = RouteProgress(
        next: const RouteStop(stop: a, order: 1, visited: false),
        toNextMeters: 1234,
        toNextSeconds: 250,
        remainingMeters: 8400,
        remainingSeconds: 1320,
        at: DateTime.utc(2026, 9, 22, 14, 28),
      );

      testWidgets('navigating: the next stop card on top of the map with its '
          'progress, and the sheet totals replaced by what is left', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          NavigationState(
            plan: plan,
            phase: NavigationPhase.navigating,
            fix: fix,
            progress: progress,
          ),
        );

        final card = tester.widget<NextStopCard>(find.byType(NextStopCard));
        expect(card.stop, plan.stops.first);
        expect(card.progress, progress);
        expect(find.text('1,2 km · 4 min · chegada às 14:32'), findsOneWidget);
        expect(
          find.text('Faltam 8,4 km · 22 min · término às 14:50'),
          findsOneWidget,
        );
        expect(find.text('12,3 km · 10 min'), findsNothing);
        final cardTop = tester.getTopLeft(find.byType(NextStopCard));
        expect(cardTop.dy, tester.getTopLeft(find.byKey(mapKey)).dy + 16);
        expect(cardTop.dx, 16);
      });

      testWidgets('navigating without progress yet: the card shows the stop '
          'only and the sheet keeps the plan totals', (tester) async {
        await pumpScreen(
          tester,
          NavigationState(
            plan: plan.markVisited('pa'),
            phase: NavigationPhase.navigating,
            fix: fix,
          ),
        );

        final card = tester.widget<NextStopCard>(find.byType(NextStopCard));
        expect(card.stop, const RouteStop(stop: b, order: 2, visited: false));
        expect(card.progress, isNull);
        expect(find.textContaining('chegada às'), findsNothing);
        expect(find.text('12,3 km · 10 min'), findsOneWidget);
      });

      testWidgets('before "Iniciar" there is no card and the sheet shows the '
          'plan totals, even with a progress in state', (tester) async {
        await pumpScreen(
          tester,
          NavigationState(
            plan: plan,
            phase: NavigationPhase.waitingGps,
            fix: fix,
            progress: progress,
          ),
        );

        expect(find.byType(NextStopCard), findsNothing);
        expect(find.text('12,3 km · 10 min'), findsOneWidget);
        expect(find.textContaining('Faltam'), findsNothing);
      });

      testWidgets('the card stays on top: the recalculation badge and the GPS '
          'error follow it, space-2 apart', (tester) async {
        await pumpScreen(
          tester,
          NavigationState(
            plan: plan,
            phase: NavigationPhase.navigating,
            fix: fix,
            badge: NavigationBadge.recalculated,
            error: 'Perdemos o sinal de GPS',
            progress: progress,
          ),
        );

        final card = find.byType(NextStopCard);
        final chip = find.widgetWithText(RbStatusChip, 'Rota recalculada');
        expect(
          tester.getTopLeft(chip).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(card).dy + RbSpace.s2),
        );
        expect(
          tester.getTopLeft(find.text('Perdemos o sinal de GPS')).dy,
          greaterThan(tester.getBottomLeft(chip).dy),
        );
      });
    });
    group('map padding', () {
      final progress = RouteProgress(
        next: const RouteStop(stop: a, order: 1, visited: false),
        toNextMeters: 1234,
        toNextSeconds: 250,
        remainingMeters: 8400,
        remainingSeconds: 1320,
        at: DateTime.utc(2026, 9, 22, 14, 28),
      );
      NavigationState navigating({
        bool online = true,
        bool following = true,
        NavigationBadge? badge,
      }) => NavigationState(
        plan: plan,
        phase: NavigationPhase.navigating,
        fix: fix,
        progress: progress,
        online: online,
        following: following,
        badge: badge,
      );

      testWidgets('top is the next stop card with its margin, bottom is the '
          'sheet: the camera centers the position between them', (
        tester,
      ) async {
        await pumpScreen(tester, navigating());

        final mapTop = tester.getTopLeft(find.byKey(mapKey)).dy;
        final padding = mapsBuilt.last.padding;
        expect(
          padding.top,
          tester.getBottomLeft(find.byType(NextStopCard)).dy - mapTop,
        );
        expect(padding.bottom, tester.getSize(find.byType(RouteSheet)).height);
        expect(padding.left, 0);
        expect(padding.right, 0);
      });

      testWidgets('the offline banner adds to the top; a badge and '
          '"Recentralizar" change nothing', (tester) async {
        await pumpScreen(tester, navigating());
        final base = mapsBuilt.last.padding;

        await pumpScreen(
          tester,
          navigating(badge: NavigationBadge.recalculated, following: false),
        );
        expect(find.text('Recentralizar'), findsOneWidget);
        expect(mapsBuilt.last.padding, base);

        await pumpScreen(tester, navigating(online: false));
        expect(
          mapsBuilt.last.padding.top,
          base.top + tester.getSize(find.byType(RbBanner)).height,
        );
        expect(mapsBuilt.last.padding.bottom, base.bottom);
      });

      testWidgets('before "Iniciar" only the sheet pads the map', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          NavigationState(plan: plan, phase: NavigationPhase.waitingGps),
        );

        final padding = mapsBuilt.last.padding;
        expect(padding.top, 0);
        expect(padding.bottom, tester.getSize(find.byType(RouteSheet)).height);
      });
    });
    testWidgets('"Abrir em outro app" on the card offers the apps for the '
        'next stop and hands it to the chosen one', (tester) async {
      when(() => launcher.open(any(), any())).thenAnswer((_) async => true);
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan.markVisited('pa'),
          phase: NavigationPhase.navigating,
          fix: fix,
        ),
      );

      await tester.tap(find.byTooltip('Abrir em outro app'));
      await tester.pumpAndSettle();
      expect(find.byType(OpenInAppSheet), findsOneWidget);

      await tester.tap(find.text('Google Maps'));
      await tester.pumpAndSettle();

      verify(() => launcher.open(NavigationApp.googleMaps, b)).called(1);
      expect(find.byType(OpenInAppSheet), findsNothing);
    });
  });

  group('NavigationScreen in dark mode', () {
    testWidgets('"Encerrar" is #EB7074 with a #0F1115 label', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
        ),
        mode: ThemeMode.dark,
      );

      expect(fillOf(tester, 'Encerrar'), const Color(0xFFEB7074));
      expect(
        tester.widget<Text>(find.text('Encerrar')).style!.color,
        const Color(0xFF0F1115),
      );
    });

    testWidgets('"Recentralizar" is #1A1D23 with its icon and label in '
        '#7EA6F8', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          following: false,
        ),
        mode: ThemeMode.dark,
      );

      final button = find.byType(FloatingActionButton);
      expect(
        tester
            .widget<Material>(
              find
                  .descendant(of: button, matching: find.byType(Material))
                  .first,
            )
            .color,
        const Color(0xFF1A1D23),
      );
      RichText rendered(Finder finder) => tester.widget<RichText>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      );
      expect(
        rendered(find.text('Recentralizar')).text.style!.color,
        const Color(0xFF7EA6F8),
      );
      expect(
        rendered(find.byIcon(Icons.my_location)).text.style!.color,
        const Color(0xFF7EA6F8),
      );
    });

    testWidgets('the recalculation chip sits on a #1A1D23 backdrop', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan,
          phase: NavigationPhase.navigating,
          fix: fix,
          badge: NavigationBadge.recalculated,
        ),
        mode: ThemeMode.dark,
      );

      final backdrop = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(RbStatusChip),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (backdrop.decoration as BoxDecoration).color,
        const Color(0xFF1A1D23),
      );
    });

    testWidgets('the map area is #0F1115 until the marker icons exist, then '
        'the route line is #7EA6F8', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(plan: plan, phase: NavigationPhase.waitingGps),
        mode: ThemeMode.dark,
        settle: false,
      );

      expect(find.byKey(mapKey), findsNothing);
      final placeholder = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is FutureBuilder),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(placeholder.color, const Color(0xFF0F1115));

      await tester.pumpAndSettle();
      expect(find.byKey(mapKey), findsOneWidget);
      expect(mapsBuilt.last.polylines.single.color, const Color(0xFF7EA6F8));
    });

    testWidgets('"Aguardando sinal de GPS" is #A4ACB9', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(plan: plan, phase: NavigationPhase.waitingGps),
        mode: ThemeMode.dark,
      );

      expect(
        tester.widget<Text>(find.text('Aguardando sinal de GPS')).style!.color,
        const Color(0xFFA4ACB9),
      );
    });

    testWidgets('the completed sheet is #1A1D23 with "Rota concluída" in '
        '#12B76A', (tester) async {
      await pumpScreen(
        tester,
        NavigationState(
          plan: plan.markVisited('pa').markVisited('pb'),
          phase: NavigationPhase.completed,
          fix: fix,
          following: false,
        ),
        mode: ThemeMode.dark,
      );

      final sheet = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Rota concluída'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (sheet.decoration! as BoxDecoration).color,
        const Color(0xFF1A1D23),
      );
      expect(
        tester.widget<Text>(find.text('Rota concluída')).style!.color,
        const Color(0xFF12B76A),
      );
    });
  });

  group('NavigationScreen accessibility', () {
    final progress = RouteProgress(
      next: const RouteStop(stop: a, order: 1, visited: false),
      toNextMeters: 1234,
      toNextSeconds: 250,
      remainingMeters: 8400,
      remainingSeconds: 1320,
      at: DateTime.utc(2026, 9, 22, 14, 28),
    );
    // Not following, so "Recentralizar" shows too.
    NavigationState navigating({
      NavigationBadge? badge,
      bool online = true,
      String? error,
    }) => NavigationState(
      plan: plan,
      phase: NavigationPhase.navigating,
      fix: fix,
      progress: progress,
      following: false,
      badge: badge,
      online: online,
      error: error,
    );

    // Each state with a text that proves it is on screen and the panel's
    // last action.
    final states = <String, (NavigationState, String, String)>{
      'waiting for GPS': (
        NavigationState(plan: plan, phase: NavigationPhase.waitingGps),
        NavigationScreen.waitingGpsCaption,
        NavigationScreen.startLabel,
      ),
      'navigating with the next stop card': (
        navigating(),
        '1,2 km · 4 min · chegada às 14:32',
        NavigationScreen.stopLabel,
      ),
      'with "Rota recalculada"': (
        navigating(badge: NavigationBadge.recalculated),
        'Rota recalculada',
        NavigationScreen.stopLabel,
      ),
      'with "Falha ao recalcular"': (
        navigating(badge: NavigationBadge.recalcFailed),
        'Falha ao recalcular',
        NavigationScreen.stopLabel,
      ),
      'with "Recálculo pendente (sem conexão)"': (
        navigating(badge: NavigationBadge.recalcPending, online: false),
        'Recálculo pendente (sem conexão)',
        NavigationScreen.stopLabel,
      ),
      'offline': (
        navigating(online: false),
        NavigationScreen.offlineBanner,
        NavigationScreen.stopLabel,
      ),
      'with the GPS error': (
        navigating(error: 'Perdemos o sinal de GPS'),
        'Perdemos o sinal de GPS',
        NavigationScreen.stopLabel,
      ),
      'completed': (
        NavigationState(
          plan: plan.markVisited('pa').markVisited('pb'),
          phase: NavigationPhase.completed,
          fix: fix,
          following: false,
        ),
        NavigationScreen.completedTitle,
        NavigationScreen.newRouteLabel,
      ),
    };

    /// Whether nothing covers the center of [finder]: a tap there reaches it.
    bool uncovered(WidgetTester tester, Finder finder) {
      final target = tester.renderObject(finder);
      return tester
          .hitTestOnBinding(tester.getCenter(finder))
          .path
          .any((entry) => entry.target == target);
    }

    /// Opens "Abrir em outro app" from the next stop card.
    Future<void> openSheet(WidgetTester tester, ThemeMode mode) async {
      await pumpScreen(tester, navigating(), mode: mode);
      await tester.tap(find.byTooltip(NextStopCard.openInAppTooltip));
      await tester.pumpAndSettle();
      expect(find.text(OpenInAppSheet.caption), findsOneWidget);
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final MapEntry(key: name, value: (state, text, _))
          in states.entries) {
        testWidgets('$name meets the contrast, tap target and label '
            'guidelines in ${mode.name} mode', (tester) async {
          await pumpScreen(tester, state, mode: mode);
          expect(find.text(text), findsOneWidget);

          await expectAccessibleGuidelines(tester);
        });
      }

      testWidgets('"Abrir em outro app" meets the contrast, tap target and '
          'label guidelines in ${mode.name} mode', (tester) async {
        await openSheet(tester, mode);

        await expectAccessibleGuidelines(tester);
      });
    }

    for (final MapEntry(key: name, value: (state, text, action))
        in states.entries) {
      testWidgets('$name lays out at 200% text on a 360×800 phone', (
        tester,
      ) async {
        await setLargeTextPhone(tester);
        await pumpScreen(tester, state, mode: ThemeMode.light);

        expect(find.text(text), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
        // The sheet grows upward, toward the top overlay: nothing may cover
        // the state's text, and the panel opens at its actions.
        expect(uncovered(tester, find.text(text)), isTrue);
        expect(uncovered(tester, find.text(action)), isTrue);
      });
    }

    testWidgets('"Abrir em outro app" lays out at 200% text on a 360×800 '
        'phone', (tester) async {
      await setLargeTextPhone(tester);
      await openSheet(tester, ThemeMode.light);

      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
    });
  });
}

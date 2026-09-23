import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70));
  const c = Stop('pc', 'Rua C, 3', GeoPoint(-23.70, -46.80));

  /// Typed order was a, b, c; optimized order is b, a, c (ROUTE-07).
  RoutePlan plan({bool firstVisited = false}) => RoutePlan(
    origin: origin,
    stops: [
      RouteStop(stop: b, order: 1, visited: firstVisited),
      const RouteStop(stop: a, order: 2, visited: false),
      const RouteStop(stop: c, order: 3, visited: false),
    ],
    polyline: const [origin],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );

  final startFinder = find.widgetWithText(RbPrimaryButton, 'Iniciar');
  final markVisitedFinder = find.widgetWithText(
    RbPrimaryButton,
    'Marcar como visitado',
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required RoutePlan plan,
    bool startEnabled = true,
    VoidCallback? onStart,
    VoidCallback? onMarkVisited,
    String startLabel = 'Iniciar',
    Color startColor = RbColors.brand,
    Widget? footer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RouteSheet(
              plan: plan,
              startEnabled: startEnabled,
              onStart: onStart ?? () {},
              onMarkVisited: onMarkVisited,
              startLabel: startLabel,
              startColor: startColor,
              footer: footer,
            ),
          ),
        ),
      ),
    );
  }

  Finder row(String placeId) => find.byKey(RouteSheet.stopKey(placeId));

  Text textIn(WidgetTester tester, Finder scope, String text) => tester
      .widget<Text>(find.descendant(of: scope, matching: find.text(text)));

  Container badgeIn(WidgetTester tester, Finder scope, Finder content) =>
      tester.widget<Container>(
        find
            .ancestor(
              of: find.descendant(of: scope, matching: content),
              matching: find.byType(Container),
            )
            .first,
      );

  Material materialOf(WidgetTester tester, Finder button) =>
      tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );

  group('RouteSheet (ROUTE-04)', () {
    testWidgets('surface-200 container with top radius-lg and the heading '
        '"Ordem otimizada" in heading style', (tester) async {
      await pumpSheet(tester, plan: plan());

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(RouteSheet.heading),
              matching: find.byType(Container),
            )
            .last,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.surface200);
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)),
      );
      expect(container.padding, const EdgeInsets.all(16));

      final heading = tester.widget<Text>(find.text('Ordem otimizada'));
      expect(heading.style!.fontSize, 17);
      expect(heading.style!.fontWeight, FontWeight.w600);
      expect(heading.style!.color, RbColors.ink);
    });

    testWidgets('lists the stops in optimized order, numbered 1..N with a '
        'brand badge and the address in body (ROUTE-02, ROUTE-07)', (
      tester,
    ) async {
      await pumpSheet(tester, plan: plan());

      expect(textIn(tester, row('pb'), '1').data, '1');
      expect(textIn(tester, row('pa'), '2').data, '2');
      expect(textIn(tester, row('pc'), '3').data, '3');
      expect(
        find.descendant(of: row('pb'), matching: find.text('Rua B, 2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('pa'), matching: find.text('Rua A, 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('pc'), matching: find.text('Rua C, 3')),
        findsOneWidget,
      );
      final y1 = tester.getTopLeft(row('pb')).dy;
      final y2 = tester.getTopLeft(row('pa')).dy;
      final y3 = tester.getTopLeft(row('pc')).dy;
      expect(y1 < y2 && y2 < y3, isTrue);

      final badge = badgeIn(tester, row('pb'), find.text('1'));
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.brand);
      expect(decoration.shape, BoxShape.circle);
      expect(tester.getSize(find.byWidget(badge)), const Size(24, 24));
      final number = textIn(tester, row('pb'), '1');
      expect(number.style!.color, Colors.white);
      expect(number.style!.fontSize, 15);
      expect(number.style!.fontWeight, FontWeight.w600);

      final address = textIn(tester, row('pb'), 'Rua B, 2');
      expect(address.style!.fontSize, 15);
      expect(address.style!.fontWeight, FontWeight.w400);
      expect(address.style!.color, RbColors.ink);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('rows are separated by s3 (16 px)', (tester) async {
      await pumpSheet(tester, plan: plan());

      expect(
        tester.getTopLeft(row('pa')).dy - tester.getBottomLeft(row('pb')).dy,
        RouteSheet.rowGap,
      );
      expect(
        tester.getTopLeft(row('pc')).dy - tester.getBottomLeft(row('pa')).dy,
        16,
      );
    });

    testWidgets('totals caption "12,3 km · 10 min" in caption/ink-muted', (
      tester,
    ) async {
      await pumpSheet(tester, plan: plan());

      final totals = tester.widget<Text>(find.text('12,3 km · 10 min'));
      expect(totals.style!.fontSize, 13);
      expect(totals.style!.color, RbColors.inkMuted);
    });

    testWidgets('visited stop: success badge with a white check (semantics '
        '"Visitado") instead of the number, address in ink-muted, no chip '
        '(NAV-04)', (tester) async {
      await pumpSheet(tester, plan: plan(firstVisited: true));

      final check = find.byIcon(Icons.check);
      expect(check, findsOneWidget);
      expect(find.descendant(of: row('pb'), matching: check), findsOneWidget);
      final icon = tester.widget<Icon>(check);
      expect(icon.color, Colors.white);
      expect(icon.size, 16);
      expect(icon.semanticLabel, 'Visitado');
      expect(find.text('Visitado'), findsNothing);
      expect(
        find.descendant(of: row('pb'), matching: find.text('1')),
        findsNothing,
      );

      final badge = badgeIn(tester, row('pb'), check);
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.success);
      expect(decoration.shape, BoxShape.circle);
      expect(tester.getSize(find.byWidget(badge)), const Size(24, 24));

      expect(
        textIn(tester, row('pb'), 'Rua B, 2').style!.color,
        RbColors.inkMuted,
      );
      expect(textIn(tester, row('pa'), 'Rua A, 1').style!.color, RbColors.ink);
      final unvisited = badgeIn(tester, row('pa'), find.text('2'));
      expect((unvisited.decoration! as BoxDecoration).color, RbColors.brand);
    });

    testWidgets('"Iniciar" enabled in brand calls onStart', (tester) async {
      var started = 0;
      await pumpSheet(tester, plan: plan(), onStart: () => started++);

      final button = tester.widget<RbPrimaryButton>(startFinder);
      expect(button.enabled, isTrue);
      final material = tester.widget<Material>(
        find.descendant(of: startFinder, matching: find.byType(Material)).first,
      );
      expect(material.color, RbColors.brand);
      await tester.tap(startFinder);
      expect(started, 1);
    });

    testWidgets('"Iniciar" disabled ignores taps', (tester) async {
      var started = 0;
      await pumpSheet(
        tester,
        plan: plan(),
        startEnabled: false,
        onStart: () => started++,
      );

      expect(tester.widget<RbPrimaryButton>(startFinder).enabled, isFalse);
      final material = tester.widget<Material>(
        find.descendant(of: startFinder, matching: find.byType(Material)).first,
      );
      expect(material.color, RbColors.border);
      await tester.tap(startFinder);
      expect(started, 0);
    });

    testWidgets('"Marcar como visitado" appears only with onMarkVisited, as '
        'a brand primary button above the start action, and calls it '
        '(NAV-05)', (tester) async {
      await pumpSheet(tester, plan: plan());
      expect(find.text('Marcar como visitado'), findsNothing);
      expect(find.byType(RbPrimaryButton), findsOneWidget);

      var marked = 0;
      var started = 0;
      await pumpSheet(
        tester,
        plan: plan(),
        onStart: () => started++,
        onMarkVisited: () => marked++,
      );

      expect(markVisitedFinder, findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(materialOf(tester, markVisitedFinder).color, RbColors.brand);
      expect(
        tester.widget<Text>(find.text('Marcar como visitado')).style!.color,
        Colors.white,
      );
      expect(
        tester.getBottomLeft(markVisitedFinder).dy,
        lessThan(tester.getTopLeft(startFinder).dy),
      );
      expect(
        tester.getTopLeft(startFinder).dy -
            tester.getBottomLeft(markVisitedFinder).dy,
        RbSpace.s2,
      );

      await tester.tap(markVisitedFinder);
      expect(marked, 1);
      expect(started, 0);
      await tester.tap(startFinder);
      expect(started, 1);
    });

    testWidgets('"Encerrar" is painted with startColor danger and white text '
        '(NAV-07, DS-03)', (tester) async {
      var stopped = 0;
      await pumpSheet(
        tester,
        plan: plan(),
        startLabel: 'Encerrar',
        startColor: RbColors.danger,
        onStart: () => stopped++,
        onMarkVisited: () {},
      );

      final stop = find.widgetWithText(RbPrimaryButton, 'Encerrar');
      expect(stop, findsOneWidget);
      expect(startFinder, findsNothing);
      expect(materialOf(tester, stop).color, RbColors.danger);
      expect(
        tester.widget<Text>(find.text('Encerrar')).style!.color,
        Colors.white,
      );
      expect(materialOf(tester, markVisitedFinder).color, RbColors.brand);
      expect(
        tester.getBottomLeft(markVisitedFinder).dy,
        lessThan(tester.getTopLeft(stop).dy),
      );
      await tester.tap(stop);
      expect(stopped, 1);
    });

    testWidgets('"Marcar como visitado" is hidden once every stop is visited', (
      tester,
    ) async {
      final complete = plan()
          .markVisited('pb')
          .markVisited('pa')
          .markVisited('pc');

      await pumpSheet(tester, plan: complete, onMarkVisited: () {});

      expect(find.text('Marcar como visitado'), findsNothing);
      expect(find.byIcon(Icons.check), findsNWidgets(3));
      expect(find.byType(RbPrimaryButton), findsOneWidget);
    });

    testWidgets('with 12 stops on a 640 px screen the heading, totals and '
        '"Iniciar" stay visible and the list scrolls', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final many = RoutePlan(
        origin: origin,
        stops: [
          for (var i = 1; i <= 12; i++)
            RouteStop(
              stop: Stop(
                'p$i',
                'Avenida Brigadeiro Faria Lima, $i - Itaim Bibi, '
                    'São Paulo - SP, 04538-132, Brasil',
                origin,
              ),
              order: i,
              visited: false,
            ),
        ],
        polyline: const [origin],
        distanceMeters: 12345,
        durationSeconds: 605,
        legs: const [],
        computedAt: DateTime.utc(2026, 9, 22, 10, 30),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RouteSheet(
                    plan: many,
                    startEnabled: true,
                    onStart: () {},
                    onMarkVisited: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final heading = find.text(RouteSheet.heading);
      expect(heading, findsOneWidget);
      expect(tester.getTopLeft(heading).dy, greaterThanOrEqualTo(0));
      expect(find.text('12,3 km · 10 min'), findsOneWidget);
      expect(startFinder, findsOneWidget);
      expect(tester.getBottomLeft(startFinder).dy, lessThanOrEqualTo(640));
      final sheet = tester.getRect(find.byType(RouteSheet));
      expect(sheet.top, greaterThanOrEqualTo(0));
      expect(sheet.height, lessThanOrEqualTo(640));
      expect(row('p1'), findsOneWidget);
      expect(row('p12'), findsNothing);

      await tester.scrollUntilVisible(
        row('p12'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(row('p12'), findsOneWidget);
      expect(heading, findsOneWidget);
      expect(startFinder, findsOneWidget);
    });

    testWidgets('renders the footer below the actions', (tester) async {
      const footerKey = Key('footer');
      await pumpSheet(
        tester,
        plan: plan(),
        footer: const SizedBox(key: footerKey, height: 10),
      );

      expect(find.byKey(footerKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(footerKey)).dy,
        greaterThan(tester.getBottomLeft(startFinder).dy - 1),
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/core/widgets/rb_feedback.dart';
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

  Future<void> pumpSheet(
    WidgetTester tester, {
    required RoutePlan plan,
    bool startEnabled = true,
    VoidCallback? onStart,
    VoidCallback? onMarkVisited,
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

      final badge = tester.widget<Container>(
        find
            .ancestor(
              of: find.descendant(of: row('pb'), matching: find.text('1')),
              matching: find.byType(Container),
            )
            .first,
      );
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
      expect(find.byType(RbStatusChip), findsNothing);
    });

    testWidgets('totals caption "12,3 km · 10 min" in caption/ink-muted', (
      tester,
    ) async {
      await pumpSheet(tester, plan: plan());

      final totals = tester.widget<Text>(find.text('12,3 km · 10 min'));
      expect(totals.style!.fontSize, 13);
      expect(totals.style!.color, RbColors.inkMuted);
    });

    testWidgets('visited stop shows the success "Visitado" chip and its '
        'address in ink-muted (NAV-04)', (tester) async {
      await pumpSheet(tester, plan: plan(firstVisited: true));

      final chip = tester.widget<RbStatusChip>(
        find.descendant(of: row('pb'), matching: find.byType(RbStatusChip)),
      );
      expect(chip.label, 'Visitado');
      expect(chip.tone, RbTone.success);
      expect(find.byType(RbStatusChip), findsOneWidget);
      expect(
        textIn(tester, row('pb'), 'Rua B, 2').style!.color,
        RbColors.inkMuted,
      );
      expect(textIn(tester, row('pa'), 'Rua A, 1').style!.color, RbColors.ink);
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

    testWidgets('"Marcar como visitado" appears only with onMarkVisited and '
        'calls it (NAV-05)', (tester) async {
      await pumpSheet(tester, plan: plan());
      expect(find.text('Marcar como visitado'), findsNothing);

      var marked = 0;
      await pumpSheet(tester, plan: plan(), onMarkVisited: () => marked++);
      await tester.tap(find.text('Marcar como visitado'));
      expect(marked, 1);
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
      expect(find.byType(RbStatusChip), findsNWidgets(3));
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

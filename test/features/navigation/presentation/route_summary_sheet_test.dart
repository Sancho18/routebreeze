import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/route_summary.dart';
import 'package:routebreeze/features/navigation/presentation/route_summary_sheet.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

void main() {
  // Local clock times: the summary shows the driver's clock.
  final start = DateTime(2026, 9, 28, 8, 40);
  final end = DateTime(2026, 9, 28, 9, 45);

  RouteStop failedStop(
    String id,
    String address,
    int order,
    FailureReason reason,
  ) => RouteStop(
    stop: Stop(id, address, const GeoPoint(-23.56, -46.65)),
    order: order,
    result: StopResult.failed(reason, at: end),
  );

  final refusedB = failedStop('pb', 'Rua B, 2', 2, FailureReason.refused);

  /// A 4-stop route with one stop not delivered.
  final summary = RouteSummary(
    delivered: 3,
    failed: [refusedB],
    traveledMeters: 12430,
    start: start,
    end: end,
  );

  RouteSummary summaryWith({
    int delivered = 3,
    List<RouteStop>? failed,
    int meters = 12430,
    DateTime? from,
    bool noStart = false,
    DateTime? to,
  }) => RouteSummary(
    delivered: delivered,
    failed: failed ?? [refusedB],
    traveledMeters: meters,
    start: noStart ? null : from ?? start,
    end: to ?? end,
  );

  var newRoutes = 0;

  /// The sheet as the navigation screen shows it, at the bottom under the
  /// app bar in a panel that scrolls from its actions up: in a bare
  /// `MaterialApp`, or in the app themes when [mode] is given.
  Future<void> pumpSheet(
    WidgetTester tester,
    RouteSummary summary, {
    ThemeMode? mode,
  }) {
    newRoutes = 0;
    final home = Scaffold(
      appBar: AppBar(title: const Text('Navegação')),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          reverse: true,
          child: RouteSummarySheet(
            summary: summary,
            onNewRoute: () => newRoutes++,
          ),
        ),
      ),
    );
    return tester.pumpWidget(
      mode == null ? MaterialApp(home: home) : themedApp(home, mode: mode),
    );
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  group('RouteSummarySheet lines', () {
    test('counts: plural and singular, the not delivered part only when '
        'there is one', () {
      expect(RouteSummarySheet.counts(summary), '3 entregues · 1 não entregue');
      expect(
        RouteSummarySheet.counts(summaryWith(delivered: 1, failed: const [])),
        '1 entregue',
      );
      expect(
        RouteSummarySheet.counts(
          summaryWith(
            delivered: 0,
            failed: [
              failedStop('pa', 'Rua A, 1', 1, FailureReason.other),
              refusedB,
            ],
          ),
        ),
        '0 entregues · 2 não entregues',
      );
    });

    test('distance and time: the meters traveled and the time from the '
        'start to the last result', () {
      expect(
        RouteSummarySheet.distanceAndTime(summary),
        '12,4 km percorridos · 1 h 05 min',
      );
      expect(
        RouteSummarySheet.distanceAndTime(
          summaryWith(meters: 850, to: start.add(const Duration(minutes: 18))),
        ),
        '850 m percorridos · 18 min',
      );
    });

    test('start and end: "Início às 08:40 · fim às 09:45"', () {
      expect(
        RouteSummarySheet.clocks(summary),
        'Início às 08:40 · fim às 09:45',
      );
    });

    test('a start read back from storage in UTC shows on the local clock', () {
      expect(
        RouteSummarySheet.clocks(summaryWith(from: start.toUtc())),
        'Início às 08:40 · fim às 09:45',
      );
    });

    test('without a start: the distance alone and no start and end line', () {
      final noStart = summaryWith(noStart: true);

      expect(RouteSummarySheet.distanceAndTime(noStart), '12,4 km percorridos');
      expect(RouteSummarySheet.clocks(noStart), isNull);
    });
  });

  group('RouteSummarySheet', () {
    testWidgets('shows, in order, "Rota concluída", the counts, the distance '
        'and time, the start and end, the stop not delivered with its '
        'reason, and "Nova rota"', (tester) async {
      await pumpSheet(tester, summary);

      final blocks = [
        'Rota concluída',
        '3 entregues · 1 não entregue',
        '12,4 km percorridos · 1 h 05 min',
        'Início às 08:40 · fim às 09:45',
        'Parada 2 · Rua B, 2',
        'Recusado',
        'Nova rota',
      ];
      final tops = [for (final block in blocks) top(tester, block)];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: blocks[i]);
      }
      expect(find.widgetWithText(RbPrimaryButton, 'Nova rota'), findsOneWidget);

      await tester.tap(find.widgetWithText(RbPrimaryButton, 'Nova rota'));
      expect(newRoutes, 1);
    });

    testWidgets('"Rota concluída" is a heading in successStrong #0D7F4A', (
      tester,
    ) async {
      await pumpSheet(tester, summary);

      final title = tester.widget<Text>(find.text('Rota concluída'));
      expect(title.style!.fontSize, 17);
      expect(title.style!.fontWeight, FontWeight.w600);
      expect(title.style!.color, const Color(0xFF0D7F4A));
    });

    testWidgets('counts in bodyStrong ink; distance and time, the clocks and '
        'the reason in caption ink-muted; the stop line in body ink', (
      tester,
    ) async {
      await pumpSheet(tester, summary);

      /// Size, weight and color of the text [text].
      (double?, FontWeight?, Color?) look(String text) {
        final style = tester.widget<Text>(find.text(text)).style!;
        return (style.fontSize, style.fontWeight, style.color);
      }

      const ink = Color(0xFF12141A);
      const inkMuted = Color(0xFF5B6472);
      expect(look('3 entregues · 1 não entregue'), (15, FontWeight.w600, ink));
      expect(look('12,4 km percorridos · 1 h 05 min'), (
        13,
        FontWeight.w400,
        inkMuted,
      ));
      expect(look('Início às 08:40 · fim às 09:45'), (
        13,
        FontWeight.w400,
        inkMuted,
      ));
      expect(look('Parada 2 · Rua B, 2'), (15, FontWeight.w400, ink));
      expect(look('Recusado'), (13, FontWeight.w400, inkMuted));
    });

    testWidgets('lists only the stops not delivered, in stop order, each '
        'with its reason below it', (tester) async {
      await pumpSheet(
        tester,
        summaryWith(
          delivered: 2,
          failed: [
            failedStop('pa', 'Rua A, 1', 1, FailureReason.recipientAbsent),
            failedStop('pc', 'Rua C, 3', 3, FailureReason.addressNotFound),
          ],
        ),
      );

      final order = [
        'Parada 1 · Rua A, 1',
        'Destinatário ausente',
        'Parada 3 · Rua C, 3',
        'Endereço não encontrado',
      ];
      final tops = [for (final text in order) top(tester, text)];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: order[i]);
      }
      expect(
        tester.getTopLeft(find.text('Destinatário ausente')).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Parada 1 · Rua A, 1')).dy,
        ),
      );
      expect(find.textContaining('Parada 2'), findsNothing);
      expect(find.textContaining('Parada 4'), findsNothing);
    });

    testWidgets('with every stop delivered there is no "não entregue" part '
        'and no list', (tester) async {
      await pumpSheet(tester, summaryWith(delivered: 4, failed: const []));

      expect(find.text('4 entregues'), findsOneWidget);
      expect(find.textContaining('não entregue'), findsNothing);
      expect(find.textContaining('Parada'), findsNothing);
    });

    testWidgets('without a start it shows the distance alone and no start '
        'and end line', (tester) async {
      await pumpSheet(tester, summaryWith(noStart: true));

      expect(find.text('12,4 km percorridos'), findsOneWidget);
      expect(find.textContaining('Início'), findsNothing);
      expect(find.textContaining('fim às'), findsNothing);
      expect(
        top(tester, 'Parada 2 · Rua B, 2'),
        greaterThan(top(tester, '12,4 km percorridos')),
      );
    });
  });

  group('RouteSummarySheet in dark mode', () {
    testWidgets('#1A1D23 sheet with "Rota concluída" in #12B76A', (
      tester,
    ) async {
      await pumpSheet(tester, summary, mode: ThemeMode.dark);

      final sheet = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RouteSummarySheet),
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

  group('RouteSummarySheet accessibility', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('meets the contrast, tap target and label guidelines in '
          '${mode.name} mode', (tester) async {
        await pumpSheet(tester, summary, mode: mode);
        expect(find.text('Rota concluída'), findsOneWidget);

        await expectAccessibleGuidelines(tester);
      });
    }

    testWidgets('at 200% text on a 360×800 phone, with a stop not '
        'delivered, every line is whole at the system scale and the whole '
        'summary is in view under the app bar', (tester) async {
      await setLargeTextPhone(tester);
      await pumpSheet(tester, summary, mode: ThemeMode.light);

      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      expect(
        tester
            .renderObject<RenderParagraph>(
              find.text('3 entregues · 1 não entregue'),
            )
            .textScaler
            .scale(15),
        30,
      );
      final body = tester.getRect(find.byType(SingleChildScrollView));
      final sheet = tester.getRect(find.byType(RouteSummarySheet));
      expect(sheet.top, greaterThanOrEqualTo(body.top));
      expect(sheet.bottom, lessThanOrEqualTo(body.bottom));
      expect(
        tester.getRect(find.text('Rota concluída')).top,
        greaterThanOrEqualTo(body.top),
      );
    });
  });
}

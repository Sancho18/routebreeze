import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/presentation/next_stop_card.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/stop_badge.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

void main() {
  const stop = RouteStop(
    stop: Stop(
      'pa',
      'Rua Augusta, 500 - Consolação, São Paulo',
      GeoPoint(-23.553, -46.653),
    ),
    order: 2,
  );

  /// Matches the spec's own example sentence verbatim.
  const shortStop = RouteStop(
    stop: Stop('pa', 'Rua Augusta, 500', GeoPoint(-23.553, -46.653)),
    order: 2,
  );
  final progress = RouteProgress(
    next: stop,
    toNextMeters: 1234,
    toNextSeconds: 250,
    remainingMeters: 8400,
    remainingSeconds: 1320,
    at: DateTime.utc(2026, 9, 28, 14, 28),
  );

  /// The card in a bare `MaterialApp`, or in the app themes when [mode] is
  /// given.
  Future<void> pumpCard(
    WidgetTester tester, {
    RouteProgress? progress,
    bool arrived = false,
    VoidCallback? onOpenInApp,
    ThemeMode? mode,
  }) {
    final home = Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(RbSpace.s3),
        child: NextStopCard(
          stop: stop,
          progress: progress,
          arrived: arrived,
          onOpenInApp: onOpenInApp,
        ),
      ),
    );
    return tester.pumpWidget(
      mode == null ? MaterialApp(home: home) : themedApp(home, mode: mode),
    );
  }

  Text text(WidgetTester tester, String value) =>
      tester.widget<Text>(find.text(value));

  group('NextStopCard', () {
    testWidgets('address card per the DS: surface-200, 1 px border, radius-md '
        'and space-3 padding, as wide as its slot', (tester) async {
      await pumpCard(tester, progress: progress);

      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(NextStopCard.label),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.surface200);
      expect(decoration.borderRadius, BorderRadius.circular(RbRadius.md));
      expect(decoration.border, Border.all(color: RbColors.border));
      expect(card.padding, const EdgeInsets.all(RbSpace.s3));
      expect(
        tester.getSize(find.byType(NextStopCard)).width,
        800 - RbSpace.s3 * 2,
      );
    });

    testWidgets('"Próxima parada" in caption/ink-muted over the stop number '
        'on its brand badge and the address in body-strong/ink', (
      tester,
    ) async {
      await pumpCard(tester, progress: progress);

      final label = text(tester, 'Próxima parada');
      expect(label.style!.fontSize, 13);
      expect(label.style!.color, RbColors.inkMuted);

      final badge = tester.widget<StopBadge>(find.byType(StopBadge));
      expect(badge.order, 2);
      expect(badge.result, isNull);

      final address = text(tester, 'Rua Augusta, 500 - Consolação, São Paulo');
      expect(address.style!.fontSize, 15);
      expect(address.style!.fontWeight, FontWeight.w600);
      expect(address.style!.color, RbColors.ink);
      expect(address.maxLines, 2);
      expect(address.overflow, TextOverflow.ellipsis);

      expect(
        tester.getTopLeft(find.byType(StopBadge)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Próxima parada')).dy + RbSpace.s2,
        ),
      );
    });

    testWidgets('with progress: distance, time and arrival clock in '
        'caption/ink-muted under the address, aligned with it', (tester) async {
      await pumpCard(tester, progress: progress);

      const summary = '1,2 km · 4 min · chegada às 14:32';
      final details = text(tester, summary);
      expect(details.style!.fontSize, 13);
      expect(details.style!.color, RbColors.inkMuted);
      final address = find.text('Rua Augusta, 500 - Consolação, São Paulo');
      expect(
        tester.getTopLeft(find.text(summary)).dx,
        tester.getTopLeft(address).dx,
      );
      expect(
        tester.getTopLeft(find.text(summary)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(address).dy + RbSpace.s2),
      );
    });

    testWidgets('without progress: the stop only, no details line', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.text('Rua Augusta, 500 - Consolação, São Paulo'), findsOne);
      expect(find.textContaining('chegada às'), findsNothing);
    });

    test('summary: meters under 1 km, "< 1 min" and a zero-padded clock', () {
      final close = RouteProgress(
        next: stop,
        toNextMeters: 45,
        toNextSeconds: 12,
        remainingMeters: 45,
        remainingSeconds: 12,
        at: DateTime.utc(2026, 9, 28, 9, 4, 50),
      );

      expect(NextStopCard.summary(close), '45 m · < 1 min · chegada às 09:05');
    });
    testWidgets('onOpenInApp adds a brand "directions" button, 48 px, at the '
        'end of the address row, "Abrir em outro app"', (tester) async {
      var taps = 0;
      await pumpCard(tester, progress: progress, onOpenInApp: () => taps++);

      final button = find.byTooltip('Abrir em outro app');
      expect(button, findsOneWidget);
      expect(tester.getSize(button), const Size.square(48));
      final icon = tester.widget<Icon>(
        find.descendant(of: button, matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.directions);
      expect(icon.color, RbColors.brand);
      expect(
        tester.getTopLeft(button).dx,
        greaterThan(
          tester
              .getTopRight(
                find.text('Rua Augusta, 500 - Consolação, São Paulo'),
              )
              .dx,
        ),
      );

      await tester.tap(button);
      expect(taps, 1);
    });

    testWidgets('without onOpenInApp there is no button', (tester) async {
      await pumpCard(tester, progress: progress);

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('arrived: "Você chegou" in caption/successStrong #0D7F4A '
        'replaces the distance line, under the address and aligned with it', (
      tester,
    ) async {
      await pumpCard(tester, progress: progress, arrived: true);

      expect(find.text('1,2 km · 4 min · chegada às 14:32'), findsNothing);
      final arrivedLine = text(tester, 'Você chegou');
      expect(arrivedLine.style!.fontSize, 13);
      expect(arrivedLine.style!.fontWeight, FontWeight.w400);
      expect(arrivedLine.style!.color, const Color(0xFF0D7F4A));
      final address = find.text('Rua Augusta, 500 - Consolação, São Paulo');
      expect(
        tester.getTopLeft(find.text('Você chegou')).dx,
        tester.getTopLeft(address).dx,
      );
      expect(
        tester.getTopLeft(find.text('Você chegou')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(address).dy + RbSpace.s2),
      );
    });

    testWidgets('arrived before a first measure: "Você chegou" shows all the '
        'same', (tester) async {
      await pumpCard(tester, arrived: true);

      expect(find.text('Você chegou'), findsOneWidget);
    });
  });

  group('NextStopCard semantics', () {
    test('semanticsLabel: address, distance, duration and arrival once '
        'measured', () {
      expect(
        NextStopCard.semanticsLabel(shortStop, progress),
        'Próxima parada 2: Rua Augusta, 500. 1,2 km, 4 min, '
        'chegada às 14:32',
      );
    });

    test('semanticsLabel: ends after the address without progress', () {
      expect(
        NextStopCard.semanticsLabel(shortStop, null),
        'Próxima parada 2: Rua Augusta, 500.',
      );
    });

    test('semanticsLabel: "Você chegou" after the address once arrived, in '
        'place of the distance', () {
      expect(
        NextStopCard.semanticsLabel(shortStop, progress, arrived: true),
        'Próxima parada 2: Rua Augusta, 500. Você chegou',
      );
      expect(
        NextStopCard.semanticsLabel(shortStop, null, arrived: true),
        'Próxima parada 2: Rua Augusta, 500. Você chegou',
      );
    });

    testWidgets('arrived, it reads as one merged sentence ending in "Você '
        'chegou"', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NextStopCard(
              stop: shortStop,
              progress: progress,
              arrived: true,
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(NextStopCard)).label,
        'Próxima parada 2: Rua Augusta, 500. Você chegou',
      );
      semantics.dispose();
    });

    testWidgets('reads as one merged sentence once measured', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NextStopCard(stop: shortStop, progress: progress),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(NextStopCard)).label,
        'Próxima parada 2: Rua Augusta, 500. 1,2 km, 4 min, '
        'chegada às 14:32',
      );
      semantics.dispose();
    });

    testWidgets('reads only the address without progress', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NextStopCard(stop: shortStop)),
        ),
      );

      expect(
        tester.getSemantics(find.byType(NextStopCard)).label,
        'Próxima parada 2: Rua Augusta, 500.',
      );
      semantics.dispose();
    });

    testWidgets('the open-in-app button stays reachable with its tooltip, '
        'outside the merged label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpCard(tester, progress: progress, onOpenInApp: () {});

      final buttonNode = tester.getSemantics(
        find.byTooltip('Abrir em outro app'),
      );
      expect(buttonNode.tooltip, 'Abrir em outro app');
      expect(
        tester.getSemantics(find.byType(NextStopCard)).label,
        isNot(contains('Abrir em outro app')),
      );
      semantics.dispose();
    });
  });

  group('NextStopCard in dark mode', () {
    testWidgets('#1A1D23 card with a #2F343D border, label and summary in '
        '#A4ACB9, address in #F2F4F7 and the action icon in #7EA6F8', (
      tester,
    ) async {
      await pumpCard(
        tester,
        progress: progress,
        onOpenInApp: () {},
        mode: ThemeMode.dark,
      );

      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(NextStopCard.label),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF1A1D23));
      expect(decoration.border, Border.all(color: const Color(0xFF2F343D)));
      expect(
        text(tester, 'Próxima parada').style!.color,
        const Color(0xFFA4ACB9),
      );
      expect(
        text(tester, '1,2 km · 4 min · chegada às 14:32').style!.color,
        const Color(0xFFA4ACB9),
      );
      expect(
        text(tester, 'Rua Augusta, 500 - Consolação, São Paulo').style!.color,
        const Color(0xFFF2F4F7),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Abrir em outro app'),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, const Color(0xFF7EA6F8));
    });

    testWidgets('"Você chegou" is #12B76A', (tester) async {
      await pumpCard(
        tester,
        progress: progress,
        arrived: true,
        mode: ThemeMode.dark,
      );

      expect(text(tester, 'Você chegou').style!.color, const Color(0xFF12B76A));
    });
  });

  group('NextStopCard accessibility', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('arrived, it meets the contrast, tap target and label '
          'guidelines in ${mode.name} mode', (tester) async {
        await pumpCard(
          tester,
          progress: progress,
          arrived: true,
          onOpenInApp: () {},
          mode: mode,
        );
        expect(find.text('Você chegou'), findsOneWidget);

        await expectAccessibleGuidelines(tester);
      });
    }

    testWidgets('arrived, it lays out at 200% text on a 360×800 phone with '
        '"Você chegou" whole at the system scale', (tester) async {
      await setLargeTextPhone(tester);
      await pumpCard(
        tester,
        progress: progress,
        arrived: true,
        onOpenInApp: () {},
        mode: ThemeMode.light,
      );

      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Você chegou'))
            .textScaler
            .scale(13),
        26,
      );
    });
  });
}

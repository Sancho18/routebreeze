import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/presentation/return_card.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

void main() {
  /// What is left of the way back: 3,2 km and 9 min from 15:31.
  final progress = RouteProgress(
    next: null,
    toNextMeters: 3200,
    toNextSeconds: 540,
    remainingMeters: 3200,
    remainingSeconds: 540,
    at: DateTime.utc(2026, 9, 29, 15, 31),
  );
  const summary = '3,2 km · 9 min · chegada às 15:40';

  /// The card in a bare `MaterialApp`, or in the app themes when [mode] is
  /// given.
  Future<void> pumpCard(
    WidgetTester tester, {
    RouteProgress? progress,
    VoidCallback? onOpenInApp,
    ThemeMode? mode,
  }) {
    final home = Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(RbSpace.s3),
        child: ReturnCard(progress: progress, onOpenInApp: onOpenInApp),
      ),
    );
    return tester.pumpWidget(
      mode == null ? MaterialApp(home: home) : themedApp(home, mode: mode),
    );
  }

  Text text(WidgetTester tester, String value) =>
      tester.widget<Text>(find.text(value));

  /// The circle behind the home icon.
  Finder homeBadge() => find
      .ancestor(of: find.byIcon(Icons.home), matching: find.byType(Container))
      .first;

  Icon iconOf(WidgetTester tester, Finder button) => tester.widget<Icon>(
    find.descendant(of: button, matching: find.byType(Icon)),
  );

  final openInApp = find.byTooltip('Abrir em outro app');

  group('ReturnCard', () {
    testWidgets('card per the DS like the next stop card: surface-200, 1 px '
        'border, radius-md and space-3 padding, as wide as its slot', (
      tester,
    ) async {
      await pumpCard(tester, progress: progress);

      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(ReturnCard.label),
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
        tester.getSize(find.byType(ReturnCard)).width,
        800 - RbSpace.s3 * 2,
      );
    });

    testWidgets('"Retorno" in caption/ink-muted over a 24 px brand home badge '
        'with a 16 px white home, and "Ponto de partida" in body-strong/ink', (
      tester,
    ) async {
      await pumpCard(tester, progress: progress);

      final caption = text(tester, 'Retorno');
      expect(caption.style!.fontSize, 13);
      expect(caption.style!.fontWeight, FontWeight.w400);
      expect(caption.style!.color, RbColors.inkMuted);

      final badge = tester.widget<Container>(homeBadge());
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.brand);
      expect(decoration.shape, BoxShape.circle);
      expect(tester.getSize(homeBadge()), const Size(24, 24));
      final home = tester.widget<Icon>(find.byIcon(Icons.home));
      expect(home.size, 16);
      expect(home.color, Colors.white);

      final title = text(tester, 'Ponto de partida');
      expect(title.style!.fontSize, 15);
      expect(title.style!.fontWeight, FontWeight.w600);
      expect(title.style!.color, RbColors.ink);

      expect(
        tester.getTopLeft(homeBadge()).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Retorno')).dy + RbSpace.s2,
        ),
      );
      expect(
        tester.getTopLeft(find.text('Ponto de partida')).dx,
        tester.getTopRight(homeBadge()).dx + RbSpace.s2,
      );
    });

    testWidgets('with progress: the way back\'s distance, time and arrival '
        'clock in caption/ink-muted under "Ponto de partida", aligned with '
        'it', (tester) async {
      await pumpCard(tester, progress: progress);

      final details = text(tester, summary);
      expect(details.style!.fontSize, 13);
      expect(details.style!.fontWeight, FontWeight.w400);
      expect(details.style!.color, RbColors.inkMuted);
      final title = find.text('Ponto de partida');
      expect(
        tester.getTopLeft(find.text(summary)).dx,
        tester.getTopLeft(title).dx,
      );
      expect(
        tester.getTopLeft(find.text(summary)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(title).dy + RbSpace.s2),
      );
    });

    testWidgets('without progress: "Retorno" and "Ponto de partida" only, no '
        'details line', (tester) async {
      await pumpCard(tester);

      expect(find.text('Retorno'), findsOneWidget);
      expect(find.text('Ponto de partida'), findsOneWidget);
      expect(find.textContaining('chegada às'), findsNothing);
    });

    testWidgets('onOpenInApp adds a brand "directions" button, 48 px, at the '
        'end of the row, "Abrir em outro app"', (tester) async {
      var taps = 0;
      await pumpCard(tester, progress: progress, onOpenInApp: () => taps++);

      expect(openInApp, findsOneWidget);
      expect(tester.getSize(openInApp), const Size.square(48));
      final icon = iconOf(tester, openInApp);
      expect(icon.icon, Icons.directions);
      expect(icon.color, RbColors.brand);
      expect(
        tester.getTopLeft(openInApp).dx,
        greaterThan(tester.getTopRight(find.text('Ponto de partida')).dx),
      );
      expect(
        tester.getTopRight(openInApp).dx,
        tester
            .getTopRight(
              find.ancestor(of: openInApp, matching: find.byType(Row)).first,
            )
            .dx,
      );

      await tester.tap(openInApp);
      expect(taps, 1);
    });
  });

  group('ReturnCard semantics', () {
    test('semanticsLabel: "Retorno ao ponto de partida." with the distance, '
        'duration and arrival once measured', () {
      expect(
        ReturnCard.semanticsLabel(progress),
        'Retorno ao ponto de partida. 3,2 km, 9 min, chegada às 15:40',
      );
    });

    test('semanticsLabel: ends after "Retorno ao ponto de partida." without '
        'progress', () {
      expect(ReturnCard.semanticsLabel(null), 'Retorno ao ponto de partida.');
    });

    testWidgets('reads as one merged sentence once measured', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpCard(tester, progress: progress, onOpenInApp: () {});

      expect(
        tester.getSemantics(find.byType(ReturnCard)).label,
        'Retorno ao ponto de partida. 3,2 km, 9 min, chegada às 15:40',
      );
      semantics.dispose();
    });

    testWidgets('the open-in-app button stays reachable with its tooltip, '
        'outside the merged label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpCard(tester, progress: progress, onOpenInApp: () {});

      expect(tester.getSemantics(openInApp).tooltip, 'Abrir em outro app');
      expect(
        tester.getSemantics(find.byType(ReturnCard)).label,
        isNot(contains('Abrir em outro app')),
      );
      semantics.dispose();
    });
  });

  group('ReturnCard in dark mode', () {
    testWidgets('#1A1D23 card with a #2F343D border, "Retorno" and the '
        'summary in #A4ACB9, "Ponto de partida" in #F2F4F7, a #7EA6F8 badge '
        'with a #0F1115 home and the action icon in #7EA6F8', (tester) async {
      await pumpCard(
        tester,
        progress: progress,
        onOpenInApp: () {},
        mode: ThemeMode.dark,
      );

      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(ReturnCard.label),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF1A1D23));
      expect(decoration.border, Border.all(color: const Color(0xFF2F343D)));
      expect(text(tester, 'Retorno').style!.color, const Color(0xFFA4ACB9));
      expect(text(tester, summary).style!.color, const Color(0xFFA4ACB9));
      expect(
        text(tester, 'Ponto de partida').style!.color,
        const Color(0xFFF2F4F7),
      );
      expect(
        (tester.widget<Container>(homeBadge()).decoration! as BoxDecoration)
            .color,
        const Color(0xFF7EA6F8),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.home)).color,
        const Color(0xFF0F1115),
      );
      expect(iconOf(tester, openInApp).color, const Color(0xFF7EA6F8));
    });
  });

  group('ReturnCard accessibility', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('with the open-in-app button it meets the contrast, tap '
          'target and label guidelines in ${mode.name} mode', (tester) async {
        await pumpCard(
          tester,
          progress: progress,
          onOpenInApp: () {},
          mode: mode,
        );
        expect(find.text(summary), findsOneWidget);

        await expectAccessibleGuidelines(tester);
      });
    }

    testWidgets('at 200% text on a 360×800 phone the home badge grows to '
        '48 px, the button stays 48 px and the text lays out whole at the '
        'system scale', (tester) async {
      await setLargeTextPhone(tester);
      await pumpCard(
        tester,
        progress: progress,
        onOpenInApp: () {},
        mode: ThemeMode.light,
      );

      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      expect(tester.getSize(homeBadge()), const Size(48, 48));
      expect(tester.getSize(openInApp), const Size.square(48));
      for (final (value, size) in [
        ('Retorno', 13.0),
        ('Ponto de partida', 15.0),
        (summary, 13.0),
      ]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(value))
              .textScaler
              .scale(size),
          size * 2,
        );
      }
    });
  });
}

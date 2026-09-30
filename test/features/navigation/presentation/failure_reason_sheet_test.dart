import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/features/navigation/presentation/failure_reason_sheet.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

void main() {
  const title = 'Por que não foi entregue?';
  const reasons = [
    'Destinatário ausente',
    'Endereço não encontrado',
    'Recusado',
    'Outro',
  ];

  late FailureReason? picked;
  late bool closed;

  /// Opens the sheet from a button and keeps what it returns.
  Future<void> pumpAndOpen(WidgetTester tester, {ThemeMode? mode}) async {
    picked = null;
    closed = false;
    final home = Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              picked = await FailureReasonSheet.show(context);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      mode == null ? MaterialApp(home: home) : themedApp(home, mode: mode),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('FailureReasonSheet', () {
    testWidgets('DS bottom sheet: surface-200 with top radius-lg, the title '
        '"Por que não foi entregue?" and the four reasons in order in '
        'body-strong, with 1 px dividers', (tester) async {
      await pumpAndOpen(tester);

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, RbColors.surface200);
      expect(
        sheet.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RbRadius.lg),
          ),
        ),
      );
      final heading = tester.widget<Text>(find.text(title));
      expect(heading.style!.fontSize, 17);
      expect(heading.style!.fontWeight, FontWeight.w600);
      expect(heading.style!.color, RbColors.ink);

      final tops = [
        for (final reason in reasons) tester.getTopLeft(find.text(reason)).dy,
      ];
      expect(
        tops.first,
        greaterThan(tester.getBottomLeft(find.text(title)).dy),
      );
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]));
      }
      for (final reason in reasons) {
        final row = tester.widget<Text>(find.text(reason));
        expect(row.style!.fontSize, 15);
        expect(row.style!.fontWeight, FontWeight.w600);
        expect(row.style!.color, RbColors.ink);
        expect(
          find.ancestor(of: find.text(reason), matching: find.byType(ListTile)),
          findsOneWidget,
        );
      }
      final dividers = tester.widgetList<Divider>(find.byType(Divider));
      expect(dividers, hasLength(3));
      for (final divider in dividers) {
        expect(divider.thickness, 1);
        expect(divider.color, RbColors.border);
      }
    });

    testWidgets('picking a reason closes the sheet and returns that reason', (
      tester,
    ) async {
      for (final (i, reason) in FailureReason.values.indexed) {
        await pumpAndOpen(tester);

        await tester.tap(find.text(reasons[i]));
        await tester.pumpAndSettle();

        expect(find.byType(FailureReasonSheet), findsNothing);
        expect(closed, isTrue);
        expect(picked, reason);
      }
    });

    testWidgets('closing the sheet without a pick returns null', (
      tester,
    ) async {
      await pumpAndOpen(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(FailureReasonSheet), findsNothing);
      expect(closed, isTrue);
      expect(picked, isNull);
    });
  });

  group('FailureReasonSheet in dark mode', () {
    testWidgets('#1A1D23 sheet with the title and reasons in #F2F4F7 and '
        '#2F343D dividers', (tester) async {
      await pumpAndOpen(tester, mode: ThemeMode.dark);

      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        const Color(0xFF1A1D23),
      );
      for (final text in [title, ...reasons]) {
        expect(
          tester.widget<Text>(find.text(text)).style!.color,
          const Color(0xFFF2F4F7),
        );
      }
      expect(
        tester
            .widgetList<Divider>(find.byType(Divider))
            .map((divider) => divider.color),
        List.filled(3, const Color(0xFF2F343D)),
      );
    });
  });

  group('FailureReasonSheet accessibility', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('meets the contrast, tap target and label guidelines in '
          '${mode.name} mode', (tester) async {
        await pumpAndOpen(tester, mode: mode);
        expect(find.text(title), findsOneWidget);

        await expectAccessibleGuidelines(tester);
      });
    }

    testWidgets('at 200% text on a 360×800 phone it lays out whole, opens at '
        'the title and scrolls to the last reason', (tester) async {
      await setLargeTextPhone(tester);
      await pumpAndOpen(tester, mode: ThemeMode.light);

      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(FailureReasonSheet)))
            .scale(15),
        30,
      );
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(tester.getRect(find.text(title)).top, greaterThan(sheet.top));
      expect(tester.getRect(find.text('Outro')).top, greaterThan(sheet.bottom));
      final scrollable = find.descendant(
        of: find.byType(FailureReasonSheet),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThanOrEqualTo(100),
      );

      await tester.drag(scrollable, const Offset(0, -1000));
      await tester.pumpAndSettle();

      final last = tester.getRect(find.text('Outro'));
      expect(last.top, greaterThanOrEqualTo(sheet.top));
      expect(last.bottom, lessThanOrEqualTo(sheet.bottom));
      await tester.tap(find.text('Outro'));
      await tester.pumpAndSettle();
      expect(picked, FailureReason.other);
    });
  });
}

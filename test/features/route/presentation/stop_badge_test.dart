import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';
import 'package:routebreeze/features/route/presentation/stop_badge.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

void main() {
  final delivered = StopResult.delivered(at: DateTime.utc(2026, 9, 28, 17));
  final failed = StopResult.failed(
    FailureReason.refused,
    at: DateTime.utc(2026, 9, 28, 17, 5),
  );

  Future<void> pumpBadge(
    WidgetTester tester, {
    StopResult? result,
    ThemeMode mode = ThemeMode.light,
  }) => tester.pumpWidget(
    themedApp(
      Scaffold(
        body: Center(child: StopBadge(order: 3, result: result)),
      ),
      mode: mode,
    ),
  );

  Color fillOf(WidgetTester tester) {
    final badge = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(StopBadge),
            matching: find.byType(Container),
          )
          .first,
    );
    return (badge.decoration! as BoxDecoration).color!;
  }

  Icon iconOf(WidgetTester tester) => tester.widget<Icon>(
    find.descendant(of: find.byType(StopBadge), matching: find.byType(Icon)),
  );

  group('StopBadge', () {
    testWidgets('no result: brand #2A6DF4 circle with the white number', (
      tester,
    ) async {
      await pumpBadge(tester);

      expect(fillOf(tester), const Color(0xFF2A6DF4));
      expect(
        tester.widget<Text>(find.text('3')).style!.color,
        const Color(0xFFFFFFFF),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('delivered: successStrong #0D7F4A circle with a white check '
        'instead of the number', (tester) async {
      await pumpBadge(tester, result: delivered);

      expect(fillOf(tester), const Color(0xFF0D7F4A));
      expect(iconOf(tester).icon, Icons.check);
      expect(iconOf(tester).color, const Color(0xFFFFFFFF));
      expect(find.text('3'), findsNothing);
    });

    testWidgets('not delivered: dangerStrong #D01E23 circle with a white "×" '
        'instead of the number', (tester) async {
      await pumpBadge(tester, result: failed);

      expect(fillOf(tester), const Color(0xFFD01E23));
      expect(iconOf(tester).icon, Icons.close);
      expect(iconOf(tester).color, const Color(0xFFFFFFFF));
      expect(find.text('3'), findsNothing);
    });

    testWidgets('24 px at 100% text, with and without a result', (
      tester,
    ) async {
      for (final result in [null, delivered, failed]) {
        await pumpBadge(tester, result: result);

        expect(tester.getSize(find.byType(StopBadge)), const Size(24, 24));
      }
    });

    testWidgets('grows with the system text: 48 px at 200%, with and '
        'without a result', (tester) async {
      await setLargeTextPhone(tester);
      for (final result in [null, delivered, failed]) {
        await pumpBadge(tester, result: result);

        expect(tester.getSize(find.byType(StopBadge)), const Size(48, 48));
      }
    });
  });

  group('StopBadge in dark mode', () {
    testWidgets('no result: #7EA6F8 circle with a #0F1115 number', (
      tester,
    ) async {
      await pumpBadge(tester, mode: ThemeMode.dark);

      expect(fillOf(tester), const Color(0xFF7EA6F8));
      expect(
        tester.widget<Text>(find.text('3')).style!.color,
        const Color(0xFF0F1115),
      );
    });

    testWidgets('delivered: #12B76A circle with a #0F1115 check', (
      tester,
    ) async {
      await pumpBadge(tester, result: delivered, mode: ThemeMode.dark);

      expect(fillOf(tester), const Color(0xFF12B76A));
      expect(iconOf(tester).icon, Icons.check);
      expect(iconOf(tester).color, const Color(0xFF0F1115));
    });

    testWidgets('not delivered: #EB7074 circle with a #0F1115 "×"', (
      tester,
    ) async {
      await pumpBadge(tester, result: failed, mode: ThemeMode.dark);

      expect(fillOf(tester), const Color(0xFFEB7074));
      expect(iconOf(tester).icon, Icons.close);
      expect(iconOf(tester).color, const Color(0xFF0F1115));
    });
  });

  group('StopBadge semantics', () {
    Future<String> announced(WidgetTester tester, StopResult? result) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StopBadge(order: 2, result: result)),
        ),
      );
      return tester.getSemantics(find.byType(StopBadge)).label;
    }

    testWidgets('without a result it is announced as "Parada 2"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      expect(await announced(tester, null), 'Parada 2');
      semantics.dispose();
    });

    testWidgets('delivered, it is announced as "Parada 2, entregue"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      expect(await announced(tester, delivered), 'Parada 2, entregue');
      semantics.dispose();
    });

    testWidgets('not delivered, it is announced as "Parada 2, não entregue"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      expect(await announced(tester, failed), 'Parada 2, não entregue');
      semantics.dispose();
    });
  });
}

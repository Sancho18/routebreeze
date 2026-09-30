import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/route/presentation/stop_badge.dart';

import '../../../helpers/themed_app.dart';

void main() {
  Future<void> pumpDarkBadge(WidgetTester tester, {bool visited = false}) =>
      tester.pumpWidget(
        themedApp(
          Scaffold(
            body: Center(child: StopBadge(order: 3, visited: visited)),
          ),
          mode: ThemeMode.dark,
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

  group('StopBadge', () {
    testWidgets('dark mode: pending badge #7EA6F8 with a #0F1115 number', (
      tester,
    ) async {
      await pumpDarkBadge(tester);

      expect(fillOf(tester), const Color(0xFF7EA6F8));
      expect(
        tester.widget<Text>(find.text('3')).style!.color,
        const Color(0xFF0F1115),
      );
    });

    testWidgets('dark mode: visited badge #12B76A with a #0F1115 check', (
      tester,
    ) async {
      await pumpDarkBadge(tester, visited: true);

      expect(fillOf(tester), const Color(0xFF12B76A));
      final check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.color, const Color(0xFF0F1115));
    });
  });

  group('StopBadge semantics', () {
    test('label: "Parada {n}" pending, "Parada {n}, visitada" visited', () {
      expect(StopBadge.label(2), 'Parada 2');
      expect(StopBadge.label(2, visited: true), 'Parada 2, visitada');
    });

    testWidgets('pending badge is announced as "Parada 2"', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StopBadge(order: 2))),
      );

      expect(tester.getSemantics(find.byType(StopBadge)).label, 'Parada 2');
      semantics.dispose();
    });

    testWidgets('visited badge is announced as "Parada 2, visitada"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StopBadge(order: 2, visited: true)),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StopBadge)).label,
        'Parada 2, visitada',
      );
      semantics.dispose();
    });
  });
}

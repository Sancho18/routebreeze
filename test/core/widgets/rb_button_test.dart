import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';

void main() {
  const label = 'Confirmar rota';

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  Material buttonMaterial(WidgetTester tester) => tester.widget<Material>(
    find
        .descendant(
          of: find.byType(RbPrimaryButton),
          matching: find.byType(Material),
        )
        .first,
  );

  TextStyle labelStyle(WidgetTester tester) =>
      tester.widget<Text>(find.text(label)).style!;

  group('RbPrimaryButton', () {
    testWidgets('enabled: brand background, white body-strong label, '
        'radius-lg, height 52, calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(RbPrimaryButton(label: label, onPressed: () => taps++)),
      );

      final material = buttonMaterial(tester);
      expect(material.color, RbColors.brand);
      expect(material.borderRadius, BorderRadius.circular(24));

      final style = labelStyle(tester);
      expect(style.color, Colors.white);
      expect(style.fontSize, 15);
      expect(style.height, 22 / 15);
      expect(style.fontWeight, FontWeight.w600);

      expect(tester.getSize(find.byType(RbPrimaryButton)).height, 52);

      await tester.tap(find.byType(RbPrimaryButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('disabled: border background, ink-muted label, tap ignored, '
        'same size and position as enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(RbPrimaryButton(label: label, onPressed: () => taps++)),
      );
      final enabledRect = tester.getRect(find.byType(RbPrimaryButton));

      await tester.pumpWidget(
        wrap(
          RbPrimaryButton(
            label: label,
            enabled: false,
            onPressed: () => taps++,
          ),
        ),
      );

      final material = buttonMaterial(tester);
      expect(material.color, RbColors.border);
      expect(material.borderRadius, BorderRadius.circular(24));
      expect(labelStyle(tester).color, RbColors.inkMuted);
      expect(tester.getRect(find.byType(RbPrimaryButton)), enabledRect);

      await tester.tap(find.byType(RbPrimaryButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('loading: shows a 20 px spinner instead of the label and '
        'ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          RbPrimaryButton(label: label, loading: true, onPressed: () => taps++),
        ),
      );

      final spinner = find.byType(CircularProgressIndicator);
      expect(spinner, findsOneWidget);
      expect(tester.getSize(spinner), const Size(20, 20));
      expect(find.text(label), findsNothing);
      expect(buttonMaterial(tester).color, RbColors.brand);
      expect(tester.getSize(find.byType(RbPrimaryButton)).height, 52);

      await tester.tap(find.byType(RbPrimaryButton));
      await tester.pump();
      expect(taps, 0);
    });
  });
}

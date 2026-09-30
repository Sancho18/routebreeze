import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';

import '../../helpers/accessibility.dart';
import '../../helpers/themed_app.dart';

void main() {
  const label = 'Confirmar rota';

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  Widget wrapDark(Widget child) => themedApp(
    Scaffold(body: Center(child: child)),
    mode: ThemeMode.dark,
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

    testWidgets('loading: shows a 20 px spinner over the hidden label and '
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
      expect(
        tester.renderObject(find.byType(RbPrimaryButton)),
        isNot(paints..paragraph()),
      );
      expect(buttonMaterial(tester).color, RbColors.brand);
      expect(tester.getSize(find.byType(RbPrimaryButton)).height, 52);

      await tester.tap(find.byType(RbPrimaryButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('color: danger background with white label while enabled, '
        'border/ink-muted while disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          RbPrimaryButton(
            label: label,
            color: RbColors.danger,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(buttonMaterial(tester).color, RbColors.danger);
      expect(labelStyle(tester).color, Colors.white);
      expect(tester.getSize(find.byType(RbPrimaryButton)).height, 52);
      await tester.tap(find.byType(RbPrimaryButton));
      expect(taps, 1);

      await tester.pumpWidget(
        wrap(
          RbPrimaryButton(
            label: label,
            color: RbColors.danger,
            enabled: false,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(buttonMaterial(tester).color, RbColors.border);
      expect(labelStyle(tester).color, RbColors.inkMuted);
      await tester.tap(find.byType(RbPrimaryButton));
      expect(taps, 1);
    });
  });

  group('RbPrimaryButton at 200% text on a 360×800 phone', () {
    testWidgets('a label that wraps shows whole: the button grows past 52', (
      tester,
    ) async {
      await setLargeTextPhone(tester);
      await tester.pumpWidget(
        wrap(RbPrimaryButton(label: label, onPressed: () {})),
      );

      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.textSize.height,
        closeTo(2 * paragraph.preferredLineHeight, 0.01),
      );
      expect(
        tester.getSize(find.byType(RbPrimaryButton)).height,
        greaterThan(52),
      );
      expectNoClippedText(tester);
    });

    testWidgets('loading keeps the height of the label button', (tester) async {
      await setLargeTextPhone(tester);
      await tester.pumpWidget(
        wrap(RbPrimaryButton(label: label, onPressed: () {})),
      );
      final labelHeight = tester.getSize(find.byType(RbPrimaryButton)).height;

      await tester.pumpWidget(
        wrap(RbPrimaryButton(label: label, loading: true, onPressed: () {})),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(labelHeight, greaterThan(52));
      expect(tester.getSize(find.byType(RbPrimaryButton)).height, labelHeight);
    });
  });

  group('RbPrimaryButton in dark mode', () {
    testWidgets('enabled: dark brand #7EA6F8 fill with a #0F1115 label', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapDark(RbPrimaryButton(label: label, onPressed: () {})),
      );

      expect(buttonMaterial(tester).color, const Color(0xFF7EA6F8));
      expect(labelStyle(tester).color, const Color(0xFF0F1115));
    });

    testWidgets('disabled: dark border #2F343D fill with a #A4ACB9 label', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapDark(
          RbPrimaryButton(label: label, enabled: false, onPressed: () {}),
        ),
      );

      expect(buttonMaterial(tester).color, const Color(0xFF2F343D));
      expect(labelStyle(tester).color, const Color(0xFFA4ACB9));
    });

    testWidgets('color: a custom fill is kept, with the #0F1115 label', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapDark(
          RbPrimaryButton(
            label: label,
            color: const Color(0xFFEB7074),
            onPressed: () {},
          ),
        ),
      );

      expect(buttonMaterial(tester).color, const Color(0xFFEB7074));
      expect(labelStyle(tester).color, const Color(0xFF0F1115));
    });
  });

  group('RbSecondaryButton', () {
    const secondaryLabel = 'Não entregue';

    Material outline(WidgetTester tester) => tester.widget<Material>(
      find
          .descendant(
            of: find.byType(RbSecondaryButton),
            matching: find.byType(Material),
          )
          .first,
    );

    RoundedRectangleBorder shapeOf(WidgetTester tester) =>
        outline(tester).shape! as RoundedRectangleBorder;

    TextStyle secondaryStyle(WidgetTester tester) =>
        tester.widget<Text>(find.text(secondaryLabel)).style!;

    testWidgets('enabled: transparent fill, 1 px brand #2A6DF4 outline, '
        'radius-lg, #1B63F3 body-strong label, height 52, calls onPressed', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(RbSecondaryButton(label: secondaryLabel, onPressed: () => taps++)),
      );

      expect(outline(tester).color, Colors.transparent);
      expect(shapeOf(tester).borderRadius, BorderRadius.circular(24));
      expect(shapeOf(tester).side.color, const Color(0xFF2A6DF4));
      expect(shapeOf(tester).side.width, 1);

      final style = secondaryStyle(tester);
      expect(style.color, const Color(0xFF1B63F3));
      expect(style.fontSize, 15);
      expect(style.height, 22 / 15);
      expect(style.fontWeight, FontWeight.w600);

      expect(tester.getSize(find.byType(RbSecondaryButton)).height, 52);

      await tester.tap(find.byType(RbSecondaryButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('disabled: border-colored outline, ink-muted label, tap '
        'ignored, same size and position as enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(RbSecondaryButton(label: secondaryLabel, onPressed: () => taps++)),
      );
      final enabledRect = tester.getRect(find.byType(RbSecondaryButton));

      await tester.pumpWidget(
        wrap(
          RbSecondaryButton(
            label: secondaryLabel,
            enabled: false,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(outline(tester).color, Colors.transparent);
      expect(shapeOf(tester).borderRadius, BorderRadius.circular(24));
      expect(shapeOf(tester).side.color, RbColors.border);
      expect(secondaryStyle(tester).color, RbColors.inkMuted);
      expect(tester.getRect(find.byType(RbSecondaryButton)), enabledRect);

      await tester.tap(find.byType(RbSecondaryButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('at 200% text a label that wraps shows whole at the system '
        'scale and the button grows like the primary one', (tester) async {
      await setLargeTextPhone(tester);
      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RbPrimaryButton(label: secondaryLabel, onPressed: () {}),
              RbSecondaryButton(label: secondaryLabel, onPressed: () {}),
            ],
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(RbSecondaryButton),
          matching: find.text(secondaryLabel),
        ),
      );
      expect(paragraph.textScaler.scale(15), 30);
      expect(
        paragraph.textSize.height,
        closeTo(2 * paragraph.preferredLineHeight, 0.01),
      );
      final height = tester.getSize(find.byType(RbSecondaryButton)).height;
      expect(height, greaterThan(52));
      expect(tester.getSize(find.byType(RbPrimaryButton)).height, height);
      expect(
        tester.getCenter(
          find.descendant(
            of: find.byType(RbSecondaryButton),
            matching: find.text(secondaryLabel),
          ),
        ),
        tester.getCenter(find.byType(RbSecondaryButton)),
      );
      expectNoClippedText(tester);
    });

    testWidgets('dark mode: #7EA6F8 outline and label on a transparent '
        'fill', (tester) async {
      await tester.pumpWidget(
        wrapDark(RbSecondaryButton(label: secondaryLabel, onPressed: () {})),
      );

      expect(outline(tester).color, Colors.transparent);
      expect(shapeOf(tester).side.color, const Color(0xFF7EA6F8));
      expect(secondaryStyle(tester).color, const Color(0xFF7EA6F8));
    });

    testWidgets('dark mode disabled: #2F343D outline with a #A4ACB9 label', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapDark(
          RbSecondaryButton(
            label: secondaryLabel,
            enabled: false,
            onPressed: () {},
          ),
        ),
      );

      expect(shapeOf(tester).side.color, const Color(0xFF2F343D));
      expect(secondaryStyle(tester).color, const Color(0xFFA4ACB9));
    });
  });
}

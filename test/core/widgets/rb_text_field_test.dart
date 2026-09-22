import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_text_field.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  InputDecoration decorationOf(WidgetTester tester) =>
      tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

  void expectOutline(InputBorder? border, Color color) {
    expect(border, isA<OutlineInputBorder>());
    final outline = border! as OutlineInputBorder;
    expect(outline.borderSide.color, color);
    expect(outline.borderRadius, BorderRadius.circular(12));
  }

  group('RbTextField', () {
    testWidgets('default: surface-200 fill, border outline radius-md, '
        'padding 16, placeholder in ink-muted', (tester) async {
      await tester.pumpWidget(wrap(const RbTextField(placeholder: 'Ponto A')));

      final decoration = decorationOf(tester);
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, RbColors.surface200);
      expect(decoration.contentPadding, const EdgeInsets.all(16));
      expectOutline(decoration.enabledBorder, RbColors.border);
      expectOutline(decoration.focusedBorder, RbColors.brand);
      expect(decoration.errorText, isNull);

      final hint = tester.widget<Text>(find.text('Ponto A'));
      expect(hint.style!.color, RbColors.inkMuted);
      expect(hint.style!.fontSize, 15);
      expect(hint.style!.fontWeight, FontWeight.w400);
    });

    testWidgets('error: danger outline and message in caption/danger', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const RbTextField(
            placeholder: 'Ponto A',
            errorText: 'Campo obrigatório',
          ),
        ),
      );

      final decoration = decorationOf(tester);
      expect(decoration.errorText, 'Campo obrigatório');
      expectOutline(decoration.errorBorder, RbColors.danger);
      expectOutline(decoration.focusedErrorBorder, RbColors.danger);

      final message = tester.widget<Text>(find.text('Campo obrigatório'));
      expect(message.style!.color, RbColors.danger);
      expect(message.style!.fontSize, 13);
      expect(message.style!.height, 18 / 13);
      expect(message.style!.fontWeight, FontWeight.w400);
    });

    testWidgets('renders the trailing widget', (tester) async {
      await tester.pumpWidget(
        wrap(const RbTextField(trailing: Icon(Icons.close))),
      );

      expect(
        find.descendant(
          of: find.byType(RbTextField),
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
      );
    });

    testWidgets('maxLength caps the text without showing a counter', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(RbTextField(controller: controller, maxLength: 200)),
      );

      await tester.enterText(find.byType(TextField), 'a' * 201);
      await tester.pump();

      expect(controller.text.length, 200);
      expect(find.textContaining('/200'), findsNothing);
      expect(find.text('200'), findsNothing);
    });

    testWidgets('onChanged fires with the typed text', (tester) async {
      String? changed;
      await tester.pumpWidget(
        wrap(RbTextField(onChanged: (value) => changed = value)),
      );

      await tester.enterText(find.byType(TextField), 'Av. Paulista');

      expect(changed, 'Av. Paulista');
    });
  });
}

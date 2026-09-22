import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_feedback.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    ),
  );

  Container containerOf<T extends Widget>(WidgetTester tester) =>
      tester.widget<Container>(
        find.descendant(of: find.byType(T), matching: find.byType(Container)),
      );

  group('RbStatusChip', () {
    Future<void> expectChip(
      WidgetTester tester, {
      required String label,
      required RbTone tone,
      required Color background,
      required Color foreground,
    }) async {
      await tester.pumpWidget(wrap(RbStatusChip(label: label, tone: tone)));

      final decoration =
          containerOf<RbStatusChip>(tester).decoration! as BoxDecoration;
      expect(decoration.color, background);
      expect(decoration.borderRadius, BorderRadius.circular(6));

      final text = tester.widget<Text>(find.text(label));
      expect(text.style!.color, foreground);
      expect(text.style!.fontSize, 13);
      expect(text.style!.height, 18 / 13);
      expect(text.style!.fontWeight, FontWeight.w400);
    }

    testWidgets('success: "Visitado" in success on success 12%', (
      tester,
    ) async {
      await expectChip(
        tester,
        label: 'Visitado',
        tone: RbTone.success,
        background: RbColors.success.withValues(alpha: 0.12),
        foreground: RbColors.success,
      );
    });

    testWidgets('warning: "Rota recalculada" in warning on warning 12%', (
      tester,
    ) async {
      await expectChip(
        tester,
        label: 'Rota recalculada',
        tone: RbTone.warning,
        background: RbColors.warning.withValues(alpha: 0.12),
        foreground: RbColors.warning,
      );
    });

    testWidgets('danger: "Falha ao recalcular" in danger on danger 12%', (
      tester,
    ) async {
      await expectChip(
        tester,
        label: 'Falha ao recalcular',
        tone: RbTone.danger,
        background: RbColors.danger.withValues(alpha: 0.12),
        foreground: RbColors.danger,
      );
    });

    testWidgets('neutral: ink-muted on border', (tester) async {
      await expectChip(
        tester,
        label: 'Pendente',
        tone: RbTone.neutral,
        background: RbColors.border,
        foreground: RbColors.inkMuted,
      );
    });
  });

  group('RbBanner', () {
    testWidgets('danger: "Sem conexão" full-width, danger background, '
        'white body-strong text, padding s2/s3', (tester) async {
      await tester.pumpWidget(
        wrap(const RbBanner(text: 'Sem conexão', tone: RbTone.danger)),
      );

      final container = containerOf<RbBanner>(tester);
      expect(container.color, RbColors.danger);
      expect(
        container.padding,
        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      );
      expect(
        tester.getSize(find.byType(RbBanner)).width,
        tester.getSize(find.byType(Scaffold)).width,
      );

      final text = tester.widget<Text>(find.text('Sem conexão'));
      expect(text.style!.color, Colors.white);
      expect(text.style!.fontSize, 15);
      expect(text.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('warning: warning background with white text', (tester) async {
      await tester.pumpWidget(
        wrap(const RbBanner(text: 'Aviso', tone: RbTone.warning)),
      );

      expect(containerOf<RbBanner>(tester).color, RbColors.warning);
      expect(
        tester.widget<Text>(find.text('Aviso')).style!.color,
        Colors.white,
      );
    });
  });

  group('RbInlineError', () {
    testWidgets('danger body text and action button calling onAction', (
      tester,
    ) async {
      var actions = 0;
      await tester.pumpWidget(
        wrap(
          RbInlineError(
            text: 'Não foi possível calcular a rota.',
            actionLabel: 'Tentar novamente',
            onAction: () => actions++,
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.text('Não foi possível calcular a rota.'),
      );
      expect(text.style!.color, RbColors.danger);
      expect(text.style!.fontSize, 15);
      expect(text.style!.fontWeight, FontWeight.w400);

      await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
      await tester.pump();
      expect(actions, 1);
    });

    testWidgets('without actionLabel renders no button', (tester) async {
      await tester.pumpWidget(
        wrap(const RbInlineError(text: 'Perdemos o sinal de GPS')),
      );

      expect(find.text('Perdemos o sinal de GPS'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}

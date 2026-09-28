import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_feedback.dart';

import '../../helpers/themed_app.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    ),
  );

  Widget wrapDark(Widget child) => themedApp(
    Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    ),
    mode: ThemeMode.dark,
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
      bool dark = false,
    }) async {
      final chip = RbStatusChip(label: label, tone: tone);
      await tester.pumpWidget(dark ? wrapDark(chip) : wrap(chip));

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

    group('in dark mode', () {
      for (final (tone, color, hex) in const [
        (RbTone.success, Color(0xFF12B76A), '#12B76A'),
        (RbTone.warning, Color(0xFFF59E0B), '#F59E0B'),
        (RbTone.danger, Color(0xFFEB7074), '#EB7074'),
      ]) {
        testWidgets('${tone.name}: $hex text on $hex 12%', (tester) async {
          await expectChip(
            tester,
            label: 'Status',
            tone: tone,
            background: color.withValues(alpha: 0.12),
            foreground: color,
            dark: true,
          );
        });
      }

      testWidgets('neutral: #A4ACB9 text on #2F343D', (tester) async {
        await expectChip(
          tester,
          label: 'Pendente',
          tone: RbTone.neutral,
          background: const Color(0xFF2F343D),
          foreground: const Color(0xFFA4ACB9),
          dark: true,
        );
      });
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

    group('in dark mode', () {
      Future<void> expectBanner(
        WidgetTester tester,
        RbTone tone, {
        required Color fill,
        required Color text,
      }) async {
        await tester.pumpWidget(
          wrapDark(RbBanner(text: 'Sem conexão', tone: tone)),
        );

        expect(containerOf<RbBanner>(tester).color, fill);
        expect(
          tester.widget<Text>(find.text('Sem conexão')).style!.color,
          text,
        );
      }

      for (final (tone, fill, hex) in const [
        (RbTone.success, Color(0xFF12B76A), '#12B76A'),
        (RbTone.warning, Color(0xFFF59E0B), '#F59E0B'),
        (RbTone.danger, Color(0xFFEB7074), '#EB7074'),
      ]) {
        testWidgets('${tone.name}: $hex fill with #0F1115 text', (
          tester,
        ) async {
          await expectBanner(
            tester,
            tone,
            fill: fill,
            text: const Color(0xFF0F1115),
          );
        });
      }

      testWidgets('neutral: #2F343D fill with #F2F4F7 text', (tester) async {
        await expectBanner(
          tester,
          RbTone.neutral,
          fill: const Color(0xFF2F343D),
          text: const Color(0xFFF2F4F7),
        );
      });
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

    testWidgets('dark mode: #EB7074 text and #7EA6F8 action', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          RbInlineError(
            text: 'Não foi possível calcular a rota.',
            actionLabel: 'Tentar novamente',
            onAction: () {},
          ),
        ),
      );

      expect(
        tester
            .widget<Text>(find.text('Não foi possível calcular a rota.'))
            .style!
            .color,
        const Color(0xFFEB7074),
      );
      final action = tester.widget<RichText>(
        find.descendant(
          of: find.widgetWithText(TextButton, 'Tentar novamente'),
          matching: find.byType(RichText),
        ),
      );
      expect(action.text.style!.color, const Color(0xFF7EA6F8));
    });
  });
}

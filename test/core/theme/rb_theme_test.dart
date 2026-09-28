import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_palette.dart';
import 'package:routebreeze/core/theme/rb_theme.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';

import '../../helpers/themed_app.dart';

void main() {
  group('buildRbTheme', () {
    test('is Material 3 with brand primary and surface-100 background', () {
      final theme = buildRbTheme();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, RbColors.brand);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F8FA));
    });

    testWidgets('Theme.of(context) uses the platform font and Rota styles', (
      tester,
    ) async {
      late ThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRbTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                resolved = Theme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final text = resolved.textTheme;
      final styles = [
        text.displayLarge,
        text.displayMedium,
        text.displaySmall,
        text.headlineLarge,
        text.headlineMedium,
        text.headlineSmall,
        text.titleLarge,
        text.titleMedium,
        text.titleSmall,
        text.bodyLarge,
        text.bodyMedium,
        text.bodySmall,
        text.labelLarge,
        text.labelMedium,
        text.labelSmall,
      ];
      for (final style in styles) {
        expect(style, isNotNull);
        expect(style!.fontFamily, isNull);
      }

      void expectMapped(TextStyle? slot, TextStyle token) {
        expect(slot!.fontSize, token.fontSize);
        expect(slot.height, token.height);
        expect(slot.fontWeight, token.fontWeight);
        expect(slot.color, RbColors.ink);
      }

      expectMapped(text.displaySmall, RbText.display);
      expectMapped(text.titleLarge, RbText.title);
      expectMapped(text.titleMedium, RbText.heading);
      expectMapped(text.bodyLarge, RbText.bodyStrong);
      expectMapped(text.bodyMedium, RbText.body);
      expectMapped(text.bodySmall, RbText.caption);

      final scaffoldMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(scaffoldMaterial.color, const Color(0xFFF7F8FA));
    });

    test('light theme keeps the DS values and attaches the light palette', () {
      final theme = buildRbTheme();

      _expectThemeColors(
        theme,
        brightness: Brightness.light,
        brand: const Color(0xFF2A6DF4),
        onFill: const Color(0xFFFFFFFF),
        danger: const Color(0xFFE5484D),
        surface100: const Color(0xFFF7F8FA),
        surface200: const Color(0xFFFFFFFF),
        ink: const Color(0xFF12141A),
        inkMuted: const Color(0xFF5B6472),
        border: const Color(0xFFE2E5EA),
      );
      expect(theme.extension<RbPalette>(), same(RbPalette.light));
    });

    test('dark theme takes every color from the dark palette', () {
      final theme = buildRbTheme(RbPalette.dark);

      _expectThemeColors(
        theme,
        brightness: Brightness.dark,
        brand: const Color(0xFF7EA6F8),
        onFill: const Color(0xFF0F1115),
        danger: const Color(0xFFEB7074),
        surface100: const Color(0xFF0F1115),
        surface200: const Color(0xFF1A1D23),
        ink: const Color(0xFFF2F4F7),
        inkMuted: const Color(0xFFA4ACB9),
        border: const Color(0xFF2F343D),
      );
      expect(theme.extension<RbPalette>(), same(RbPalette.dark));
    });

    testWidgets(
      'dark mode paints the scaffold and text from the dark palette',
      (tester) async {
        late ThemeData resolved;
        await tester.pumpWidget(
          themedApp(
            Scaffold(
              body: Builder(
                builder: (context) {
                  resolved = Theme.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            mode: ThemeMode.dark,
          ),
        );

        expect(resolved.brightness, Brightness.dark);
        expect(resolved.extension<RbPalette>(), same(RbPalette.dark));
        for (final style in _slots(resolved.textTheme)) {
          expect(style!.color, const Color(0xFFF2F4F7));
        }
        final scaffoldMaterial = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(Scaffold),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(scaffoldMaterial.color, const Color(0xFF0F1115));
      },
    );
  });
}

List<TextStyle?> _slots(TextTheme text) => [
  text.displayLarge,
  text.displayMedium,
  text.displaySmall,
  text.headlineLarge,
  text.headlineMedium,
  text.headlineSmall,
  text.titleLarge,
  text.titleMedium,
  text.titleSmall,
  text.bodyLarge,
  text.bodyMedium,
  text.bodySmall,
  text.labelLarge,
  text.labelMedium,
  text.labelSmall,
];

/// Expects the scheme, component and text colors of one palette's theme.
void _expectThemeColors(
  ThemeData theme, {
  required Brightness brightness,
  required Color brand,
  required Color onFill,
  required Color danger,
  required Color surface100,
  required Color surface200,
  required Color ink,
  required Color inkMuted,
  required Color border,
}) {
  final scheme = theme.colorScheme;
  expect(theme.brightness, brightness);
  expect(scheme.primary, brand);
  expect(scheme.onPrimary, onFill);
  expect(scheme.secondary, brand);
  expect(scheme.onSecondary, onFill);
  expect(scheme.error, danger);
  expect(scheme.onError, onFill);
  expect(scheme.surface, surface200);
  expect(scheme.onSurface, ink);
  expect(scheme.outline, border);
  expect(theme.scaffoldBackgroundColor, surface100);

  final input = theme.inputDecorationTheme;
  expect(input.fillColor, surface200);
  expect(input.border!.borderSide.color, border);
  expect(input.enabledBorder!.borderSide.color, border);
  expect(input.focusedBorder!.borderSide.color, brand);
  expect(input.errorBorder!.borderSide.color, danger);
  expect(input.focusedErrorBorder!.borderSide.color, danger);
  expect(input.hintStyle!.color, inkMuted);
  expect(input.errorStyle!.color, danger);

  const disabled = {WidgetState.disabled};
  final filled = theme.filledButtonTheme.style!;
  expect(filled.backgroundColor!.resolve({}), brand);
  expect(filled.foregroundColor!.resolve({}), onFill);
  expect(filled.backgroundColor!.resolve(disabled), border);
  expect(filled.foregroundColor!.resolve(disabled), inkMuted);
  expect(theme.textButtonTheme.style!.foregroundColor!.resolve({}), brand);

  for (final style in _slots(theme.textTheme)) {
    expect(style!.color, ink);
  }
}

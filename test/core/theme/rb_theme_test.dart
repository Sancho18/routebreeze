import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_theme.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';

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
  });
}

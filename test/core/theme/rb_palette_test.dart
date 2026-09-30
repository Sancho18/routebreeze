import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_palette.dart';

import '../../helpers/contrast.dart';

List<Color> _colors(RbPalette p) => [
  p.brand,
  p.onFill,
  p.success,
  p.warning,
  p.danger,
  p.successStrong,
  p.warningStrong,
  p.dangerStrong,
  p.brandStrong,
  p.surface100,
  p.surface200,
  p.ink,
  p.inkMuted,
  p.border,
];

List<Object> _fields(RbPalette p) => [p.brightness, ..._colors(p)];

void main() {
  group('RbPalette values', () {
    test('light holds the DS values of the Palette table', () {
      const light = RbPalette.light;

      expect(light.brightness, Brightness.light);
      expect(light.brand, const Color(0xFF2A6DF4));
      expect(light.onFill, const Color(0xFFFFFFFF));
      expect(light.success, const Color(0xFF12B76A));
      expect(light.warning, const Color(0xFFF59E0B));
      expect(light.danger, const Color(0xFFE5484D));
      expect(light.successStrong, const Color(0xFF0D7F4A));
      expect(light.warningStrong, const Color(0xFF996206));
      expect(light.dangerStrong, const Color(0xFFD01E23));
      expect(light.brandStrong, const Color(0xFF1B63F3));
      expect(light.surface100, const Color(0xFFF7F8FA));
      expect(light.surface200, const Color(0xFFFFFFFF));
      expect(light.ink, const Color(0xFF12141A));
      expect(light.inkMuted, const Color(0xFF5B6472));
      expect(light.border, const Color(0xFFE2E5EA));
    });

    test('dark holds the dark values of the Palette table', () {
      const dark = RbPalette.dark;

      expect(dark.brightness, Brightness.dark);
      expect(dark.brand, const Color(0xFF7EA6F8));
      expect(dark.onFill, const Color(0xFF0F1115));
      expect(dark.success, const Color(0xFF12B76A));
      expect(dark.warning, const Color(0xFFF59E0B));
      expect(dark.danger, const Color(0xFFEB7074));
      expect(dark.successStrong, const Color(0xFF12B76A));
      expect(dark.warningStrong, const Color(0xFFF59E0B));
      expect(dark.dangerStrong, const Color(0xFFEB7074));
      expect(dark.brandStrong, const Color(0xFF7EA6F8));
      expect(dark.surface100, const Color(0xFF0F1115));
      expect(dark.surface200, const Color(0xFF1A1D23));
      expect(dark.ink, const Color(0xFFF2F4F7));
      expect(dark.inkMuted, const Color(0xFFA4ACB9));
      expect(dark.border, const Color(0xFF2F343D));
    });
  });

  group('dark palette contrast is at least 4.5:1', () {
    const dark = RbPalette.dark;

    // The status chip draws its tone at 12% over surface-200.
    Color chipTint(Color tone) =>
        Color.alphaBlend(tone.withValues(alpha: 0.12), dark.surface200);

    test('the WCAG helper gives the reference ratios', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);

      expect(contrastRatio(black, white), closeTo(21, 1e-9));
      expect(contrastRatio(white, black), closeTo(21, 1e-9));
      expect(
        contrastRatio(const Color(0xFF767676), white),
        closeTo(4.54, 0.005),
      );
      expect(contrastRatio(white, white), 1);
    });

    final pairs = <String, (Color, Color)>{
      'ink on surface-100': (dark.ink, dark.surface100),
      'ink on surface-200': (dark.ink, dark.surface200),
      'ink-muted on surface-100': (dark.inkMuted, dark.surface100),
      'ink-muted on surface-200': (dark.inkMuted, dark.surface200),
      'brand on surface-100': (dark.brand, dark.surface100),
      'brand on surface-200': (dark.brand, dark.surface200),
      'success on surface-100': (dark.success, dark.surface100),
      'success on surface-200': (dark.success, dark.surface200),
      'danger on surface-100': (dark.danger, dark.surface100),
      'danger on surface-200': (dark.danger, dark.surface200),
      'onFill on brand': (dark.onFill, dark.brand),
      'onFill on success': (dark.onFill, dark.success),
      'onFill on danger': (dark.onFill, dark.danger),
      'warning on its chip tint': (dark.warning, chipTint(dark.warning)),
      'danger on its chip tint': (dark.danger, chipTint(dark.danger)),
      'ink-muted on border (disabled button)': (dark.inkMuted, dark.border),
      'successStrong on surface-100': (dark.successStrong, dark.surface100),
      'successStrong on surface-200': (dark.successStrong, dark.surface200),
      'successStrong on its chip tint': (
        dark.successStrong,
        chipTint(dark.success),
      ),
      'onFill on successStrong': (dark.onFill, dark.successStrong),
      'warningStrong on surface-100': (dark.warningStrong, dark.surface100),
      'warningStrong on surface-200': (dark.warningStrong, dark.surface200),
      'warningStrong on its chip tint': (
        dark.warningStrong,
        chipTint(dark.warning),
      ),
      'onFill on warningStrong': (dark.onFill, dark.warningStrong),
      'dangerStrong on surface-100': (dark.dangerStrong, dark.surface100),
      'dangerStrong on surface-200': (dark.dangerStrong, dark.surface200),
      'dangerStrong on its chip tint': (
        dark.dangerStrong,
        chipTint(dark.danger),
      ),
      'onFill on dangerStrong': (dark.onFill, dark.dangerStrong),
      'brandStrong on surface-100': (dark.brandStrong, dark.surface100),
      'brandStrong on surface-200': (dark.brandStrong, dark.surface200),
    };
    for (final MapEntry(key: name, value: (text, background))
        in pairs.entries) {
      test(name, () {
        expect(contrastRatio(text, background), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('light palette contrast of the strong roles is at least 4.5:1', () {
    const light = RbPalette.light;

    Color chipTint(Color tone) =>
        Color.alphaBlend(tone.withValues(alpha: 0.12), light.surface200);

    final pairs = <String, (Color, Color)>{
      'successStrong on surface-100': (light.successStrong, light.surface100),
      'successStrong on surface-200': (light.successStrong, light.surface200),
      'successStrong on its chip tint': (
        light.successStrong,
        chipTint(light.success),
      ),
      'onFill on successStrong': (light.onFill, light.successStrong),
      'warningStrong on surface-100': (light.warningStrong, light.surface100),
      'warningStrong on surface-200': (light.warningStrong, light.surface200),
      'warningStrong on its chip tint': (
        light.warningStrong,
        chipTint(light.warning),
      ),
      'onFill on warningStrong': (light.onFill, light.warningStrong),
      'dangerStrong on surface-100': (light.dangerStrong, light.surface100),
      'dangerStrong on surface-200': (light.dangerStrong, light.surface200),
      'dangerStrong on its chip tint': (
        light.dangerStrong,
        chipTint(light.danger),
      ),
      'onFill on dangerStrong': (light.onFill, light.dangerStrong),
      'brandStrong on surface-100': (light.brandStrong, light.surface100),
      'brandStrong on surface-200': (light.brandStrong, light.surface200),
    };
    for (final MapEntry(key: name, value: (text, background))
        in pairs.entries) {
      test(name, () {
        expect(contrastRatio(text, background), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('RbPalette.of', () {
    Future<(RbPalette, RbPalette)> resolve(
      WidgetTester tester,
      MaterialApp Function(Widget home) app,
    ) async {
      late RbPalette viaOf;
      late RbPalette viaContext;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              viaOf = RbPalette.of(context);
              viaContext = context.rb;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return (viaOf, viaContext);
    }

    testWidgets('falls back to the light palette without the extension', (
      tester,
    ) async {
      final (viaOf, viaContext) = await resolve(
        tester,
        (home) => MaterialApp(home: home),
      );

      expect(viaOf, same(RbPalette.light));
      expect(viaContext, same(RbPalette.light));
    });

    testWidgets('resolves the palette attached to the theme', (tester) async {
      final (viaOf, viaContext) = await resolve(
        tester,
        (home) => MaterialApp(
          theme: ThemeData(extensions: const [RbPalette.dark]),
          home: home,
        ),
      );

      expect(viaOf, same(RbPalette.dark));
      expect(viaContext, same(RbPalette.dark));
    });
  });

  group('RbPalette as a theme extension', () {
    const light = RbPalette.light;
    const dark = RbPalette.dark;

    test('copyWith replaces the given roles and keeps the others', () {
      expect(_fields(light.copyWith()), _fields(light));
      expect(
        _fields(
          light.copyWith(
            brightness: dark.brightness,
            brand: dark.brand,
            onFill: dark.onFill,
            success: dark.success,
            warning: dark.warning,
            danger: dark.danger,
            successStrong: dark.successStrong,
            warningStrong: dark.warningStrong,
            dangerStrong: dark.dangerStrong,
            brandStrong: dark.brandStrong,
            surface100: dark.surface100,
            surface200: dark.surface200,
            ink: dark.ink,
            inkMuted: dark.inkMuted,
            border: dark.border,
          ),
        ),
        _fields(dark),
      );
    });

    test('lerp blends every role and switches brightness at t = 0.5', () {
      expect(_fields(light.lerp(dark, 0)), _fields(light));
      expect(_fields(light.lerp(dark, 1)), _fields(dark));
      expect(light.lerp(dark, 0.49).brightness, Brightness.light);

      final middle = light.lerp(dark, 0.5);
      final from = _colors(light);
      final to = _colors(dark);
      expect(middle.brightness, Brightness.dark);
      expect(_colors(middle), [
        for (var i = 0; i < from.length; i++) Color.lerp(from[i], to[i], 0.5),
      ]);

      expect(light.lerp(null, 0.5), same(light));
    });
  });
}

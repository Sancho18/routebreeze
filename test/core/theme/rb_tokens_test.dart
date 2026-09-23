import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';

void main() {
  group('RbColors', () {
    test('defines the 9 Rota colors', () {
      expect(RbColors.brand, const Color(0xFF2A6DF4));
      expect(RbColors.success, const Color(0xFF12B76A));
      expect(RbColors.warning, const Color(0xFFF59E0B));
      expect(RbColors.danger, const Color(0xFFE5484D));
      expect(RbColors.surface100, const Color(0xFFF7F8FA));
      expect(RbColors.surface200, const Color(0xFFFFFFFF));
      expect(RbColors.ink, const Color(0xFF12141A));
      expect(RbColors.inkMuted, const Color(0xFF5B6472));
      expect(RbColors.border, const Color(0xFFE2E5EA));
    });
  });

  group('RbText', () {
    void expectStyle(
      TextStyle style, {
      required double size,
      required double lineHeight,
      required FontWeight weight,
    }) {
      expect(style.fontSize, size);
      expect(style.height, lineHeight / size);
      expect(style.fontWeight, weight);
      expect(style.fontFamily, isNull);
    }

    test('display 34/40/700', () {
      expectStyle(
        RbText.display,
        size: 34,
        lineHeight: 40,
        weight: FontWeight.w700,
      );
    });

    test('title 22/28/700', () {
      expectStyle(
        RbText.title,
        size: 22,
        lineHeight: 28,
        weight: FontWeight.w700,
      );
    });

    test('heading 17/24/600', () {
      expectStyle(
        RbText.heading,
        size: 17,
        lineHeight: 24,
        weight: FontWeight.w600,
      );
    });

    test('bodyStrong 15/22/600', () {
      expectStyle(
        RbText.bodyStrong,
        size: 15,
        lineHeight: 22,
        weight: FontWeight.w600,
      );
    });

    test('body 15/22/400', () {
      expectStyle(
        RbText.body,
        size: 15,
        lineHeight: 22,
        weight: FontWeight.w400,
      );
    });

    test('caption 13/18/400', () {
      expectStyle(
        RbText.caption,
        size: 13,
        lineHeight: 18,
        weight: FontWeight.w400,
      );
    });
  });

  group('RbSpace', () {
    test('defines the 4 spacing values', () {
      expect(RbSpace.s1, 4);
      expect(RbSpace.s2, 8);
      expect(RbSpace.s3, 16);
      expect(RbSpace.s4, 32);
    });
  });

  group('RbRadius', () {
    test('defines the 3 radii', () {
      expect(RbRadius.sm, 6);
      expect(RbRadius.md, 12);
      expect(RbRadius.lg, 24);
    });
  });
}

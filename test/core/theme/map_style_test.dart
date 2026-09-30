import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/map_style.dart';
import 'package:routebreeze/core/theme/rb_palette.dart';

void main() {
  group('rbDarkMapStyle', () {
    const dark = RbPalette.dark;
    final rules = (jsonDecode(rbDarkMapStyle) as List<Object?>)
        .cast<Map<String, Object?>>();

    /// Color of the single rule for [featureType] (null: every feature) and
    /// [elementType].
    Color colorOf(String? featureType, String elementType) {
      final rule = rules.singleWhere(
        (rule) =>
            rule['featureType'] == featureType &&
            rule['elementType'] == elementType,
      );
      final styler = (rule['stylers']! as List<Object?>).single as Map;
      final hex = styler['color'] as String;
      return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
    }

    test('paints land, roads, water and label text in the dark palette', () {
      final land = colorOf(null, 'geometry');
      final roads = colorOf('road', 'geometry');
      final water = colorOf('water', 'geometry');
      final labelText = colorOf(null, 'labels.text.fill');

      expect(land, const Color(0xFF1A1D23));
      expect(land, dark.surface200);
      expect(roads, const Color(0xFF2F343D));
      expect(roads, dark.border);
      expect(water, const Color(0xFF0F1115));
      expect(water, dark.surface100);
      expect(labelText, const Color(0xFFA4ACB9));
      expect(labelText, dark.inkMuted);
    });

    test('outlines labels in surface-100 and lifts arterials and highways', () {
      expect(colorOf(null, 'labels.text.stroke'), dark.surface100);
      expect(colorOf('road.arterial', 'geometry'), const Color(0xFF3A404B));
      expect(colorOf('road.highway', 'geometry'), const Color(0xFF3A404B));
    });

    test('keeps POI and transit geometry muted, between land and roads', () {
      final land = colorOf(null, 'geometry').computeLuminance();
      final roads = colorOf('road', 'geometry').computeLuminance();

      for (final feature in ['poi', 'transit']) {
        expect(
          colorOf(feature, 'geometry').computeLuminance(),
          inInclusiveRange(land, roads),
          reason: feature,
        );
      }
    });
  });

  group('mapStyleFor', () {
    test('dark mode takes the dark style', () {
      expect(mapStyleFor(Brightness.dark), rbDarkMapStyle);
    });

    test("light mode keeps Google's default style", () {
      expect(mapStyleFor(Brightness.light), isNull);
    });
  });
}

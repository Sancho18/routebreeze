import 'package:flutter/material.dart';

/// Rota design system: the only source of colors, text styles, spacing and
/// radii used by the app.

abstract final class RbColors {
  static const Color brand = Color(0xFF2A6DF4);
  static const Color success = Color(0xFF12B76A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE5484D);
  static const Color surface100 = Color(0xFFF7F8FA);
  static const Color surface200 = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF12141A);
  static const Color inkMuted = Color(0xFF5B6472);
  static const Color border = Color(0xFFE2E5EA);
}

/// Text styles as size / line height / weight. No `fontFamily`: the platform
/// default font is used. Colors are applied by the theme or widgets.
abstract final class RbText {
  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle title = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );
}

abstract final class RbSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 16;
  static const double s4 = 32;
}

abstract final class RbRadius {
  static const double sm = 6;
  static const double md = 12;
  static const double lg = 24;
}

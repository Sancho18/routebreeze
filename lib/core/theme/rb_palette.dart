import 'package:flutter/material.dart';

import 'rb_tokens.dart';

/// Color roles of one theme: the twelve Rota colors plus [onFill]. Widgets
/// read the active palette with `context.rb`.
@immutable
class RbPalette extends ThemeExtension<RbPalette> {
  const RbPalette({
    required this.brightness,
    required this.brand,
    required this.onFill,
    required this.success,
    required this.warning,
    required this.danger,
    required this.successStrong,
    required this.warningStrong,
    required this.dangerStrong,
    required this.surface100,
    required this.surface200,
    required this.ink,
    required this.inkMuted,
    required this.border,
  });

  /// The Rota design system values.
  static const RbPalette light = RbPalette(
    brightness: Brightness.light,
    brand: RbColors.brand,
    onFill: Colors.white,
    success: RbColors.success,
    warning: RbColors.warning,
    danger: RbColors.danger,
    successStrong: Color(0xFF0D7F4A),
    warningStrong: Color(0xFF996206),
    dangerStrong: Color(0xFFD01E23),
    surface100: RbColors.surface100,
    surface200: RbColors.surface200,
    ink: RbColors.ink,
    inkMuted: RbColors.inkMuted,
    border: RbColors.border,
  );

  /// Dark extension of the design system: every text/background pair the app
  /// draws reaches 4.5:1.
  static const RbPalette dark = RbPalette(
    brightness: Brightness.dark,
    brand: Color(0xFF7EA6F8),
    onFill: Color(0xFF0F1115),
    success: Color(0xFF12B76A),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEB7074),
    successStrong: Color(0xFF12B76A),
    warningStrong: Color(0xFFF59E0B),
    dangerStrong: Color(0xFFEB7074),
    surface100: Color(0xFF0F1115),
    surface200: Color(0xFF1A1D23),
    ink: Color(0xFFF2F4F7),
    inkMuted: Color(0xFFA4ACB9),
    border: Color(0xFF2F343D),
  );

  final Brightness brightness;
  final Color brand;

  /// Text and icons drawn on a [brand], [success] or [danger] fill.
  final Color onFill;
  final Color success;
  final Color warning;
  final Color danger;

  /// Darker read of [success], [warning] and [danger]: at least 4.5:1 as
  /// text, or under [onFill] text on a fill, where the base tone would not.
  final Color successStrong;
  final Color warningStrong;
  final Color dangerStrong;
  final Color surface100;
  final Color surface200;
  final Color ink;
  final Color inkMuted;
  final Color border;

  /// The palette of the enclosing theme, or [light] when the theme has none.
  static RbPalette of(BuildContext context) =>
      Theme.of(context).extension<RbPalette>() ?? light;

  @override
  RbPalette copyWith({
    Brightness? brightness,
    Color? brand,
    Color? onFill,
    Color? success,
    Color? warning,
    Color? danger,
    Color? successStrong,
    Color? warningStrong,
    Color? dangerStrong,
    Color? surface100,
    Color? surface200,
    Color? ink,
    Color? inkMuted,
    Color? border,
  }) => RbPalette(
    brightness: brightness ?? this.brightness,
    brand: brand ?? this.brand,
    onFill: onFill ?? this.onFill,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    successStrong: successStrong ?? this.successStrong,
    warningStrong: warningStrong ?? this.warningStrong,
    dangerStrong: dangerStrong ?? this.dangerStrong,
    surface100: surface100 ?? this.surface100,
    surface200: surface200 ?? this.surface200,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    border: border ?? this.border,
  );

  @override
  RbPalette lerp(RbPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return RbPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      brand: mix(brand, other.brand),
      onFill: mix(onFill, other.onFill),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      successStrong: mix(successStrong, other.successStrong),
      warningStrong: mix(warningStrong, other.warningStrong),
      dangerStrong: mix(dangerStrong, other.dangerStrong),
      surface100: mix(surface100, other.surface100),
      surface200: mix(surface200, other.surface200),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      border: mix(border, other.border),
    );
  }
}

/// `context.rb`: the active [RbPalette].
extension RbPaletteContext on BuildContext {
  RbPalette get rb => RbPalette.of(this);
}

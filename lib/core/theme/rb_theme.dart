import 'package:flutter/material.dart';

import 'rb_tokens.dart';

/// Material 3 theme built from the Rota tokens.
ThemeData buildRbTheme() {
  const scheme = ColorScheme.light(
    primary: RbColors.brand,
    onPrimary: Colors.white,
    secondary: RbColors.brand,
    onSecondary: Colors.white,
    error: RbColors.danger,
    onError: Colors.white,
    surface: RbColors.surface200,
    onSurface: RbColors.ink,
    outline: RbColors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RbColors.surface100,
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: RbColors.surface200,
      contentPadding: const EdgeInsets.all(RbSpace.s3),
      border: _outline(RbColors.border),
      enabledBorder: _outline(RbColors.border),
      focusedBorder: _outline(RbColors.brand),
      errorBorder: _outline(RbColors.danger),
      focusedErrorBorder: _outline(RbColors.danger),
      hintStyle: RbText.body.copyWith(color: RbColors.inkMuted),
      errorStyle: RbText.caption.copyWith(color: RbColors.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RbColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: RbColors.border,
        disabledForegroundColor: RbColors.inkMuted,
        minimumSize: const Size.fromHeight(52),
        textStyle: RbText.bodyStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RbRadius.lg),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RbColors.brand,
        textStyle: RbText.bodyStrong,
      ),
    ),
  );

  // Replace (not merge) the text theme: `ThemeData()` merges over
  // `Typography.black`, which would leak a platform `fontFamily` (DS-02).
  return base.copyWith(textTheme: _textTheme);
}

OutlineInputBorder _outline(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(RbRadius.md),
  borderSide: BorderSide(color: color),
);

/// Rota styles mapped onto the Material slots. Primary mapping:
/// display → displaySmall, title → titleLarge, heading → titleMedium,
/// bodyStrong → bodyLarge, body → bodyMedium, caption → bodySmall.
final TextTheme _textTheme = const TextTheme(
  displayLarge: RbText.display,
  displayMedium: RbText.display,
  displaySmall: RbText.display,
  headlineLarge: RbText.title,
  headlineMedium: RbText.title,
  headlineSmall: RbText.title,
  titleLarge: RbText.title,
  titleMedium: RbText.heading,
  titleSmall: RbText.bodyStrong,
  bodyLarge: RbText.bodyStrong,
  bodyMedium: RbText.body,
  bodySmall: RbText.caption,
  labelLarge: RbText.bodyStrong,
  labelMedium: RbText.caption,
  labelSmall: RbText.caption,
).apply(bodyColor: RbColors.ink, displayColor: RbColors.ink);

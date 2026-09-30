import 'package:flutter/material.dart';

import 'rb_palette.dart';
import 'rb_tokens.dart';

/// Material 3 theme from [palette], which it also carries as an extension.
ThemeData buildRbTheme([RbPalette palette = RbPalette.light]) {
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.brand,
    onPrimary: palette.onFill,
    secondary: palette.brand,
    onSecondary: palette.onFill,
    error: palette.danger,
    onError: palette.onFill,
    surface: palette.surface200,
    onSurface: palette.ink,
    outline: palette.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.surface100,
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: palette.surface200,
      contentPadding: const EdgeInsets.all(RbSpace.s3),
      border: _outline(palette.border),
      enabledBorder: _outline(palette.border),
      focusedBorder: _outline(palette.brand),
      errorBorder: _outline(palette.danger),
      focusedErrorBorder: _outline(palette.danger),
      hintStyle: RbText.body.copyWith(color: palette.inkMuted),
      errorStyle: RbText.caption.copyWith(color: palette.dangerStrong),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brand,
        foregroundColor: palette.onFill,
        disabledBackgroundColor: palette.border,
        disabledForegroundColor: palette.inkMuted,
        minimumSize: const Size.fromHeight(52),
        textStyle: RbText.bodyStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RbRadius.lg),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.brandStrong,
        textStyle: RbText.bodyStrong,
      ),
    ),
    extensions: [palette],
  );

  // Replaces the text theme instead of merging it: `ThemeData()` merges over
  // `Typography.black`/`.white`, which would leak a platform `fontFamily`.
  return base.copyWith(
    textTheme: _textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    ),
  );
}

OutlineInputBorder _outline(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(RbRadius.md),
  borderSide: BorderSide(color: color),
);

/// Rota text styles mapped onto the Material slots.
const TextTheme _textTheme = TextTheme(
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
);

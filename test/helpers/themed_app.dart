import 'package:flutter/material.dart';
import 'package:routebreeze/core/theme/rb_palette.dart';
import 'package:routebreeze/core/theme/rb_theme.dart';

/// [home] in a `MaterialApp` with the app themes, shown in [mode].
Widget themedApp(Widget home, {ThemeMode mode = ThemeMode.light}) =>
    MaterialApp(
      theme: buildRbTheme(),
      darkTheme: buildRbTheme(RbPalette.dark),
      themeMode: mode,
      home: home,
    );

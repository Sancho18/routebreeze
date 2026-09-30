import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transparent status and navigation bars whose icons contrast with a theme
/// of [brightness]: dark icons in light mode, light icons in dark mode.
SystemUiOverlayStyle rbSystemBarsFor(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: icons,
    // iOS takes the brightness of the bar background instead of the icons.
    statusBarBrightness: brightness,
  );
}

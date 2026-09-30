import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transparent system bars with icons that contrast with a [brightness] theme.
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

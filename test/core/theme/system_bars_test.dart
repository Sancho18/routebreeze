import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/system_bars.dart';

void main() {
  group('rbSystemBarsFor', () {
    test('light theme: transparent bars with dark icons', () {
      final style = rbSystemBarsFor(Brightness.light);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      // iOS takes the brightness of the bar background: light gets dark icons.
      expect(style.statusBarBrightness, Brightness.light);
    });

    test('dark theme: transparent bars with light icons', () {
      final style = rbSystemBarsFor(Brightness.dark);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
    });
  });
}

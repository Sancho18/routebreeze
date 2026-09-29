import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android asks only for biometrics, location, the location '
      'foreground service and notifications', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final permissions = {
      for (final match in RegExp(
        r'<uses-permission android:name="([^"]+)"',
      ).allMatches(manifest))
        match.group(1),
    };

    expect(permissions, {
      'android.permission.USE_BIOMETRIC',
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_LOCATION',
      'android.permission.POST_NOTIFICATIONS',
    });
  });

  test('iOS describes only the Face ID and location uses', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final descriptions = {
      for (final match in RegExp(
        r'<key>(NS\w*UsageDescription)</key>',
      ).allMatches(plist))
        match.group(1),
    };

    expect(descriptions, {
      'NSFaceIDUsageDescription',
      'NSLocationWhenInUseUsageDescription',
    });
  });
}

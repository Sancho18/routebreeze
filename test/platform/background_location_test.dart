import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android declares the notification plugin\'s foreground service, of '
      'type location and stopped with the task, inside the application', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final application = RegExp(r'<application[\s\S]*</application>')
        .firstMatch(manifest)![0]!;
    final services = [
      for (final match in RegExp(r'<service\b[^>]*>').allMatches(application))
        {
          for (final attribute in RegExp(
            r'android:(\w+)="([^"]*)"',
          ).allMatches(match[0]!))
            attribute[1]!: attribute[2]!,
        },
    ];

    expect(services, [
      {
        'name': 'com.dexterous.flutterlocalnotifications.ForegroundService',
        'exported': 'false',
        'stopWithTask': 'true',
        'foregroundServiceType': 'location',
      },
    ]);
  });

  test('iOS declares the location background mode only', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final modes = RegExp(
      r'<key>UIBackgroundModes</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(plist)?[1];

    expect(modes, isNotNull);
    expect(
      [
        for (final match in RegExp(
          r'<string>([^<]*)</string>',
        ).allMatches(modes!))
          match[1],
      ],
      ['location'],
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Value of `<key>[key]</key><string>…</string>` in the iOS Info.plist.
String? plistString(String key) =>
    RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
        .firstMatch(File('ios/Runner/Info.plist').readAsStringSync())
        ?.group(1);

void main() {
  test('Android shows "RouteBreeze" under the launcher icon', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="RouteBreeze"'),
    );
  });

  test('iOS shows "RouteBreeze" on the home screen', () {
    expect(plistString('CFBundleDisplayName'), 'RouteBreeze');
    expect(plistString('CFBundleName'), 'RouteBreeze');
  });
}

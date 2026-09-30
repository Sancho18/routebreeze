import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'png_header.dart';

const res = 'android/app/src/main/res';
const assets = 'ios/Runner/Assets.xcassets';

const white = [0xFF, 0xFF, 0xFF, 0xFF];
const darkSurface = [0x1A, 0x1D, 0x23, 0xFF];

void main() {
  group('Android before 12', () {
    // At minSdk 24 the APK packages the -v21 folders; the plain folders are
    // what the generator writes next to them. Both are checked.
    const fill =
        '<bitmap android:gravity="fill" android:src="@drawable/background"/>';
    const center =
        '<bitmap android:gravity="center" android:src="@drawable/splash"/>';

    test('light: the icon circle centered on #FFFFFF', () async {
      for (final folder in ['drawable', 'drawable-v21']) {
        final xml = File('$res/$folder/launch_background.xml')
            .readAsStringSync();
        expect(xml, contains(fill), reason: folder);
        expect(xml, contains(center), reason: folder);
        expect(
          await pngPixel('$res/$folder/background.png', 0, 0),
          white,
          reason: folder,
        );
      }
      expect(
        pngHeader('$res/drawable-xxxhdpi/splash.png').width,
        640,
        reason: 'xxxhdpi is the 4x source',
      );
    });

    test('dark: the same icon circle centered on #1A1D23', () async {
      for (final folder in ['drawable-night', 'drawable-night-v21']) {
        final xml = File('$res/$folder/launch_background.xml')
            .readAsStringSync();
        expect(xml, contains(fill), reason: folder);
        expect(xml, contains(center), reason: folder);
        expect(
          await pngPixel('$res/$folder/background.png', 0, 0),
          darkSurface,
          reason: folder,
        );
      }
    });
  });

  group('Android 12+', () {
    String style(String folder) =>
        File('$res/$folder/styles.xml').readAsStringSync();

    test('light: white mark on a #2A6DF4 icon background over #FFFFFF', () {
      final xml = style('values-v31');
      expect(
        xml,
        matches(
          RegExp(
            r'windowSplashScreenBackground">#FFFFFF<',
            caseSensitive: false,
          ),
        ),
      );
      expect(
        xml,
        matches(
          RegExp(
            r'windowSplashScreenIconBackgroundColor">#2A6DF4<',
            caseSensitive: false,
          ),
        ),
      );
      expect(xml, contains('@drawable/android12splash'));
    });

    test('dark: same icon over #1A1D23', () {
      final xml = style('values-night-v31');
      expect(xml, contains('@drawable/android12splash'));
      expect(
        xml,
        matches(
          RegExp(
            r'windowSplashScreenBackground">#1A1D23<',
            caseSensitive: false,
          ),
        ),
      );
      expect(
        xml,
        matches(
          RegExp(
            r'windowSplashScreenIconBackgroundColor">#2A6DF4<',
            caseSensitive: false,
          ),
        ),
      );
    });

    test('the Android 12 icon is the white mark source', () {
      expect(pngHeader('$res/drawable-xxxhdpi/android12splash.png').width, 960);
    });
  });

  group('iOS', () {
    test('the launch screen centers the icon circle over the background '
        'image', () {
      final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
          .readAsStringSync();
      expect(storyboard, contains('image="LaunchImage"'));
      expect(storyboard, contains('image="LaunchBackground"'));
      expect(storyboard, contains('contentMode="center"'));
    });

    test('background is #FFFFFF in light and #1A1D23 in dark mode', () async {
      final contents = jsonDecode(
        File('$assets/LaunchBackground.imageset/Contents.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final images = [
        for (final image in contents['images'] as List)
          image as Map<String, dynamic>,
      ];
      final light = images.firstWhere((i) => i['appearances'] == null);
      final dark = images.firstWhere(
        (i) =>
            (i['appearances'] as List?)?.any(
              (a) => (a as Map)['value'] == 'dark',
            ) ??
            false,
      );
      expect(
        await pngPixel(
          '$assets/LaunchBackground.imageset/${light['filename']}',
          0,
          0,
        ),
        white,
      );
      expect(
        await pngPixel(
          '$assets/LaunchBackground.imageset/${dark['filename']}',
          0,
          0,
        ),
        darkSurface,
      );
    });

    test('the launch image is the icon circle', () {
      expect(
        pngHeader('$assets/LaunchImage.imageset/LaunchImage@3x.png').width,
        480,
        reason: '640 px at 4x shown at 160 pt: 3x = 480 px',
      );
    });
  });
}

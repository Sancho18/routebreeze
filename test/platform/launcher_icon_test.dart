import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'png_header.dart';

const res = 'android/app/src/main/res';
const appIcon = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  group('Android', () {
    test('adaptive icon: brand background, the mark as foreground and a '
        'monochrome layer', () {
      final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml')
          .readAsStringSync();

      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@drawable/ic_launcher_foreground'));
      expect(xml, contains('<monochrome'));
      expect(xml, contains('@drawable/ic_launcher_monochrome'));
      expect(
        File('$res/values/colors.xml').readAsStringSync(),
        matches(
          RegExp(
            r'name="ic_launcher_background">\s*#2A6DF4\s*<',
            caseSensitive: false,
          ),
        ),
      );
    });

    test('foreground and monochrome drawables exist for every density', () {
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        for (final name in [
          'ic_launcher_foreground',
          'ic_launcher_monochrome',
        ]) {
          expect(
            File('$res/drawable-$density/$name.png').existsSync(),
            isTrue,
            reason: '$density/$name',
          );
        }
      }
    });

    test('legacy icons for API 24-25 at 48, 72, 96, 144 and 192 px', () {
      const sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final MapEntry(key: density, value: size) in sizes.entries) {
        final header = pngHeader('$res/mipmap-$density/ic_launcher.png');
        expect([header.width, header.height], [size, size], reason: density);
      }
    });

    test('the legacy icon is the full-bleed brand icon', () async {
      expect(await pngPixel('$res/mipmap-xxxhdpi/ic_launcher.png', 0, 0), [
        0x2A,
        0x6D,
        0xF4,
        0xFF,
      ]);
    });

    test('the manifest points at the launcher icon', () {
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:icon="@mipmap/ic_launcher"'),
      );
    });
  });

  group('iOS', () {
    test('every icon the asset catalog lists exists, at its size, without '
        'an alpha channel', () {
      final contents = jsonDecode(
        File('$appIcon/Contents.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final images = [
        for (final image in contents['images'] as List)
          image as Map<String, dynamic>,
      ];
      expect(images, isNotEmpty);

      for (final image in images) {
        final file = image['filename'] as String;
        final points = double.parse((image['size'] as String).split('x').first);
        final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
        final header = pngHeader('$appIcon/$file');

        expect(header.width, (points * scale).round(), reason: file);
        expect(header.colorType, 2, reason: '$file has alpha');
      }
    });

    test('the 1024 px marketing icon is the brand icon', () async {
      const path = '$appIcon/Icon-App-1024x1024@1x.png';
      final header = pngHeader(path);
      expect([header.width, header.height, header.colorType], [1024, 1024, 2]);
      expect(await pngPixel(path, 0, 0), [0x2A, 0x6D, 0xF4, 0xFF]);
    });
  });
}

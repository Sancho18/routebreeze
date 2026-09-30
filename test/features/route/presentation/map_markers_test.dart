import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';

void main() {
  /// The color of the pixel at ([x], [y]) of a PNG [icon].
  Future<Color> pixelOf(BytesMapBitmap icon, int x, int y) async {
    final codec = await ui.instantiateImageCodec(icon.byteData);
    final image = (await codec.getNextFrame()).image;
    final rgba = (await image.toByteData())!;
    final i = (y * image.width + x) * 4;
    final color = Color.fromARGB(
      rgba.getUint8(i + 3),
      rgba.getUint8(i),
      rgba.getUint8(i + 1),
      rgba.getUint8(i + 2),
    );
    image.dispose();
    codec.dispose();
    return color;
  }

  group('MapMarkers', () {
    test(
      'numbered draws a PNG with non-empty bytes at the pixel ratio',
      () async {
        final markers = MapMarkers();

        final icon = await markers.numbered(3);

        expect(icon, isA<BytesMapBitmap>());
        final bitmap = icon as BytesMapBitmap;
        expect(bitmap.byteData, isNotEmpty);
        expect(bitmap.imagePixelRatio, 3);
        // PNG signature.
        expect(bitmap.byteData.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      },
    );

    test('numbered is cached per number', () async {
      final markers = MapMarkers();

      final first = await markers.numbered(1);
      final again = await markers.numbered(1);
      final other = await markers.numbered(2);

      expect(identical(first, again), isTrue);
      expect(identical(first, other), isFalse);
    });

    test('position draws a smaller PNG dot once', () async {
      final markers = MapMarkers();

      final icon = await markers.position();
      final again = await markers.position();

      expect(icon, isA<BytesMapBitmap>());
      final bitmap = icon as BytesMapBitmap;
      expect(bitmap.byteData.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(bitmap.imagePixelRatio, 3);
      expect(identical(icon, again), isTrue);
      expect(identical(icon, await markers.numbered(1)), isFalse);
    });

    test('numbered paints the light brand #2A6DF4 in any theme: the '
        'center-left pixel, between the white ring and the label', () async {
      final icon = await MapMarkers().numbered(3) as BytesMapBitmap;

      // 108 px at pixel ratio 3: a 6 px white ring, the label centered.
      expect(await pixelOf(icon, 18, 54), const Color(0xFF2A6DF4));
    });

    test('start is a distinct azure default pin', () {
      expect(
        MapMarkers().start().toJson(),
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
            .toJson(),
      );
    });
  });
}

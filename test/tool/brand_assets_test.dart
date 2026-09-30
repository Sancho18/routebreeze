import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/widgets/rb_route_loader.dart';

/// A decoded PNG from `assets/brand/`.
class Png {
  Png(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;

  static Future<Png> load(String name) async {
    final bytes = File('assets/brand/$name').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final png = Png(image.width, image.height, rgba!);
    image.dispose();
    return png;
  }

  List<int> at(Offset p) {
    final i = (p.dy.round() * width + p.dx.round()) * 4;
    return [for (var c = 0; c < 4; c++) rgba.getUint8(i + c)];
  }

  /// Distance from the center of the farthest non-transparent pixel.
  double farthestDrawn() {
    var farthest = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (rgba.getUint8((y * width + x) * 4 + 3) == 0) continue;
        farthest = math.max(
          farthest,
          math.sqrt(
            math.pow(x + 0.5 - width / 2, 2) +
                math.pow(y + 0.5 - height / 2, 2),
          ),
        );
      }
    }
    return farthest;
  }
}

/// A partly covered (anti-aliased) pixel's center can sit up to half a pixel
/// diagonal outside the shape that covers it.
const double edgePixel = math.sqrt2 / 2;

const brand = [0x2A, 0x6D, 0xF4, 0xFF];
const white = [0xFF, 0xFF, 0xFF, 0xFF];
const clear = 0;

/// Point at [t] of the loader curve for a mark drawn at [scale] on a
/// [canvas] px square (spec: box 640 px wide, 0.62 tall, centered, per 1024).
Offset curvePoint(double t, {required double canvas, required double scale}) {
  final k = canvas / 1024 * scale;
  final size = Size(640 * k, 640 * 0.62 * k);
  final metric = RouteLoaderPainter.route(size).computeMetrics().first;
  final topLeft = Offset((canvas - size.width) / 2, (canvas - size.height) / 2);
  return topLeft + metric.getTangentForOffset(metric.length * t)!.position;
}

/// [curvePoint] of the adaptive icon (1024 px, scale 0.62) mapped onto a
/// splash image whose [circle] px circle shows the adaptive icon's visible
/// 72 of 108 dp.
Offset splashPoint(double t, {required double image, required double circle}) {
  const visible = 1024 * 72 / 108;
  final p = curvePoint(t, canvas: 1024, scale: 0.62);
  return (p - const Offset(512, 512)) * (circle / visible) +
      Offset(image / 2, image / 2);
}

void main() {
  test('icon.png: 1024 px, brand background to the corners, white mark along '
      'the loader curve', () async {
    final icon = await Png.load('icon.png');

    expect([icon.width, icon.height], [1024, 1024]);
    expect(icon.at(Offset.zero), brand);
    expect(icon.at(const Offset(1023, 1023)), brand);
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      expect(icon.at(curvePoint(t, canvas: 1024, scale: 1)), white);
    }
    // The ring's hole shows the background.
    expect(icon.at(curvePoint(0, canvas: 1024, scale: 1)), brand);
  });

  test('icon_foreground.png: 1024 px, transparent, white mark at 0.62 inside '
      'the 66 dp safe zone', () async {
    final foreground = await Png.load('icon_foreground.png');

    expect([foreground.width, foreground.height], [1024, 1024]);
    expect(foreground.at(Offset.zero)[3], clear);
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      expect(foreground.at(curvePoint(t, canvas: 1024, scale: 0.62)), white);
    }
    expect(foreground.at(curvePoint(0, canvas: 1024, scale: 0.62))[3], clear);
    expect(
      foreground.farthestDrawn(),
      lessThanOrEqualTo(1024 * 33 / 108 + edgePixel),
    );
  });

  test('icon_monochrome.png is the foreground mark', () {
    expect(
      File('assets/brand/icon_monochrome.png').readAsBytesSync(),
      File('assets/brand/icon_foreground.png').readAsBytesSync(),
    );
  });

  test('splash.png: 640 px brand disc with the white mark, transparent '
      'corners', () async {
    final splash = await Png.load('splash.png');

    expect([splash.width, splash.height], [640, 640]);
    expect(splash.at(Offset.zero)[3], clear);
    expect(splash.at(const Offset(320, 12)), brand);
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      expect(splash.at(splashPoint(t, image: 640, circle: 640)), white);
    }
    expect(splash.farthestDrawn(), lessThanOrEqualTo(320 + edgePixel));
  });

  test('splash_android12.png: 960 px, transparent, white mark inside the '
      '640 px circle', () async {
    final splash = await Png.load('splash_android12.png');

    expect([splash.width, splash.height], [960, 960]);
    expect(splash.at(Offset.zero)[3], clear);
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      expect(splash.at(splashPoint(t, image: 960, circle: 640)), white);
    }
    expect(splash.farthestDrawn(), lessThanOrEqualTo(320 + edgePixel));
  });
}

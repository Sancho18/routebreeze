// Renders the brand source images into assets/brand/. Run it with:
//   flutter test tool/brand/render_brand_assets_test.dart
// then regenerate the platform files (see README, "Ícone e abertura").
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'brand_mark.dart';

const Color brand = Color(0xFF2A6DF4);

/// The part of the 108 dp adaptive layer a launcher shows: 72 dp.
const double visible = BrandMark.canvas * 72 / 108;

Future<void> write(String name, int size, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File('assets/brand/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

/// The adaptive icon's visible circle drawn at [circle] px in the middle of an
/// [image] px canvas, with the brand disc behind the mark when [disc].
void paintAdaptiveCircle(
  Canvas canvas, {
  required double image,
  required double circle,
  required bool disc,
}) {
  canvas
    ..save()
    ..translate(image / 2, image / 2)
    ..scale(circle / visible)
    ..translate(-BrandMark.canvas / 2, -BrandMark.canvas / 2);
  if (disc) {
    canvas.drawCircle(
      const Offset(BrandMark.canvas / 2, BrandMark.canvas / 2),
      visible / 2,
      Paint()..color = brand,
    );
  }
  paintBrandMark(
    canvas,
    const Size.square(BrandMark.canvas),
    color: Colors.white,
    ringFill: disc ? brand : null,
    scale: BrandMark.adaptiveScale,
  );
  canvas.restore();
}

void main() {
  test('render the brand sources', () async {
    const full = Size.square(BrandMark.canvas);
    final size = BrandMark.canvas.toInt();

    await write('icon.png', size, (canvas) {
      canvas.drawRect(Offset.zero & full, Paint()..color = brand);
      paintBrandMark(canvas, full, color: Colors.white, ringFill: brand);
    });
    for (final name in ['icon_foreground.png', 'icon_monochrome.png']) {
      await write(name, size, (canvas) {
        paintBrandMark(
          canvas,
          full,
          color: Colors.white,
          scale: BrandMark.adaptiveScale,
        );
      });
    }
    await write('splash.png', 640, (canvas) {
      paintAdaptiveCircle(canvas, image: 640, circle: 640, disc: true);
    });
    await write('splash_android12.png', 960, (canvas) {
      paintAdaptiveCircle(canvas, image: 960, circle: 640, disc: false);
    });
  });
}

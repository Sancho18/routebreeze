import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/widgets/rb_route_loader.dart';

import '../../tool/brand/brand_mark.dart';

Future<ByteData> render({
  required double size,
  required double scale,
  Color? ringFill,
}) async {
  final recorder = ui.PictureRecorder();
  paintBrandMark(
    Canvas(recorder),
    Size.square(size),
    color: Colors.white,
    ringFill: ringFill,
    scale: scale,
  );
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!;
}

int alphaAt(ByteData data, int width, Offset p) =>
    data.getUint8(((p.dy.round() * width) + p.dx.round()) * 4 + 3);

void main() {
  const canvas = 1024.0;

  test('at the adaptive scale every drawn pixel stays inside the 66 dp safe '
      'zone of the 108 dp layer (312.9 px on 1024 px)', () async {
    final data = await render(size: canvas, scale: 0.62);
    const safeRadius = canvas * 33 / 108;
    var drawn = 0;
    var farthest = 0.0;
    for (var y = 0; y < canvas; y++) {
      for (var x = 0; x < canvas; x++) {
        if (data.getUint8((y * canvas.toInt() + x) * 4 + 3) == 0) continue;
        drawn++;
        final d = math.sqrt(
          math.pow(x + 0.5 - canvas / 2, 2) + math.pow(y + 0.5 - canvas / 2, 2),
        );
        farthest = math.max(farthest, d);
      }
    }

    expect(drawn, greaterThan(20000));
    expect(farthest, lessThanOrEqualTo(safeRadius));
  });

  group('the mark is the loader curve', () {
    const width = 640.0;
    const height = width * 0.62;
    const topLeft = Offset((canvas - width) / 2, (canvas - height) / 2);
    final metric = RouteLoaderPainter.route(const Size(width, height))
        .computeMetrics()
        .first;
    Offset along(double t) =>
        topLeft + metric.getTangentForOffset(metric.length * t)!.position;

    late ByteData data;
    setUpAll(() async => data = await render(size: canvas, scale: 1));

    test('the curve is drawn along its whole length', () {
      for (final t in [0.25, 0.4, 0.5, 0.6, 0.75]) {
        expect(alphaAt(data, canvas.toInt(), along(t)), 255, reason: 't=$t');
      }
    });

    test('the curve is 80 px wide', () {
      // At the peak (half of the length) the curve runs horizontally, so the
      // stroke's 40 px half-width lies straight above and below it.
      final peak = along(0.5);
      for (final dy in [-36.0, 36.0]) {
        expect(
          alphaAt(data, canvas.toInt(), peak + Offset(0, dy)),
          255,
          reason: 'dy=$dy',
        );
      }
      for (final dy in [-44.0, 44.0]) {
        expect(
          alphaAt(data, canvas.toInt(), peak + Offset(0, dy)),
          0,
          reason: 'dy=$dy',
        );
      }
    });

    test('a destination dot of radius 84 sits at the end of the curve', () {
      final end = along(1);
      expect(alphaAt(data, canvas.toInt(), end), 255);
      expect(alphaAt(data, canvas.toInt(), end + const Offset(0, 80)), 255);
      expect(alphaAt(data, canvas.toInt(), end + const Offset(0, 88)), 0);
    });

    test('an origin ring of radius 66 with a hole of radius 30 sits at the '
        'start of the curve', () {
      final start = along(0);
      expect(alphaAt(data, canvas.toInt(), start), 0);
      expect(alphaAt(data, canvas.toInt(), start + const Offset(0, 26)), 0);
      expect(alphaAt(data, canvas.toInt(), start + const Offset(0, 48)), 255);
      expect(alphaAt(data, canvas.toInt(), start + const Offset(0, 70)), 0);
    });

    test('the hole takes the ring fill when one is given', () async {
      final filled = await render(
        size: canvas,
        scale: 1,
        ringFill: const Color(0xFF2A6DF4),
      );
      final i =
          ((along(0).dy.round() * canvas.toInt()) + along(0).dx.round()) * 4;
      expect(
        [
          filled.getUint8(i),
          filled.getUint8(i + 1),
          filled.getUint8(i + 2),
          filled.getUint8(i + 3),
        ],
        [0x2A, 0x6D, 0xF4, 0xFF],
      );
    });

    test('away from the curve the canvas stays empty', () {
      expect(alphaAt(data, canvas.toInt(), const Offset(512, 120)), 0);
      expect(alphaAt(data, canvas.toInt(), const Offset(512, 900)), 0);
    });
  });
}

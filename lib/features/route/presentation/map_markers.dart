import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/rb_tokens.dart';

/// Marker icons for the route map (ROUTE-03): numbered `brand` circles drawn
/// with `dart:ui` and cached per number, plus a distinct start marker.
class MapMarkers {
  MapMarkers();

  /// Circle radius in logical pixels.
  static const double radius = 18;

  final Map<int, BitmapDescriptor> _cache = {};

  /// A `brand` circle with a white ring and the white `bodyStrong` number
  /// [n], rendered at [pixelRatio]. The same instance is returned on every
  /// later call for the same number.
  Future<BitmapDescriptor> numbered(int n, {double pixelRatio = 3}) async {
    final cached = _cache[n];
    if (cached != null) return cached;
    final icon = BitmapDescriptor.bytes(
      await _draw(n, pixelRatio),
      imagePixelRatio: pixelRatio,
    );
    _cache[n] = icon;
    return icon;
  }

  /// The "Partida" marker: an azure default pin, distinct from the numbered
  /// circles.
  BitmapDescriptor start() =>
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  static Future<Uint8List> _draw(int n, double pixelRatio) async {
    final size = radius * 2 * pixelRatio;
    final center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawCircle(center, size / 2, Paint()..color = Colors.white)
      ..drawCircle(
        center,
        size / 2 - 2 * pixelRatio,
        Paint()..color = RbColors.brand,
      );
    final text = TextPainter(
      text: TextSpan(
        text: '$n',
        style: RbText.bodyStrong.copyWith(
          color: Colors.white,
          fontSize: RbText.bodyStrong.fontSize! * pixelRatio,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    final image = await recorder.endRecording().toImage(
      size.ceil(),
      size.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}

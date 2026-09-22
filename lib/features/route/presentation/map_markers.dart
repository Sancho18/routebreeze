import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/rb_tokens.dart';

/// Marker icons for the route map (ROUTE-03): numbered `brand` circles drawn
/// with `dart:ui` and cached per number, a distinct start marker and the
/// current-position dot (NAV-02).
class MapMarkers {
  MapMarkers();

  /// Circle radius in logical pixels.
  static const double radius = 18;

  /// Current-position dot radius in logical pixels.
  static const double positionRadius = 10;

  final Map<int, BitmapDescriptor> _cache = {};
  BitmapDescriptor? _position;

  /// A `brand` circle with a white ring and the white `bodyStrong` number
  /// [n], rendered at [pixelRatio]. The same instance is returned on every
  /// later call for the same number.
  Future<BitmapDescriptor> numbered(int n, {double pixelRatio = 3}) async {
    final cached = _cache[n];
    if (cached != null) return cached;
    final icon = BitmapDescriptor.bytes(
      await _paint(radius, pixelRatio, label: '$n'),
      imagePixelRatio: pixelRatio,
    );
    _cache[n] = icon;
    return icon;
  }

  /// The current-position marker: a smaller `brand` dot with a white ring,
  /// drawn once.
  Future<BitmapDescriptor> position({double pixelRatio = 3}) async =>
      _position ??= BitmapDescriptor.bytes(
        await _paint(positionRadius, pixelRatio),
        imagePixelRatio: pixelRatio,
      );

  /// The "Partida" marker: an azure default pin, distinct from the numbered
  /// circles.
  BitmapDescriptor start() =>
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  static Future<Uint8List> _paint(
    double radius,
    double pixelRatio, {
    String? label,
  }) async {
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
    if (label != null) {
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: RbText.bodyStrong.copyWith(
            color: Colors.white,
            fontSize: RbText.bodyStrong.fontSize! * pixelRatio,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
    final image = await recorder.endRecording().toImage(
      size.ceil(),
      size.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}

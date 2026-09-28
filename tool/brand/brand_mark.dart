import 'dart:ui';

import 'package:routebreeze/core/widgets/rb_route_loader.dart';

/// Sizes of the brand mark on a 1024 px canvas at scale 1.
abstract final class BrandMark {
  static const double canvas = 1024;
  static const double width = 640;

  /// Height of the curve's box as a fraction of [width].
  static const double aspect = 0.62;
  static const double stroke = 80;
  static const double dotRadius = 84;
  static const double ringRadius = 66;
  static const double holeRadius = 30;

  /// Scale of the adaptive icon foreground: the whole mark stays inside the
  /// 66 dp safe zone of the 108 dp layer.
  static const double adaptiveScale = 0.62;
}

/// The map loader's route drawn as the brand mark, centered in [size]: an
/// origin ring at the start of the curve and a destination dot at its end.
/// [BrandMark] sizes are for a 1024 px canvas and follow [size] and [scale].
/// The ring's hole shows [ringFill], or the canvas below when it is null.
void paintBrandMark(
  Canvas canvas,
  Size size, {
  required Color color,
  Color? ringFill,
  double scale = 1,
}) {
  final k = size.shortestSide / BrandMark.canvas * scale;
  final box = Size(BrandMark.width * k, BrandMark.width * BrandMark.aspect * k);
  final path = RouteLoaderPainter.route(box);
  final metric = path.computeMetrics().first;
  final start = metric.getTangentForOffset(0)!.position;
  final end = metric.getTangentForOffset(metric.length)!.position;
  final fill = Paint()..color = color;

  // A layer of its own so a cleared hole never cuts through what is below.
  canvas
    ..saveLayer(Offset.zero & size, Paint())
    ..translate((size.width - box.width) / 2, (size.height - box.height) / 2)
    ..drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = BrandMark.stroke * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    )
    ..drawCircle(end, BrandMark.dotRadius * k, fill)
    ..drawCircle(start, BrandMark.ringRadius * k, fill)
    ..drawCircle(
      start,
      BrandMark.holeRadius * k,
      ringFill == null
          ? (Paint()..blendMode = BlendMode.clear)
          : (Paint()..color = ringFill),
    )
    ..restore();
}

import 'package:flutter/material.dart';

import '../theme/rb_tokens.dart';

/// Looping "route being drawn" indicator: a faint track in `border`, the
/// travelled stretch in `brand` and a dot at its head. The head runs the
/// whole path first, then the tail catches up, so the loop has no jump.
class RbRouteLoader extends StatefulWidget {
  const RbRouteLoader({
    super.key,
    this.width = 120,
    this.period = const Duration(milliseconds: 1800),
    this.semanticsLabel = 'Carregando',
  });

  final double width;
  final Duration period;
  final String semanticsLabel;

  /// Height as a fraction of [width].
  static const double aspect = 0.4;

  @override
  State<RbRouteLoader> createState() => _RbRouteLoaderState();
}

class _RbRouteLoaderState extends State<RbRouteLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox(
        width: widget.width,
        height: widget.width * RbRouteLoader.aspect,
        child: CustomPaint(
          painter: RouteLoaderPainter(
            progress: _controller,
            track: RbColors.border,
            stroke: RbColors.brand,
          ),
        ),
      ),
    );
  }
}

/// Paints an S-shaped route across the box and the stretch between
/// [segmentFor]'s tail and head for the current [progress].
class RouteLoaderPainter extends CustomPainter {
  RouteLoaderPainter({
    required this.progress,
    required this.track,
    required this.stroke,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color track;
  final Color stroke;

  static const double strokeWidth = 4;
  static const double dotRadius = 5;

  /// Fractions of the path length that are drawn at cycle position [t]
  /// (0..1): the head travels during the first half, the tail during the
  /// second, both eased.
  static ({double tail, double head}) segmentFor(double t) {
    if (t < 0.5) {
      return (tail: 0, head: Curves.easeInOut.transform(t * 2));
    }
    return (tail: Curves.easeInOut.transform((t - 0.5) * 2), head: 1);
  }

  /// The route, inset so the head dot and the stroke stay inside [size].
  static Path route(Size size) {
    final inset = dotRadius + 1;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    Offset p(double x, double y) => Offset(inset + w * x, inset + h * y);
    return Path()
      ..moveTo(p(0, 0.8).dx, p(0, 0.8).dy)
      ..cubicTo(
        p(0.28, 0.8).dx,
        p(0.28, 0.8).dy,
        p(0.22, 0.2).dx,
        p(0.22, 0.2).dy,
        p(0.5, 0.2).dx,
        p(0.5, 0.2).dy,
      )
      ..cubicTo(
        p(0.78, 0.2).dx,
        p(0.78, 0.2).dy,
        p(0.72, 0.8).dx,
        p(0.72, 0.8).dy,
        p(1, 0.8).dx,
        p(1, 0.8).dy,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = route(size);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, line..color = track);

    final metric = path.computeMetrics().first;
    final segment = segmentFor(progress.value);
    final tail = metric.length * segment.tail;
    final head = metric.length * segment.head;
    if (head > tail) {
      canvas.drawPath(metric.extractPath(tail, head), line..color = stroke);
    }
    final headPoint = metric.getTangentForOffset(head)!.position;
    canvas.drawCircle(headPoint, dotRadius, Paint()..color = stroke);
  }

  @override
  bool shouldRepaint(RouteLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.stroke != stroke;
}

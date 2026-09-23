import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_route_loader.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  RouteLoaderPainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!
          as RouteLoaderPainter;

  group('RbRouteLoader', () {
    testWidgets('is 120 x 48 by default, brand on a border track, with the '
        '"Carregando" semantics label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const RbRouteLoader()));

      expect(tester.getSize(find.byType(RbRouteLoader)), const Size(120, 48));
      final painter = painterOf(tester);
      expect(painter.stroke, RbColors.brand);
      expect(painter.track, RbColors.border);
      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('width scales the height and semanticsLabel is applied', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const RbRouteLoader(width: 200, semanticsLabel: 'Calculando')),
      );

      expect(tester.getSize(find.byType(RbRouteLoader)), const Size(200, 80));
      expect(find.bySemanticsLabel('Calculando'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('loops: progress advances with time and wraps after the '
        'period', (tester) async {
      await tester.pumpWidget(
        wrap(const RbRouteLoader(period: Duration(milliseconds: 1000))),
      );
      final painter = painterOf(tester);
      expect(painter.progress.value, 0);

      await tester.pump(const Duration(milliseconds: 250));
      expect(painter.progress.value, closeTo(0.25, 0.01));

      await tester.pump(const Duration(milliseconds: 500));
      expect(painter.progress.value, closeTo(0.75, 0.01));

      await tester.pump(const Duration(milliseconds: 400));
      expect(painter.progress.value, closeTo(0.15, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('stops the ticker when removed from the tree', (tester) async {
      await tester.pumpWidget(wrap(const RbRouteLoader()));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RbRouteLoader), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('RouteLoaderPainter', () {
    test('segmentFor: the head travels in the first half, the tail in the '
        'second, both eased', () {
      expect(RouteLoaderPainter.segmentFor(0), (tail: 0.0, head: 0.0));
      final quarter = RouteLoaderPainter.segmentFor(0.25);
      expect(quarter.tail, 0);
      expect(quarter.head, closeTo(0.5, 0.001));
      expect(RouteLoaderPainter.segmentFor(0.5), (tail: 0.0, head: 1.0));
      final threeQuarters = RouteLoaderPainter.segmentFor(0.75);
      expect(threeQuarters.tail, closeTo(0.5, 0.001));
      expect(threeQuarters.head, 1);
      expect(RouteLoaderPainter.segmentFor(1), (tail: 1.0, head: 1.0));
      // Eased: slower near the ends than in the middle.
      expect(RouteLoaderPainter.segmentFor(0.05).head, lessThan(0.1));
    });

    test('route stays inside the box with room for the head dot', () {
      const size = Size(120, 48);
      final bounds = RouteLoaderPainter.route(size).getBounds();
      const inset = RouteLoaderPainter.dotRadius + 1;
      expect(bounds.left, greaterThanOrEqualTo(inset));
      expect(bounds.top, greaterThanOrEqualTo(inset));
      expect(bounds.right, lessThanOrEqualTo(size.width - inset));
      expect(bounds.bottom, lessThanOrEqualTo(size.height - inset));
      expect(bounds.width, greaterThan(size.width * 0.8));
    });

    test('shouldRepaint only when the animation or colors change', () {
      final a = AlwaysStoppedAnimation<double>(0.2);
      final b = AlwaysStoppedAnimation<double>(0.2);
      final painter = RouteLoaderPainter(
        progress: a,
        track: RbColors.border,
        stroke: RbColors.brand,
      );
      expect(
        painter.shouldRepaint(
          RouteLoaderPainter(
            progress: a,
            track: RbColors.border,
            stroke: RbColors.brand,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          RouteLoaderPainter(
            progress: b,
            track: RbColors.border,
            stroke: RbColors.brand,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          RouteLoaderPainter(
            progress: a,
            track: RbColors.border,
            stroke: RbColors.danger,
          ),
        ),
        isTrue,
      );
    });

    test('paints the track, the travelled stretch and the head dot', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      RouteLoaderPainter(
        progress: const AlwaysStoppedAnimation<double>(0.25),
        track: RbColors.border,
        stroke: RbColors.brand,
      ).paint(canvas, const Size(120, 48));
      RouteLoaderPainter(
        progress: const AlwaysStoppedAnimation<double>(0),
        track: RbColors.border,
        stroke: RbColors.brand,
      ).paint(canvas, const Size(120, 48));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });
  });
}

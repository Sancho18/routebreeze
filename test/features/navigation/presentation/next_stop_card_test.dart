import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/presentation/next_stop_card.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/presentation/stop_badge.dart';

void main() {
  const stop = RouteStop(
    stop: Stop(
      'pa',
      'Rua Augusta, 500 - Consolação, São Paulo',
      GeoPoint(-23.553, -46.653),
    ),
    order: 2,
    visited: false,
  );
  final progress = RouteProgress(
    next: stop,
    toNextMeters: 1234,
    toNextSeconds: 250,
    remainingMeters: 8400,
    remainingSeconds: 1320,
    at: DateTime.utc(2026, 9, 28, 14, 28),
  );

  Future<void> pumpCard(WidgetTester tester, {RouteProgress? progress}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(RbSpace.s3),
              child: NextStopCard(stop: stop, progress: progress),
            ),
          ),
        ),
      );

  Text text(WidgetTester tester, String value) =>
      tester.widget<Text>(find.text(value));

  group('NextStopCard', () {
    testWidgets('address card per the DS: surface-200, 1 px border, radius-md '
        'and space-3 padding, as wide as its slot', (tester) async {
      await pumpCard(tester, progress: progress);

      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(NextStopCard.label),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.surface200);
      expect(decoration.borderRadius, BorderRadius.circular(RbRadius.md));
      expect(decoration.border, Border.all(color: RbColors.border));
      expect(card.padding, const EdgeInsets.all(RbSpace.s3));
      expect(
        tester.getSize(find.byType(NextStopCard)).width,
        800 - RbSpace.s3 * 2,
      );
    });

    testWidgets('"Próxima parada" in caption/ink-muted over the stop number '
        'on its brand badge and the address in body-strong/ink', (
      tester,
    ) async {
      await pumpCard(tester, progress: progress);

      final label = text(tester, 'Próxima parada');
      expect(label.style!.fontSize, 13);
      expect(label.style!.color, RbColors.inkMuted);

      final badge = tester.widget<StopBadge>(find.byType(StopBadge));
      expect(badge.order, 2);
      expect(badge.visited, isFalse);

      final address = text(tester, 'Rua Augusta, 500 - Consolação, São Paulo');
      expect(address.style!.fontSize, 15);
      expect(address.style!.fontWeight, FontWeight.w600);
      expect(address.style!.color, RbColors.ink);
      expect(address.maxLines, 2);
      expect(address.overflow, TextOverflow.ellipsis);

      expect(
        tester.getTopLeft(find.byType(StopBadge)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Próxima parada')).dy + RbSpace.s2,
        ),
      );
    });

    testWidgets('with progress: distance, time and arrival clock in '
        'caption/ink-muted under the address, aligned with it', (tester) async {
      await pumpCard(tester, progress: progress);

      const summary = '1,2 km · 4 min · chegada às 14:32';
      final details = text(tester, summary);
      expect(details.style!.fontSize, 13);
      expect(details.style!.color, RbColors.inkMuted);
      final address = find.text('Rua Augusta, 500 - Consolação, São Paulo');
      expect(
        tester.getTopLeft(find.text(summary)).dx,
        tester.getTopLeft(address).dx,
      );
      expect(
        tester.getTopLeft(find.text(summary)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(address).dy + RbSpace.s2),
      );
    });

    testWidgets('without progress: the stop only, no details line', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.text('Rua Augusta, 500 - Consolação, São Paulo'), findsOne);
      expect(find.textContaining('chegada às'), findsNothing);
    });

    test('summary: meters under 1 km, "< 1 min" and a zero-padded clock', () {
      final close = RouteProgress(
        next: stop,
        toNextMeters: 45,
        toNextSeconds: 12,
        remainingMeters: 45,
        remainingSeconds: 12,
        at: DateTime.utc(2026, 9, 28, 9, 4, 50),
      );

      expect(NextStopCard.summary(close), '45 m · < 1 min · chegada às 09:05');
    });
  });
}

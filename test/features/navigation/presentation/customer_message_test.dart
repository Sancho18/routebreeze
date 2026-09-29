import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/presentation/customer_message.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';

void main() {
  const next = RouteStop(
    stop: Stop('pa', 'Rua Augusta, 500', GeoPoint(-23.55, -46.65)),
    order: 2,
  );

  /// Progress measured at [at], [toNextSeconds] away from [next].
  RouteProgress measuredAt(DateTime at, {int toNextSeconds = 240}) =>
      RouteProgress(
        next: next,
        toNextMeters: 1200,
        toNextSeconds: toNextSeconds,
        remainingMeters: 5000,
        remainingSeconds: 900,
        at: at,
      );

  group('customerMessage', () {
    test(
      'with a measured progress it gives the next stop\'s arrival clock',
      () {
        expect(
          customerMessage(
            progress: measuredAt(DateTime(2026, 9, 22, 14, 28)),
            arrived: false,
          ),
          'Olá! Sua entrega chega por volta das 14:32.',
        );
      },
    );

    test('an arrival past midnight reads as the clock gives it', () {
      expect(
        customerMessage(
          progress: measuredAt(
            DateTime(2026, 9, 22, 23, 58),
            toNextSeconds: 720,
          ),
          arrived: false,
        ),
        'Olá! Sua entrega chega por volta das 00:10.',
      );
    });

    test('without a measured progress the delivery is on its way', () {
      expect(
        customerMessage(progress: null, arrived: false),
        'Olá! Sua entrega está a caminho.',
      );
    });

    test('once the driver arrived it says so, measured or not', () {
      expect(
        customerMessage(
          progress: measuredAt(DateTime(2026, 9, 22, 14, 28)),
          arrived: true,
        ),
        'Olá! Cheguei com a sua entrega.',
      );
      expect(
        customerMessage(progress: null, arrived: true),
        'Olá! Cheguei com a sua entrega.',
      );
    });
  });
}

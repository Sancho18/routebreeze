import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/route_summary.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  const a = Stop('pa', 'Rua A, 1', GeoPoint(-23.56, -46.65));
  const b = Stop('pb', 'Rua B, 2', GeoPoint(-23.57, -46.66));
  const c = Stop('pc', 'Rua C, 3', GeoPoint(-23.58, -46.67));
  const d = Stop('pd', 'Rua D, 4', GeoPoint(-23.59, -46.68));
  final start = DateTime.utc(2026, 9, 28, 16, 40);
  final end = DateTime.utc(2026, 9, 28, 17, 45);
  StopResult deliveredAt(int minute) =>
      StopResult.delivered(at: DateTime.utc(2026, 9, 28, 17, minute));
  StopResult failedAt(FailureReason reason, int minute) =>
      StopResult.failed(reason, at: DateTime.utc(2026, 9, 28, 17, minute));

  /// The stops numbered 1..N in the given order, without results.
  RoutePlan planOf(List<Stop> stops) => RoutePlan(
    origin: origin,
    stops: [
      for (var i = 0; i < stops.length; i++)
        RouteStop(stop: stops[i], order: i + 1),
    ],
    polyline: const [origin],
    distanceMeters: 12345,
    durationSeconds: 605,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 28, 16, 30),
  );

  group('RouteSummary counts', () {
    test('3 delivered and 1 not delivered: the failed list holds only the '
        'not-delivered stop with its reason', () {
      final summary = RouteSummary.of(
        planOf(const [a, b, c, d])
            .withStart(start)
            .record('pa', deliveredAt(0))
            .record('pb', failedAt(FailureReason.refused, 10))
            .record('pc', deliveredAt(30))
            .record('pd', deliveredAt(45)),
        traveledMeters: 12430,
        end: end,
      );

      expect(summary.delivered, 3);
      expect(summary.failed, [
        RouteStop(
          stop: b,
          order: 2,
          result: failedAt(FailureReason.refused, 10),
        ),
      ]);
    });

    test('every stop delivered: 1 delivered and no failed stops', () {
      final summary = RouteSummary.of(
        planOf(const [a]).withStart(start).record('pa', deliveredAt(0)),
        traveledMeters: 850,
        end: DateTime.utc(2026, 9, 28, 16, 58),
      );

      expect(summary.delivered, 1);
      expect(summary.failed, isEmpty);
    });

    test('0 delivered and 2 not delivered, listed in stop order with their '
        'reasons even when recorded in another order', () {
      final summary = RouteSummary.of(
        planOf(const [a, b])
            .withStart(start)
            .record('pb', failedAt(FailureReason.addressNotFound, 0))
            .record('pa', failedAt(FailureReason.recipientAbsent, 10)),
        traveledMeters: 3200,
        end: DateTime.utc(2026, 9, 28, 17, 10),
      );

      expect(summary.delivered, 0);
      expect(summary.failed, [
        RouteStop(
          stop: a,
          order: 1,
          result: failedAt(FailureReason.recipientAbsent, 10),
        ),
        RouteStop(
          stop: b,
          order: 2,
          result: failedAt(FailureReason.addressNotFound, 0),
        ),
      ]);
    });

    test('stops visited in a route saved before results count as '
        'delivered', () {
      final legacy = RoutePlan.fromJson({
        ...planOf(const [a, b]).toJson(),
        'stops': [
          {'stop': a.toJson(), 'order': 1, 'visited': true},
          {'stop': b.toJson(), 'order': 2, 'visited': true},
        ],
      });

      final summary = RouteSummary.of(legacy, traveledMeters: 0, end: end);

      expect(summary.delivered, 2);
      expect(summary.failed, isEmpty);
    });
  });

  group('RouteSummary distance and time', () {
    test('keeps the meters traveled, the start of the route and the end; the '
        'duration runs from the start to the end: 1 h 05 min', () {
      final summary = RouteSummary.of(
        planOf(const [a])
            .withStart(start)
            .withTraveled(12000)
            .record('pa', deliveredAt(45)),
        traveledMeters: 12430,
        end: end,
      );

      expect(summary.traveledMeters, 12430);
      expect(summary.start, DateTime.utc(2026, 9, 28, 16, 40));
      expect(summary.end, DateTime.utc(2026, 9, 28, 17, 45));
      expect(summary.duration, const Duration(hours: 1, minutes: 5));
    });

    test('without a start there is no duration; the distance and the end '
        'stay', () {
      final summary = RouteSummary.of(
        planOf(const [a]).record('pa', deliveredAt(45)),
        traveledMeters: 12430,
        end: end,
      );

      expect(summary.start, isNull);
      expect(summary.duration, isNull);
      expect(summary.traveledMeters, 12430);
      expect(summary.end, DateTime.utc(2026, 9, 28, 17, 45));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';

void main() {
  final at = DateTime.utc(2026, 9, 28, 17, 5);

  group('StopResult', () {
    test('delivered at a clock time is delivered, without a reason', () {
      final result = StopResult.delivered(at: at);

      expect(result.outcome, DeliveryOutcome.delivered);
      expect(result.delivered, isTrue);
      expect(result.reason, isNull);
      expect(result.at, at);
    });

    test('not delivered keeps its reason and clock time', () {
      final result = StopResult.failed(FailureReason.refused, at: at);

      expect(result.outcome, DeliveryOutcome.failed);
      expect(result.delivered, isFalse);
      expect(result.reason, FailureReason.refused);
      expect(result.at, at);
    });
  });

  group('StopResult JSON', () {
    test('delivered round-trips with its outcome and time in UTC ISO', () {
      final result = StopResult.delivered(at: at);

      expect(result.toJson(), {
        'outcome': 'delivered',
        'at': '2026-09-28T17:05:00.000Z',
      });
      expect(StopResult.fromJson(result.toJson()), result);
    });

    test('not delivered round-trips with its outcome, reason and time in '
        'UTC ISO', () {
      final result = StopResult.failed(FailureReason.refused, at: at);

      expect(result.toJson(), {
        'outcome': 'failed',
        'reason': 'refused',
        'at': '2026-09-28T17:05:00.000Z',
      });
      expect(StopResult.fromJson(result.toJson()), result);
    });

    test('each reason is written by name and read back', () {
      const names = {
        FailureReason.recipientAbsent: 'recipientAbsent',
        FailureReason.addressNotFound: 'addressNotFound',
        FailureReason.refused: 'refused',
        FailureReason.other: 'other',
      };
      expect(names.keys, FailureReason.values);

      for (final MapEntry(key: reason, value: name) in names.entries) {
        final result = StopResult.failed(reason, at: at);

        expect(result.toJson()['reason'], name);
        expect(StopResult.fromJson(result.toJson()).reason, reason);
      }
    });

    test('a local clock time is written in UTC', () {
      final local = StopResult.delivered(at: at.toLocal());

      expect(local.toJson()['at'], '2026-09-28T17:05:00.000Z');
      expect(StopResult.fromJson(local.toJson()).at, at);
    });

    test('a result without a time omits the key and reads back without '
        'one', () {
      const delivered = StopResult.delivered();
      const failed = StopResult.failed(FailureReason.other);

      expect(delivered.toJson(), {'outcome': 'delivered'});
      expect(failed.toJson(), {'outcome': 'failed', 'reason': 'other'});
      expect(StopResult.fromJson(delivered.toJson()), delivered);
      expect(StopResult.fromJson(delivered.toJson()).at, isNull);
      expect(StopResult.fromJson(failed.toJson()), failed);
      expect(StopResult.fromJson(failed.toJson()).at, isNull);
    });
  });
}

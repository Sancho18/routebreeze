import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/lock/domain/relock_policy.dart';

void main() {
  const policy = RelockPolicy();

  group('RelockPolicy.shouldRelock', () {
    test('29 s in background does not re-lock', () {
      expect(
        policy.shouldRelock(
          inBackground: const Duration(seconds: 29),
          navigationActive: false,
        ),
        isFalse,
      );
    });

    test('30 s in background re-locks', () {
      expect(
        policy.shouldRelock(
          inBackground: const Duration(seconds: 30),
          navigationActive: false,
        ),
        isTrue,
      );
    });

    test('31 s in background re-locks', () {
      expect(
        policy.shouldRelock(
          inBackground: const Duration(seconds: 31),
          navigationActive: false,
        ),
        isTrue,
      );
    });

    test('5 min in background with an active navigation does not re-lock', () {
      expect(
        policy.shouldRelock(
          inBackground: const Duration(minutes: 5),
          navigationActive: true,
        ),
        isFalse,
      );
    });
  });
}

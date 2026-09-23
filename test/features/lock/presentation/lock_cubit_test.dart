import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/lock/presentation/lock_cubit.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

void main() {
  late MockLocalAuthService auth;

  setUp(() {
    auth = MockLocalAuthService();
  });

  test('starts locked', () {
    expect(LockCubit(auth).state, const LockState(status: LockStatus.locked));
  });

  blocTest<LockCubit, LockState>(
    'unlock: authenticating then unlocked on success',
    build: () {
      when(() => auth.authenticate())
          .thenAnswer((_) async => AuthResult.success);
      return LockCubit(auth);
    },
    act: (cubit) => cubit.unlock(),
    expect: () => const [
      LockState(status: LockStatus.authenticating),
      LockState(status: LockStatus.unlocked),
    ],
  );

  for (final reason in AuthResult.values.where(
    (r) => r != AuthResult.success,
  )) {
    blocTest<LockCubit, LockState>(
      'unlock: authenticating then failed(${reason.name})',
      build: () {
        when(() => auth.authenticate()).thenAnswer((_) async => reason);
        return LockCubit(auth);
      },
      act: (cubit) => cubit.unlock(),
      expect: () => [
        const LockState(status: LockStatus.authenticating),
        LockState(status: LockStatus.failed, reason: reason),
      ],
    );
  }

  late Completer<AuthResult> pending;

  blocTest<LockCubit, LockState>(
    'a second unlock while authenticating is ignored: one prompt, '
    'authenticating then unlocked',
    build: () {
      pending = Completer<AuthResult>();
      when(() => auth.authenticate()).thenAnswer((_) => pending.future);
      return LockCubit(auth);
    },
    act: (cubit) {
      final first = cubit.unlock();
      final second = cubit.unlock();
      pending.complete(AuthResult.success);
      return Future.wait([first, second]);
    },
    expect: () => const [
      LockState(status: LockStatus.authenticating),
      LockState(status: LockStatus.unlocked),
    ],
    verify: (_) => verify(() => auth.authenticate()).called(1),
  );

  blocTest<LockCubit, LockState>(
    'lock after unlocked returns to locked without a reason',
    build: () => LockCubit(auth),
    seed: () => const LockState(status: LockStatus.unlocked),
    act: (cubit) => cubit.lock(),
    expect: () => const [LockState(status: LockStatus.locked)],
  );
}

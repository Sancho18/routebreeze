import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_auth_service.dart';
import '../domain/auth_result.dart';

enum LockStatus { locked, authenticating, unlocked, failed }

class LockState extends Equatable {
  const LockState({this.status = LockStatus.locked, this.reason});

  final LockStatus status;

  /// Why the last attempt failed; set only when [status] is `failed`.
  final AuthResult? reason;

  @override
  List<Object?> get props => [status, reason];
}

/// Drives the Lock screen: starts locked, `unlock()` prompts the device
/// authentication, `lock()` returns to locked (LOCK-01, LOCK-02, LOCK-04..06).
class LockCubit extends Cubit<LockState> {
  LockCubit(this._auth) : super(const LockState());

  final LocalAuthService _auth;

  Future<void> unlock() async {
    emit(const LockState(status: LockStatus.authenticating));
    final result = await _auth.authenticate();
    if (isClosed) return;
    emit(
      result == AuthResult.success
          ? const LockState(status: LockStatus.unlocked)
          : LockState(status: LockStatus.failed, reason: result),
    );
  }

  void lock() => emit(const LockState());
}

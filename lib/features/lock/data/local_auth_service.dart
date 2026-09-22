import 'package:local_auth/local_auth.dart';

import '../domain/auth_result.dart';

abstract class LocalAuthService {
  Future<AuthResult> authenticate();
}

/// Device authentication with biometrics and device-credential fallback.
class LocalAuthServiceImpl implements LocalAuthService {
  LocalAuthServiceImpl(this._auth);

  final LocalAuthentication _auth;

  static const String localizedReason = 'Desbloqueie para acessar suas rotas';

  @override
  Future<AuthResult> authenticate() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
      );
      return ok ? AuthResult.success : AuthResult.canceled;
    } on LocalAuthException catch (e) {
      return _map(e.code);
    } on Object {
      // Plugin or platform errors (missing activity, plugin not attached).
      return AuthResult.error;
    }
  }

  // SPEC_DEVIATION: design.md folds noBiometricHardware/noBiometricsEnrolled
  // into noCredentials. They are mapped to `unavailable` instead.
  // Reason: with biometricOnly=false a missing credential surfaces as
  // noCredentialsSet; these codes mean the platform could not authenticate at
  // all, and "configure a screen lock" would mislead a user who has one.
  static AuthResult _map(LocalAuthExceptionCode code) => switch (code) {
    // authInProgress: another prompt is already open and will answer; this
    // attempt is a no-op, not a failure.
    LocalAuthExceptionCode.userCanceled ||
    LocalAuthExceptionCode.systemCanceled ||
    LocalAuthExceptionCode.timeout ||
    LocalAuthExceptionCode.userRequestedFallback ||
    LocalAuthExceptionCode.authInProgress => AuthResult.canceled,
    LocalAuthExceptionCode.temporaryLockout ||
    LocalAuthExceptionCode.biometricLockout => AuthResult.lockedOut,
    LocalAuthExceptionCode.noCredentialsSet => AuthResult.noCredentials,
    LocalAuthExceptionCode.noBiometricHardware ||
    LocalAuthExceptionCode.noBiometricsEnrolled ||
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
    LocalAuthExceptionCode.uiUnavailable => AuthResult.unavailable,
    _ => AuthResult.error,
  };
}

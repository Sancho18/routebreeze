import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late MockLocalAuthentication auth;
  late LocalAuthService service;

  setUp(() {
    auth = MockLocalAuthentication();
    service = LocalAuthServiceImpl(auth);
  });

  void stubAuthenticate(Object outcome) {
    final stub = when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
      ),
    );
    if (outcome is bool) {
      stub.thenAnswer((_) async => outcome);
    } else {
      stub.thenThrow(outcome);
    }
  }

  group('LocalAuthServiceImpl.authenticate', () {
    test('prompts with the pt-BR reason and device-credential fallback, '
        'and maps true to success', () async {
      stubAuthenticate(true);

      expect(await service.authenticate(), AuthResult.success);
      verify(
        () => auth.authenticate(
          localizedReason: 'Desbloqueie para acessar suas rotas',
          biometricOnly: false,
        ),
      ).called(1);
    });

    test('maps false to canceled', () async {
      stubAuthenticate(false);
      expect(await service.authenticate(), AuthResult.canceled);
    });

    const mapped = <LocalAuthExceptionCode, AuthResult>{
      LocalAuthExceptionCode.userCanceled: AuthResult.canceled,
      LocalAuthExceptionCode.systemCanceled: AuthResult.canceled,
      LocalAuthExceptionCode.timeout: AuthResult.canceled,
      LocalAuthExceptionCode.userRequestedFallback: AuthResult.canceled,
      LocalAuthExceptionCode.temporaryLockout: AuthResult.lockedOut,
      LocalAuthExceptionCode.biometricLockout: AuthResult.lockedOut,
      LocalAuthExceptionCode.noCredentialsSet: AuthResult.noCredentials,
      LocalAuthExceptionCode.noBiometricHardware: AuthResult.unavailable,
      LocalAuthExceptionCode.noBiometricsEnrolled: AuthResult.unavailable,
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          AuthResult.unavailable,
      LocalAuthExceptionCode.uiUnavailable: AuthResult.unavailable,
      LocalAuthExceptionCode.authInProgress: AuthResult.error,
      LocalAuthExceptionCode.deviceError: AuthResult.error,
      LocalAuthExceptionCode.unknownError: AuthResult.error,
    };

    for (final entry in mapped.entries) {
      test('maps ${entry.key.name} to ${entry.value.name}', () async {
        stubAuthenticate(LocalAuthException(code: entry.key));
        expect(await service.authenticate(), entry.value);
      });
    }
  });
}

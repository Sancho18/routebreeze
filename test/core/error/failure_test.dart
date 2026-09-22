import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/error/failure.dart';

void main() {
  group('Failure.userMessage', () {
    test('NoConnection', () {
      expect(const NoConnection().userMessage, 'Sem conexão');
    });

    test('TimeoutFailure', () {
      expect(
        const TimeoutFailure().userMessage,
        'A conexão demorou demais. Tente novamente.',
      );
    });

    test('ApiFailure', () {
      expect(
        const ApiFailure(500, 'boom').userMessage,
        'Não foi possível completar a solicitação. Tente novamente.',
      );
    });

    test('PermissionDenied', () {
      expect(
        const PermissionDenied().userMessage,
        'Precisamos da sua localização para seguir. '
        'Ela define o ponto de partida da sua rota.',
      );
    });

    test('PermissionDeniedForever', () {
      expect(
        const PermissionDeniedForever().userMessage,
        'Precisamos da sua localização para seguir. '
        'Ela define o ponto de partida da sua rota. '
        'Você negou o acesso. Ative em Configurações.',
      );
    });

    test('ServiceDisabled', () {
      expect(
        const ServiceDisabled().userMessage,
        'Ative a localização do dispositivo para continuar.',
      );
    });

    test('Unknown', () {
      expect(
        const Unknown('cause').userMessage,
        'Algo deu errado. Tente novamente.',
      );
    });
  });
}

import 'package:equatable/equatable.dart';

/// One error vocabulary from the data layer to the UI.
///
/// Every variant carries the pt-BR copy the screens show (`userMessage`).
sealed class Failure extends Equatable {
  const Failure();

  String get userMessage;

  @override
  List<Object?> get props => const [];
}

final class NoConnection extends Failure {
  const NoConnection();

  @override
  String get userMessage => 'Sem conexão';
}

final class Timeout extends Failure {
  const Timeout();

  @override
  String get userMessage => 'A conexão demorou demais. Tente novamente.';
}

final class ApiFailure extends Failure {
  const ApiFailure(this.status, this.message);

  final int? status;
  final String message;

  @override
  String get userMessage =>
      'Não foi possível completar a solicitação. Tente novamente.';

  @override
  List<Object?> get props => [status, message];
}

final class PermissionDenied extends Failure {
  const PermissionDenied();

  @override
  String get userMessage =>
      'Precisamos da sua localização para seguir. '
      'Ela define o ponto de partida da sua rota.';
}

final class PermissionDeniedForever extends Failure {
  const PermissionDeniedForever();

  @override
  String get userMessage =>
      '${const PermissionDenied().userMessage} '
      'Você negou o acesso. Ative em Configurações.';
}

final class ServiceDisabled extends Failure {
  const ServiceDisabled();

  @override
  String get userMessage => 'Ative a localização do dispositivo para continuar.';
}

final class Unknown extends Failure {
  const Unknown(this.cause);

  final Object cause;

  @override
  String get userMessage => 'Algo deu errado. Tente novamente.';

  @override
  List<Object?> get props => [cause];
}

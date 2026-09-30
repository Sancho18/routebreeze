import '../domain/stop_result.dart';

/// How a [FailureReason] reads in the reason sheet, the stop list and the
/// summary.
extension FailureReasonLabel on FailureReason {
  String get label => switch (this) {
    FailureReason.recipientAbsent => 'Destinatário ausente',
    FailureReason.addressNotFound => 'Endereço não encontrado',
    FailureReason.refused => 'Recusado',
    FailureReason.other => 'Outro',
  };
}

/// Screen reader label of a stop badge: "Parada {n}" without a result,
/// "Parada {n}, entregue" or "Parada {n}, não entregue".
String resultBadgeLabel(int order, StopResult? result) => switch (result) {
  null => 'Parada $order',
  StopResult(delivered: true) => 'Parada $order, entregue',
  StopResult() => 'Parada $order, não entregue',
};

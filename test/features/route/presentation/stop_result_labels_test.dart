import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/route/domain/stop_result.dart';
import 'package:routebreeze/features/route/presentation/stop_result_labels.dart';

void main() {
  test('reasons read in pt-BR, in the order the sheet lists them', () {
    expect(FailureReason.values.map((reason) => reason.label), [
      'Destinatário ausente',
      'Endereço não encontrado',
      'Recusado',
      'Outro',
    ]);
  });

  group('resultBadgeLabel', () {
    test('without a result: "Parada 2"', () {
      expect(resultBadgeLabel(2, null), 'Parada 2');
    });

    test('delivered: "Parada 2, entregue"', () {
      expect(
        resultBadgeLabel(2, StopResult.delivered(at: DateTime.utc(2026))),
        'Parada 2, entregue',
      );
    });

    test('not delivered: "Parada 2, não entregue"', () {
      expect(
        resultBadgeLabel(
          2,
          StopResult.failed(FailureReason.refused, at: DateTime.utc(2026)),
        ),
        'Parada 2, não entregue',
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/domain/progress_estimator.dart';
import 'package:routebreeze/features/navigation/presentation/next_stop_card.dart';
import 'package:routebreeze/features/navigation/presentation/notification_copy.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';

void main() {
  const stop = RouteStop(
    stop: Stop('pa', 'Rua Augusta, 500', GeoPoint(-23.553, -46.653)),
    order: 2,
  );

  /// 1234 m and 250 s from 14:28: "1,2 km · 4 min · chegada às 14:32".
  final progress = RouteProgress(
    next: stop,
    toNextMeters: 1234,
    toNextSeconds: 250,
    remainingMeters: 8400,
    remainingSeconds: 1320,
    at: DateTime.utc(2026, 9, 28, 14, 28),
  );

  /// On the way back of a round trip there is no next stop: 3400 m and
  /// 9 min from 14:28 are what is left of it.
  final wayBack = RouteProgress(
    next: null,
    toNextMeters: 3400,
    toNextSeconds: 540,
    remainingMeters: 3400,
    remainingSeconds: 540,
    at: DateTime.utc(2026, 9, 28, 14, 28),
  );

  group('ongoingCopy', () {
    test('with a measured progress: "Próxima parada {n} · {address}" over '
        '"{distance} · {duration} · chegada às {HH:mm}", the values of the '
        'next stop card', () {
      final copy = ongoingCopy(
        next: stop,
        progress: progress,
        arrived: false,
        returning: false,
      );

      expect(copy, (
        title: 'Próxima parada 2 · Rua Augusta, 500',
        body: '1,2 km · 4 min · chegada às 14:32',
      ));
      expect(copy.body, NextStopCard.summary(progress));
    });

    test('without a measured progress, the text is "Acompanhando sua '
        'rota"', () {
      expect(ongoingCopy(next: stop, arrived: false, returning: false), (
        title: 'Próxima parada 2 · Rua Augusta, 500',
        body: 'Acompanhando sua rota',
      ));
    });

    test('once arrived at the next stop, the text is "Você chegou"', () {
      expect(
        ongoingCopy(
          next: stop,
          progress: progress,
          arrived: true,
          returning: false,
        ),
        (title: 'Próxima parada 2 · Rua Augusta, 500', body: 'Você chegou'),
      );
    });

    test('while returning, the title is "Retorno ao ponto de partida" and '
        'the text the way back\'s summary', () {
      expect(ongoingCopy(progress: wayBack, arrived: false, returning: true), (
        title: 'Retorno ao ponto de partida',
        body: '3,4 km · 9 min · chegada às 14:37',
      ));
    });

    test('while returning without a measured progress, the text is '
        '"Acompanhando sua rota"', () {
      expect(ongoingCopy(arrived: false, returning: true), (
        title: 'Retorno ao ponto de partida',
        body: 'Acompanhando sua rota',
      ));
    });
  });

  test('arrivalCopy: "Você chegou à parada {n}" / "{address}. Registre a '
      'entrega."', () {
    expect(arrivalCopy(stop), (
      title: 'Você chegou à parada 2',
      body: 'Rua Augusta, 500. Registre a entrega.',
    ));
  });

  group('recalculatedCopy', () {
    test('"Rota recalculada" / "Próxima parada {n} · {address}"', () {
      expect(recalculatedCopy(next: stop), (
        title: 'Rota recalculada',
        body: 'Próxima parada 2 · Rua Augusta, 500',
      ));
    });

    test('while returning: "Rota recalculada" / "Retorno ao ponto de '
        'partida"', () {
      expect(recalculatedCopy(), (
        title: 'Rota recalculada',
        body: 'Retorno ao ponto de partida',
      ));
    });
  });

  test('completedCopy: "Rota concluída" over the summary counts line', () {
    expect(completedCopy('3 entregues · 1 não entregue'), (
      title: 'Rota concluída',
      body: '3 entregues · 1 não entregue',
    ));
  });
}

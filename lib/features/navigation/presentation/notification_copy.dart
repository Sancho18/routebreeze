import '../../route/domain/route_plan.dart';
import '../../route/presentation/route_format.dart';
import '../domain/progress_estimator.dart';

const String _wayBack = 'Retorno ao ponto de partida';

/// `"1,2 km · 4 min · chegada às 14:32"`: the distance, time and arrival
/// clock to the next point, also on the next stop card.
String progressSummary(RouteProgress progress) =>
    '${formatDistance(progress.toNextMeters)} · '
    '${formatDuration(progress.toNextSeconds)} · '
    'chegada às ${formatClock(progress.nextArrival)}';

/// The ongoing notification of a navigation: `"Próxima parada {n} ·
/// {address}"` over the [progressSummary], `"Você chegou"` once [arrived],
/// or `"Acompanhando sua rota"` without a [progress]. While [returning] (no
/// [next] stop), the title is `"Retorno ao ponto de partida"` and the
/// summary is the way back's.
({String title, String body}) ongoingCopy({
  RouteStop? next,
  RouteProgress? progress,
  required bool arrived,
  required bool returning,
}) => (
  title: returning || next == null ? _wayBack : _nextStop(next),
  body: arrived
      ? 'Você chegou'
      : progress == null
      ? 'Acompanhando sua rota'
      : progressSummary(progress),
);

/// `"Você chegou à parada {n}"` / `"{address}. Registre a entrega."`.
({String title, String body}) arrivalCopy(RouteStop stop) => (
  title: 'Você chegou à parada ${stop.order}',
  body: '${stop.stop.address}. Registre a entrega.',
);

/// `"Rota recalculada"` over the [next] stop, or `"Retorno ao ponto de
/// partida"` on the way back.
({String title, String body}) recalculatedCopy({RouteStop? next}) => (
  title: 'Rota recalculada',
  body: next == null ? _wayBack : _nextStop(next),
);

/// `"Rota concluída"` over the summary's [countsLine]
/// (`"3 entregues · 1 não entregue"`).
({String title, String body}) completedCopy(String countsLine) =>
    (title: 'Rota concluída', body: countsLine);

String _nextStop(RouteStop stop) =>
    'Próxima parada ${stop.order} · ${stop.stop.address}';

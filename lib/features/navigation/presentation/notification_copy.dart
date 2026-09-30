import '../../route/domain/route_plan.dart';
import '../../route/presentation/route_format.dart';
import '../domain/progress_estimator.dart';

const String _wayBack = 'Retorno ao ponto de partida';

/// `"1,2 km · 4 min · chegada às 14:32"` to the next point.
String progressSummary(RouteProgress progress) =>
    '${formatDistance(progress.toNextMeters)} · '
    '${formatDuration(progress.toNextSeconds)} · '
    'chegada às ${formatClock(progress.nextArrival)}';

/// Title and body of the ongoing navigation notification.
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

({String title, String body}) arrivalCopy(RouteStop stop) => (
  title: 'Você chegou à parada ${stop.order}',
  body: '${stop.stop.address}. Registre a entrega.',
);

({String title, String body}) recalculatedCopy({RouteStop? next}) => (
  title: 'Rota recalculada',
  body: next == null ? _wayBack : _nextStop(next),
);

({String title, String body}) completedCopy(String countsLine) =>
    (title: 'Rota concluída', body: countsLine);

String _nextStop(RouteStop stop) =>
    'Próxima parada ${stop.order} · ${stop.stop.address}';

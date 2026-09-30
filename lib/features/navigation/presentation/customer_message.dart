import '../../route/presentation/route_format.dart';
import '../domain/progress_estimator.dart';

/// What the driver sends the next stop's customer: once arrived, the
/// arrival; while measured, the arrival clock the next stop card shows;
/// before that, that the delivery is on its way.
String customerMessage({
  required RouteProgress? progress,
  required bool arrived,
}) {
  if (arrived) return 'Olá! Cheguei com a sua entrega.';
  if (progress == null) return 'Olá! Sua entrega está a caminho.';
  return 'Olá! Sua entrega chega por volta das '
      '${formatClock(progress.nextArrival)}.';
}

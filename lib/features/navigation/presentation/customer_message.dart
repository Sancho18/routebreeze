import '../../route/presentation/route_format.dart';
import '../domain/progress_estimator.dart';

/// The message the driver sends the next stop's customer.
String customerMessage({
  required RouteProgress? progress,
  required bool arrived,
}) {
  if (arrived) return 'Olá! Cheguei com a sua entrega.';
  if (progress == null) return 'Olá! Sua entrega está a caminho.';
  return 'Olá! Sua entrega chega por volta das '
      '${formatClock(progress.nextArrival)}.';
}

import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../../route/presentation/route_format.dart';
import '../../route/presentation/stop_result_labels.dart';
import '../domain/route_summary.dart';

/// What the route came to, in place of the route sheet once the last stop
/// has a result: the counts, the distance and time, the start and end
/// clocks, the stops not delivered with their reasons and "Nova rota".
class RouteSummarySheet extends StatelessWidget {
  const RouteSummarySheet({
    super.key,
    required this.summary,
    required this.onNewRoute,
  });

  final RouteSummary summary;
  final VoidCallback onNewRoute;

  static const String title = 'Rota concluída';
  static const String newRouteLabel = 'Nova rota';

  /// `"3 entregues · 1 não entregue"`, `"1 entregue"`,
  /// `"0 entregues · 2 não entregues"`.
  static String counts(RouteSummary summary) {
    final delivered = summary.delivered;
    final failed = summary.failed.length;
    final line = '$delivered ${delivered == 1 ? 'entregue' : 'entregues'}';
    if (failed == 0) return line;
    return '$line · $failed ${failed == 1 ? 'não entregue' : 'não entregues'}';
  }

  /// `"12,4 km percorridos · 1 h 05 min"`; the distance alone without a
  /// start.
  static String distanceAndTime(RouteSummary summary) {
    final distance = '${formatDistance(summary.traveledMeters)} percorridos';
    return switch (summary.duration) {
      final duration? => '$distance · ${formatDuration(duration.inSeconds)}',
      null => distance,
    };
  }

  /// `"Início às 08:40 · fim às 09:45"` on the local clock (a start read
  /// back from storage is in UTC); null without a start.
  static String? clocks(RouteSummary summary) => switch (summary.start) {
    final start? =>
      'Início às ${formatClock(start.toLocal())} · '
          'fim às ${formatClock(summary.end.toLocal())}',
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final clocks = RouteSummarySheet.clocks(summary);
    return Container(
      padding: const EdgeInsets.all(RbSpace.s3),
      decoration: BoxDecoration(
        color: rb.surface200,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RbRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: RbText.heading.copyWith(color: rb.successStrong),
            ),
            const SizedBox(height: RbSpace.s2),
            Text(
              counts(summary),
              style: RbText.bodyStrong.copyWith(color: rb.ink),
            ),
            const SizedBox(height: RbSpace.s1),
            Text(
              distanceAndTime(summary),
              style: RbText.caption.copyWith(color: rb.inkMuted),
            ),
            if (clocks != null) ...[
              const SizedBox(height: RbSpace.s1),
              Text(clocks, style: RbText.caption.copyWith(color: rb.inkMuted)),
            ],
            for (final stop in summary.failed) ...[
              const SizedBox(height: RbSpace.s2),
              Text(
                'Parada ${stop.order} · ${stop.stop.address}',
                style: RbText.body.copyWith(color: rb.ink),
              ),
              if (stop.result?.reason case final reason?)
                Text(
                  reason.label,
                  style: RbText.caption.copyWith(color: rb.inkMuted),
                ),
            ],
            const SizedBox(height: RbSpace.s3),
            RbPrimaryButton(label: newRouteLabel, onPressed: onNewRoute),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../domain/route_plan.dart';
import 'route_format.dart';

/// Bottom sheet with the optimized order (ROUTE-04): heading, numbered stop
/// list with the "Visitado" chip (NAV-04), totals caption and the primary
/// action. [onMarkVisited] adds the manual "Marcar como visitado" action for
/// the next stop (NAV-05); [footer] is rendered below the actions.
class RouteSheet extends StatelessWidget {
  const RouteSheet({
    super.key,
    required this.plan,
    required this.startEnabled,
    required this.onStart,
    this.onMarkVisited,
    this.startLabel = 'Iniciar',
    this.footer,
  });

  final RoutePlan plan;
  final bool startEnabled;
  final VoidCallback onStart;
  final VoidCallback? onMarkVisited;
  final String startLabel;
  final Widget? footer;

  static const String heading = 'Ordem otimizada';
  static const String visitedLabel = 'Visitado';
  static const String markVisitedLabel = 'Marcar como visitado';

  /// Key of the row for the stop with [placeId].
  static Key stopKey(String placeId) => ValueKey('stop-$placeId');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RbSpace.s3),
      decoration: const BoxDecoration(
        color: RbColors.surface200,
        borderRadius: BorderRadius.vertical(top: Radius.circular(RbRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(heading, style: RbText.heading.copyWith(color: RbColors.ink)),
            const SizedBox(height: RbSpace.s2),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: plan.stops.length,
                separatorBuilder: (_, _) => const SizedBox(height: RbSpace.s2),
                itemBuilder: (_, i) => _StopRow(plan.stops[i]),
              ),
            ),
            const SizedBox(height: RbSpace.s2),
            Text(
              '${formatDistance(plan.distanceMeters)} · '
              '${formatDuration(plan.durationSeconds)}',
              style: RbText.caption.copyWith(color: RbColors.inkMuted),
            ),
            const SizedBox(height: RbSpace.s3),
            RbPrimaryButton(
              label: startLabel,
              enabled: startEnabled,
              onPressed: onStart,
            ),
            if (onMarkVisited != null && !plan.isComplete)
              TextButton(
                onPressed: onMarkVisited,
                style: TextButton.styleFrom(
                  foregroundColor: RbColors.brand,
                  textStyle: RbText.bodyStrong,
                ),
                child: const Text(markVisitedLabel),
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// Number badge (`brand` circle, white `bodyStrong`), address in `body`
/// (`ink-muted` once visited) and the `success` "Visitado" chip.
class _StopRow extends StatelessWidget {
  const _StopRow(this.stop);

  final RouteStop stop;

  static const double badgeSize = 24;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: RouteSheet.stopKey(stop.stop.placeId),
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: RbColors.brand,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${stop.order}',
            style: RbText.bodyStrong.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: RbSpace.s2),
        Expanded(
          child: Text(
            stop.stop.address,
            style: RbText.body.copyWith(
              color: stop.visited ? RbColors.inkMuted : RbColors.ink,
            ),
          ),
        ),
        if (stop.visited) ...[
          const SizedBox(width: RbSpace.s2),
          const RbStatusChip(
            label: RouteSheet.visitedLabel,
            tone: RbTone.success,
          ),
        ],
      ],
    );
  }
}

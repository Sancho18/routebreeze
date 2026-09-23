import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../domain/route_plan.dart';
import 'route_format.dart';

/// Bottom sheet with the optimized stop order, totals and the primary action.
/// [onMarkVisited] adds the "Marcar como visitado" button above the primary
/// action for the next stop; [footer] is rendered below the actions.
class RouteSheet extends StatelessWidget {
  const RouteSheet({
    super.key,
    required this.plan,
    required this.startEnabled,
    required this.onStart,
    this.onMarkVisited,
    this.startLabel = 'Iniciar',
    this.startColor = RbColors.brand,
    this.footer,
  });

  final RoutePlan plan;
  final bool startEnabled;
  final VoidCallback onStart;
  final VoidCallback? onMarkVisited;
  final String startLabel;
  final Color startColor;
  final Widget? footer;

  static const String heading = 'Ordem otimizada';

  /// Semantics label of the check badge on a visited stop.
  static const String visitedLabel = 'Visitado';
  static const String markVisitedLabel = 'Marcar como visitado';

  static const double rowGap = RbSpace.s2;

  static Key stopKey(String placeId) => ValueKey('stop-$placeId');

  /// The stop list never grows past this (or 40% of the screen): heading,
  /// totals and actions stay visible and the list scrolls.
  static const double maxListHeight = 320;

  @override
  Widget build(BuildContext context) {
    final listHeight = math.min(
      maxListHeight,
      MediaQuery.sizeOf(context).height * 0.4,
    );
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
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: listHeight),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: plan.stops.length,
                separatorBuilder: (_, _) => const SizedBox(height: rowGap),
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
            if (onMarkVisited != null && !plan.isComplete) ...[
              RbPrimaryButton(
                label: markVisitedLabel,
                onPressed: onMarkVisited,
              ),
              const SizedBox(height: RbSpace.s2),
            ],
            RbPrimaryButton(
              label: startLabel,
              enabled: startEnabled,
              onPressed: onStart,
              color: startColor,
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// One stop row; a visited stop gets a check badge and a muted address.
class _StopRow extends StatelessWidget {
  const _StopRow(this.stop);

  final RouteStop stop;

  static const double badgeSize = 24;
  static const double checkSize = 16;

  @override
  Widget build(BuildContext context) {
    final visited = stop.visited;
    return Row(
      key: RouteSheet.stopKey(stop.stop.placeId),
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: visited ? RbColors.success : RbColors.brand,
            shape: BoxShape.circle,
          ),
          child: visited
              ? const Icon(
                  Icons.check,
                  size: checkSize,
                  color: Colors.white,
                  semanticLabel: RouteSheet.visitedLabel,
                )
              : Text(
                  '${stop.order}',
                  style: RbText.bodyStrong.copyWith(color: Colors.white),
                ),
        ),
        const SizedBox(width: RbSpace.s2),
        Expanded(
          child: Text(
            stop.stop.address,
            style: RbText.body.copyWith(
              color: visited ? RbColors.inkMuted : RbColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

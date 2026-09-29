import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../domain/route_plan.dart';
import 'route_format.dart';
import 'stop_badge.dart';

/// Bottom sheet with the optimized stop order, totals and the primary action.
/// [onMarkVisited] adds the "Marcar como visitado" button above the primary
/// action for the next stop; [totals] replaces the plan's distance and
/// duration line; [footer] is rendered below the actions.
class RouteSheet extends StatelessWidget {
  const RouteSheet({
    super.key,
    required this.plan,
    required this.startEnabled,
    required this.onStart,
    this.onMarkVisited,
    this.startLabel = 'Iniciar',
    this.startColor,
    this.totals,
    this.footer,
  });

  final RoutePlan plan;
  final bool startEnabled;
  final VoidCallback onStart;
  final VoidCallback? onMarkVisited;
  final String startLabel;

  /// Fill of the primary action; the palette's `brand` when null.
  final Color? startColor;
  final String? totals;
  final Widget? footer;

  static const String heading = 'Ordem otimizada';

  static const String markVisitedLabel = 'Marcar como visitado';

  static const double rowGap = RbSpace.s2;

  /// The 1 px `border` divider sits inside [rowGap], starting under the
  /// address text (past the 24 px badge and its `s2` gap).
  static const double dividerIndent = StopBadge.size + RbSpace.s2;

  static Key stopKey(String placeId) => ValueKey('stop-$placeId');

  /// The stop list never grows past this (or 40% of the screen): heading,
  /// totals and actions stay visible and the list scrolls.
  static const double maxListHeight = 320;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final listHeight = math.min(
      maxListHeight,
      MediaQuery.sizeOf(context).height * 0.4,
    );
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
            Text(heading, style: RbText.heading.copyWith(color: rb.ink)),
            const SizedBox(height: RbSpace.s2),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: listHeight),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: plan.stops.length,
                separatorBuilder: (_, _) => Divider(
                  height: rowGap,
                  thickness: 1,
                  indent: dividerIndent,
                  color: rb.border,
                ),
                itemBuilder: (_, i) => _StopRow(plan.stops[i]),
              ),
            ),
            const SizedBox(height: RbSpace.s2),
            Text(
              totals ??
                  '${formatDistance(plan.distanceMeters)} · '
                      '${formatDuration(plan.durationSeconds)}',
              style: RbText.caption.copyWith(color: rb.inkMuted),
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

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final visited = stop.visited;
    return Row(
      key: RouteSheet.stopKey(stop.stop.placeId),
      children: [
        StopBadge(order: stop.order, result: stop.result),
        const SizedBox(width: RbSpace.s2),
        Expanded(
          child: Text(
            stop.stop.address,
            style: RbText.body.copyWith(color: visited ? rb.inkMuted : rb.ink),
          ),
        ),
      ],
    );
  }
}

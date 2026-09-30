import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../domain/route_plan.dart';
import 'route_format.dart';
import 'stop_badge.dart';
import 'stop_result_labels.dart';

/// Bottom sheet with the optimized stop order (a round trip ends with the way
/// back to the start), totals and the primary action.
/// While a stop is left, [onDelivered] and [onNotDelivered] add the
/// "Entregue" and "Não entregue" buttons side by side above the primary
/// action; [finishLabel] adds a primary button in their place, calling
/// [onFinish]; [totals] replaces the plan's distance and duration line;
/// [footer] is rendered below the actions.
class RouteSheet extends StatelessWidget {
  const RouteSheet({
    super.key,
    required this.plan,
    required this.startEnabled,
    required this.onStart,
    this.onDelivered,
    this.onNotDelivered,
    this.finishLabel,
    this.onFinish,
    this.startLabel = 'Iniciar',
    this.startColor,
    this.totals,
    this.footer,
  });

  final RoutePlan plan;
  final bool startEnabled;
  final VoidCallback onStart;
  final VoidCallback? onDelivered;
  final VoidCallback? onNotDelivered;

  /// "Finalizar rota" on the way back of a round trip, when every stop has a
  /// result and the result buttons are gone.
  final String? finishLabel;
  final VoidCallback? onFinish;
  final String startLabel;

  /// Fill of the primary action; the palette's `brand` when null.
  final Color? startColor;
  final String? totals;
  final Widget? footer;

  static const String heading = 'Ordem otimizada';

  static const String deliveredLabel = 'Entregue';
  static const String notDeliveredLabel = 'Não entregue';

  static const double rowGap = RbSpace.s2;

  /// The 1 px `border` divider sits inside [rowGap], starting under the
  /// address text (past the 24 px badge and its `s2` gap).
  static const double dividerIndent = StopBadge.size + RbSpace.s2;

  static Key stopKey(String placeId) => ValueKey('stop-$placeId');

  static const String returnLabel = 'Retorno ao ponto de partida';
  static const Key returnKey = ValueKey('return');

  /// The stop list never grows past this (or 40% of the screen): heading,
  /// totals and actions stay visible and the list scrolls.
  static const double maxListHeight = 320;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final finishLabel = this.finishLabel;
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
                itemCount: plan.stops.length + (plan.isRoundTrip ? 1 : 0),
                separatorBuilder: (_, _) => Divider(
                  height: rowGap,
                  thickness: 1,
                  indent: dividerIndent,
                  color: rb.border,
                ),
                itemBuilder: (_, i) => i < plan.stops.length
                    ? _StopRow(plan.stops[i])
                    : const _ReturnRow(),
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
            if ((onDelivered != null || onNotDelivered != null) &&
                !plan.isComplete) ...[
              // Both buttons take the height of the taller label.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: RbPrimaryButton(
                        label: deliveredLabel,
                        onPressed: onDelivered,
                      ),
                    ),
                    const SizedBox(width: RbSpace.s2),
                    Expanded(
                      child: RbSecondaryButton(
                        label: notDeliveredLabel,
                        onPressed: onNotDelivered,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RbSpace.s2),
            ],
            if (finishLabel != null) ...[
              RbPrimaryButton(label: finishLabel, onPressed: onFinish),
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

/// One stop row; a stop with a result gets its result badge and a muted
/// address, and a stop not delivered its reason under the address.
class _StopRow extends StatelessWidget {
  const _StopRow(this.stop);

  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final visited = stop.visited;
    final reason = stop.result?.reason;
    return Row(
      key: RouteSheet.stopKey(stop.stop.placeId),
      children: [
        StopBadge(order: stop.order, result: stop.result),
        const SizedBox(width: RbSpace.s2),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.stop.address,
                style: RbText.body.copyWith(
                  color: visited ? rb.inkMuted : rb.ink,
                ),
              ),
              if (reason != null)
                Text(
                  reason.label,
                  style: RbText.caption.copyWith(color: rb.inkMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The last row of a round trip: a home on a `brand` circle that, like
/// [StopBadge], scales with the system text.
class _ReturnRow extends StatelessWidget {
  const _ReturnRow();

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final side = MediaQuery.textScalerOf(context).scale(StopBadge.size);
    return Row(
      key: RouteSheet.returnKey,
      children: [
        Container(
          width: side,
          height: side,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: rb.brand, shape: BoxShape.circle),
          child: Icon(Icons.home, size: StopBadge.iconSize, color: rb.onFill),
        ),
        const SizedBox(width: RbSpace.s2),
        Expanded(
          child: Text(
            RouteSheet.returnLabel,
            style: RbText.body.copyWith(color: rb.ink),
          ),
        ),
      ],
    );
  }
}

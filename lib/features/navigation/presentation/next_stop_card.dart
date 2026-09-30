import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../route/domain/route_plan.dart';
import '../../route/presentation/route_format.dart';
import '../../route/presentation/stop_badge.dart';
import '../domain/progress_estimator.dart';

/// The stop the driver is heading to, over the navigation map: its number and
/// address and, once measured, the distance, time and arrival clock, which
/// "Você chegou" replaces once [arrived]. [onNotifyCustomer] adds a button to
/// share a message with the customer, and [onOpenInApp] one to hand the stop
/// over to another app. The card reads as one merged [semanticsLabel]; the
/// buttons stay separate tappable nodes.
class NextStopCard extends StatelessWidget {
  const NextStopCard({
    super.key,
    required this.stop,
    this.progress,
    this.arrived = false,
    this.onOpenInApp,
    this.onNotifyCustomer,
  });

  final RouteStop stop;
  final RouteProgress? progress;

  /// The driver reached the stop; it stays next until a result is recorded.
  final bool arrived;
  final VoidCallback? onOpenInApp;

  /// Gets the button's rect in global coordinates, where the share sheet
  /// anchors on iPad.
  final ValueChanged<Rect>? onNotifyCustomer;

  static const String label = 'Próxima parada';
  static const String openInAppTooltip = 'Abrir em outro app';
  static const String notifyCustomerTooltip = 'Avisar cliente';
  static const String arrivedText = 'Você chegou';

  /// Tap target of the card's buttons.
  static const double actionSize = 48;

  /// `"1,2 km · 4 min · chegada às 14:32"`.
  static String summary(RouteProgress progress) =>
      '${formatDistance(progress.toNextMeters)} · '
      '${formatDuration(progress.toNextSeconds)} · '
      'chegada às ${formatClock(progress.nextArrival)}';

  /// The card's merged reading: `"Próxima parada {n}: {address}."`, plus
  /// `" {distance}, {duration}, chegada às {HH:mm}"` once measured, or
  /// `" Você chegou"` once [arrived].
  static String semanticsLabel(
    RouteStop stop,
    RouteProgress? progress, {
    bool arrived = false,
  }) {
    final base = 'Próxima parada ${stop.order}: ${stop.stop.address}.';
    if (arrived) return '$base $arrivedText';
    if (progress == null) return base;
    return '$base ${formatDistance(progress.toNextMeters)}, '
        '${formatDuration(progress.toNextSeconds)}, '
        'chegada às ${formatClock(progress.nextArrival)}';
  }

  /// The details line starts under the address, past the badge.
  static const double detailsIndent = StopBadge.size + RbSpace.s2;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final progress = this.progress;
    final onOpenInApp = this.onOpenInApp;
    final onNotifyCustomer = this.onNotifyCustomer;
    final details = arrived
        ? arrivedText
        : progress == null
        ? null
        : summary(progress);
    return Semantics(
      container: true,
      label: semanticsLabel(stop, progress, arrived: arrived),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(RbSpace.s3),
        decoration: BoxDecoration(
          color: rb.surface200,
          borderRadius: BorderRadius.circular(RbRadius.md),
          border: Border.all(color: rb.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Text(
                label,
                style: RbText.caption.copyWith(color: rb.inkMuted),
              ),
            ),
            const SizedBox(height: RbSpace.s2),
            Row(
              children: [
                ExcludeSemantics(child: StopBadge(order: stop.order)),
                const SizedBox(width: RbSpace.s2),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      stop.stop.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RbText.bodyStrong.copyWith(color: rb.ink),
                    ),
                  ),
                ),
                if (onNotifyCustomer != null) ...[
                  const SizedBox(width: RbSpace.s2),
                  Builder(
                    builder: (button) => IconButton(
                      onPressed: () {
                        final box = button.findRenderObject()! as RenderBox;
                        onNotifyCustomer(
                          box.localToGlobal(Offset.zero) & box.size,
                        );
                      },
                      tooltip: notifyCustomerTooltip,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: actionSize,
                        height: actionSize,
                      ),
                      icon: Icon(Icons.adaptive.share, color: rb.brand),
                    ),
                  ),
                ],
                if (onOpenInApp != null) ...[
                  SizedBox(
                    width: onNotifyCustomer == null ? RbSpace.s2 : RbSpace.s1,
                  ),
                  IconButton(
                    onPressed: onOpenInApp,
                    tooltip: openInAppTooltip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: actionSize,
                      height: actionSize,
                    ),
                    icon: Icon(Icons.directions, color: rb.brand),
                  ),
                ],
              ],
            ),
            if (details != null) ...[
              const SizedBox(height: RbSpace.s2),
              Padding(
                padding: const EdgeInsets.only(left: detailsIndent),
                child: ExcludeSemantics(
                  child: Text(
                    details,
                    style: RbText.caption.copyWith(
                      color: arrived ? rb.successStrong : rb.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

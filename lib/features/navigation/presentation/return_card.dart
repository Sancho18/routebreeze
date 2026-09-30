import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../route/presentation/route_format.dart';
import '../../route/presentation/stop_badge.dart';
import '../domain/progress_estimator.dart';
import 'next_stop_card.dart';

/// The way back to the start of a round trip, over the navigation map once
/// every stop has a result: "Retorno", a home badge, "Ponto de partida" and,
/// once measured, the distance, time and arrival clock of the way back.
/// [onOpenInApp] adds a button to hand the start over to another app. Laid
/// out like the [NextStopCard], it reads as one merged [semanticsLabel];
/// the button stays a separate tappable node.
class ReturnCard extends StatelessWidget {
  const ReturnCard({super.key, this.progress, this.onOpenInApp});

  /// Measured on the way back: its distance and time to the next point are
  /// what is left of it.
  final RouteProgress? progress;
  final VoidCallback? onOpenInApp;

  static const String label = 'Retorno';
  static const String title = 'Ponto de partida';

  /// The card's merged reading: `"Retorno ao ponto de partida."`, plus
  /// `" {distance}, {duration}, chegada às {HH:mm}"` once measured.
  static String semanticsLabel(RouteProgress? progress) {
    const base = 'Retorno ao ponto de partida.';
    if (progress == null) return base;
    return '$base ${formatDistance(progress.toNextMeters)}, '
        '${formatDuration(progress.toNextSeconds)}, '
        'chegada às ${formatClock(progress.nextArrival)}';
  }

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final progress = this.progress;
    final onOpenInApp = this.onOpenInApp;
    // Like a stop badge, the home badge scales with the system text.
    final badge = MediaQuery.textScalerOf(context).scale(StopBadge.size);
    return Semantics(
      container: true,
      label: semanticsLabel(progress),
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
                ExcludeSemantics(
                  child: Container(
                    width: badge,
                    height: badge,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rb.brand,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.home,
                      size: StopBadge.iconSize,
                      color: rb.onFill,
                    ),
                  ),
                ),
                const SizedBox(width: RbSpace.s2),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      title,
                      style: RbText.bodyStrong.copyWith(color: rb.ink),
                    ),
                  ),
                ),
                if (onOpenInApp != null) ...[
                  const SizedBox(width: RbSpace.s2),
                  IconButton(
                    onPressed: onOpenInApp,
                    tooltip: NextStopCard.openInAppTooltip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: NextStopCard.actionSize,
                      height: NextStopCard.actionSize,
                    ),
                    icon: Icon(Icons.directions, color: rb.brand),
                  ),
                ],
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: RbSpace.s2),
              Padding(
                padding: const EdgeInsets.only(
                  left: NextStopCard.detailsIndent,
                ),
                child: ExcludeSemantics(
                  child: Text(
                    NextStopCard.summary(progress),
                    style: RbText.caption.copyWith(color: rb.inkMuted),
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

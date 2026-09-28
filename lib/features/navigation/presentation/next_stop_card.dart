import 'package:flutter/material.dart';

import '../../../core/theme/rb_tokens.dart';
import '../../route/domain/route_plan.dart';
import '../../route/presentation/route_format.dart';
import '../../route/presentation/stop_badge.dart';
import '../domain/progress_estimator.dart';

/// The stop the driver is heading to, over the navigation map: its number and
/// address and, once measured, the distance, time and arrival clock.
class NextStopCard extends StatelessWidget {
  const NextStopCard({super.key, required this.stop, this.progress});

  final RouteStop stop;
  final RouteProgress? progress;

  static const String label = 'Próxima parada';

  /// `"1,2 km · 4 min · chegada às 14:32"`.
  static String summary(RouteProgress progress) =>
      '${formatDistance(progress.toNextMeters)} · '
      '${formatDuration(progress.toNextSeconds)} · '
      'chegada às ${formatClock(progress.nextArrival)}';

  /// The details line starts under the address, past the badge.
  static const double detailsIndent = StopBadge.size + RbSpace.s2;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RbSpace.s3),
      decoration: BoxDecoration(
        color: RbColors.surface200,
        borderRadius: BorderRadius.circular(RbRadius.md),
        border: Border.all(color: RbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: RbText.caption.copyWith(color: RbColors.inkMuted)),
          const SizedBox(height: RbSpace.s2),
          Row(
            children: [
              StopBadge(order: stop.order),
              const SizedBox(width: RbSpace.s2),
              Expanded(
                child: Text(
                  stop.stop.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RbText.bodyStrong.copyWith(color: RbColors.ink),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: RbSpace.s2),
            Padding(
              padding: const EdgeInsets.only(left: detailsIndent),
              child: Text(
                summary(progress),
                style: RbText.caption.copyWith(color: RbColors.inkMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

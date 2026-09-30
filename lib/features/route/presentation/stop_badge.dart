import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../domain/stop_result.dart';
import 'stop_result_labels.dart';

/// A stop's place in the optimized order: its number on a `brand` circle
/// until it has a [result], then a check on `successStrong` (delivered) or
/// an "×" on `dangerStrong` (not delivered), all in `onFill`. Announced as
/// [resultBadgeLabel]. The circle scales with the system text, so the
/// number fits.
class StopBadge extends StatelessWidget {
  const StopBadge({super.key, required this.order, this.result});

  final int order;
  final StopResult? result;

  /// Diameter at 100% text.
  static const double size = 24;
  static const double iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final result = this.result;
    final side = MediaQuery.textScalerOf(context).scale(size);
    return Semantics(
      container: true,
      label: resultBadgeLabel(order, result),
      child: ExcludeSemantics(
        child: Container(
          width: side,
          height: side,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: switch (result) {
              null => rb.brand,
              StopResult(delivered: true) => rb.successStrong,
              StopResult() => rb.dangerStrong,
            },
            shape: BoxShape.circle,
          ),
          child: result == null
              ? Text(
                  '$order',
                  style: RbText.bodyStrong.copyWith(color: rb.onFill),
                )
              : Icon(
                  result.delivered ? Icons.check : Icons.close,
                  size: iconSize,
                  color: rb.onFill,
                ),
        ),
      ),
    );
  }
}

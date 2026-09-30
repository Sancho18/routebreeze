import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';

/// A stop's place in the optimized order: its number on a `brand` circle,
/// or a check on `success` once visited, both in `onFill`.
class StopBadge extends StatelessWidget {
  const StopBadge({super.key, required this.order, this.visited = false});

  final int order;
  final bool visited;

  static const double size = 24;
  static const double checkSize = 16;

  /// Semantics label of the check.
  static const String visitedLabel = 'Visitado';

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: visited ? rb.success : rb.brand,
        shape: BoxShape.circle,
      ),
      child: visited
          ? Icon(
              Icons.check,
              size: checkSize,
              color: rb.onFill,
              semanticLabel: visitedLabel,
            )
          : Text('$order', style: RbText.bodyStrong.copyWith(color: rb.onFill)),
    );
  }
}

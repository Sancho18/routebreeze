import 'package:flutter/material.dart';

import '../../../core/theme/rb_tokens.dart';

/// A stop's place in the optimized order: its number on a `brand` circle,
/// or a white check on `success` once visited.
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
    return Container(
      width: size,
      height: size,
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
              semanticLabel: visitedLabel,
            )
          : Text(
              '$order',
              style: RbText.bodyStrong.copyWith(color: Colors.white),
            ),
    );
  }
}

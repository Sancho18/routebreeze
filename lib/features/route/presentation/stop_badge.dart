import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';

/// A stop's place in the optimized order: its number on a `brand` circle,
/// or a check on `successStrong` once visited, both in `onFill`. Announced
/// as [label].
class StopBadge extends StatelessWidget {
  const StopBadge({super.key, required this.order, this.visited = false});

  final int order;
  final bool visited;

  static const double size = 24;
  static const double checkSize = 16;

  /// Semantics label: "Parada {n}" pending, "Parada {n}, visitada" visited.
  static String label(int order, {bool visited = false}) =>
      visited ? 'Parada $order, visitada' : 'Parada $order';

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    return Semantics(
      container: true,
      label: label(order, visited: visited),
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: visited ? rb.successStrong : rb.brand,
            shape: BoxShape.circle,
          ),
          child: visited
              ? Icon(Icons.check, size: checkSize, color: rb.onFill)
              : Text(
                  '$order',
                  style: RbText.bodyStrong.copyWith(color: rb.onFill),
                ),
        ),
      ),
    );
  }
}

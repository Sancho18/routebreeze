import 'package:flutter/material.dart';

import '../theme/rb_palette.dart';
import '../theme/rb_tokens.dart';

/// Semantic tone shared by the feedback widgets.
enum RbTone { success, warning, danger, neutral }

extension on RbTone {
  Color colorIn(RbPalette palette) => switch (this) {
    RbTone.success => palette.success,
    RbTone.warning => palette.warning,
    RbTone.danger => palette.danger,
    RbTone.neutral => palette.inkMuted,
  };
}

/// Small status label tinted by [tone].
class RbStatusChip extends StatelessWidget {
  const RbStatusChip({super.key, required this.label, required this.tone});

  final String label;
  final RbTone tone;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final neutral = tone == RbTone.neutral;
    final color = tone.colorIn(rb);
    final background = neutral ? rb.border : color.withValues(alpha: 0.12);
    final foreground = neutral ? rb.inkMuted : color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RbSpace.s2,
        vertical: RbSpace.s1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RbRadius.sm),
      ),
      child: Text(label, style: RbText.caption.copyWith(color: foreground)),
    );
  }
}

/// Full-width banner at the top of a screen (e.g. "Sem conexão").
class RbBanner extends StatelessWidget {
  const RbBanner({super.key, required this.text, required this.tone});

  final String text;
  final RbTone tone;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final neutral = tone == RbTone.neutral;
    final background = neutral ? rb.border : tone.colorIn(rb);
    final foreground = neutral ? rb.ink : rb.onFill;

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(
        vertical: RbSpace.s2,
        horizontal: RbSpace.s3,
      ),
      child: Text(text, style: RbText.bodyStrong.copyWith(color: foreground)),
    );
  }
}

/// Inline error copy with an optional text action (e.g. "Tentar novamente").
class RbInlineError extends StatelessWidget {
  const RbInlineError({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final label = actionLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: RbText.body.copyWith(color: rb.danger)),
        if (label != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: rb.brand,
              textStyle: RbText.bodyStrong,
            ),
            child: Text(label),
          ),
      ],
    );
  }
}

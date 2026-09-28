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

  /// The tone's readable role: text in this color clears 4.5:1 against the
  /// backgrounds the feedback widgets use.
  Color strongColorIn(RbPalette palette) => switch (this) {
    RbTone.success => palette.successStrong,
    RbTone.warning => palette.warningStrong,
    RbTone.danger => palette.dangerStrong,
    RbTone.neutral => palette.inkMuted,
  };
}

/// Small status label tinted by [tone]; announced as a live region.
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
    final foreground = neutral ? rb.inkMuted : tone.strongColorIn(rb);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RbSpace.s2,
          vertical: RbSpace.s1,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(RbRadius.sm),
        ),
        child: Text(label, style: RbText.caption.copyWith(color: foreground)),
      ),
    );
  }
}

/// Full-width banner at the top of a screen (e.g. "Sem conexão"); announced
/// as a live region.
class RbBanner extends StatelessWidget {
  const RbBanner({super.key, required this.text, required this.tone});

  final String text;
  final RbTone tone;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final neutral = tone == RbTone.neutral;
    final background = neutral ? rb.border : tone.strongColorIn(rb);
    final foreground = neutral ? rb.ink : rb.onFill;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: background,
        padding: const EdgeInsets.symmetric(
          vertical: RbSpace.s2,
          horizontal: RbSpace.s3,
        ),
        child: Text(text, style: RbText.bodyStrong.copyWith(color: foreground)),
      ),
    );
  }
}

/// Inline error copy with an optional text action (e.g. "Tentar novamente").
/// [liveRegion] announces it on appearance (e.g. a GPS loss).
class RbInlineError extends StatelessWidget {
  const RbInlineError({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.liveRegion = false,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final label = actionLabel;
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: RbText.body.copyWith(color: rb.dangerStrong)),
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
      ),
    );
  }
}

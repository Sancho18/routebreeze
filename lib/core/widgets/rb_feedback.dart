import 'package:flutter/material.dart';

import '../theme/rb_tokens.dart';

/// Semantic tone shared by the feedback widgets.
enum RbTone { success, warning, danger, neutral }

extension on RbTone {
  Color get color => switch (this) {
    RbTone.success => RbColors.success,
    RbTone.warning => RbColors.warning,
    RbTone.danger => RbColors.danger,
    RbTone.neutral => RbColors.inkMuted,
  };
}

/// Small status label (NAV-04 "Visitado", RECALC-04/05/06 badges).
///
/// `radius-sm`; tone color at 12% as background with the tone color as text.
/// Neutral uses `border` background and `ink-muted` text.
class RbStatusChip extends StatelessWidget {
  const RbStatusChip({super.key, required this.label, required this.tone});

  final String label;
  final RbTone tone;

  @override
  Widget build(BuildContext context) {
    final neutral = tone == RbTone.neutral;
    final background = neutral
        ? RbColors.border
        : tone.color.withValues(alpha: 0.12);
    final foreground = neutral ? RbColors.inkMuted : tone.color;

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

/// Full-width banner at the top of a screen (OFFL-01 "Sem conexão").
///
/// Tone color as background with white `body-strong` text; neutral uses
/// `border` background and `ink` text. Padding `s2` vertical, `s3` horizontal.
class RbBanner extends StatelessWidget {
  const RbBanner({super.key, required this.text, required this.tone});

  final String text;
  final RbTone tone;

  @override
  Widget build(BuildContext context) {
    final neutral = tone == RbTone.neutral;
    final background = neutral ? RbColors.border : tone.color;
    final foreground = neutral ? RbColors.ink : Colors.white;

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

/// Inline error copy in `danger`/`body` with an optional text action
/// (ROUTE-06 "Tentar novamente", MAP-03..06 buttons).
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
    final label = actionLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: RbText.body.copyWith(color: RbColors.danger)),
        if (label != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: RbColors.brand,
              textStyle: RbText.bodyStrong,
            ),
            child: Text(label),
          ),
      ],
    );
  }
}

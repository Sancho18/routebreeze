import 'package:flutter/material.dart';

import '../theme/rb_tokens.dart';

/// Primary action button (DS-03).
///
/// Enabled: `brand` background with white `bodyStrong` text. Disabled:
/// `border` background with `inkMuted` text. Both states share `radius-lg`
/// and a fixed height of 52 so the button never moves between states.
/// While [loading] a 20 px spinner replaces the label and taps are ignored.
class RbPrimaryButton extends StatelessWidget {
  const RbPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final background = enabled ? RbColors.brand : RbColors.border;
    final foreground = enabled ? Colors.white : RbColors.inkMuted;
    final radius = BorderRadius.circular(RbRadius.lg);
    final active = enabled && !loading;

    return Semantics(
      button: true,
      enabled: active,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: active ? onPressed : null,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Text(
                      label,
                      style: RbText.bodyStrong.copyWith(color: foreground),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/rb_palette.dart';
import '../theme/rb_tokens.dart';

/// Primary action button that keeps its size across states; while [loading]
/// a spinner replaces the label and taps are ignored.
class RbPrimaryButton extends StatelessWidget {
  const RbPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  /// Background while enabled; the palette's `brand` when null. Only palette
  /// fills are expected here.
  final Color? color;

  /// Minimum height.
  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final background = enabled ? color ?? rb.brand : rb.border;
    final foreground = enabled ? rb.onFill : rb.inkMuted;
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: height,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RbSpace.s3),
                  child: Visibility(
                    visible: !loading,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: RbText.bodyStrong.copyWith(color: foreground),
                    ),
                  ),
                ),
                if (loading)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action button: outlined, sized like [RbPrimaryButton].
class RbSecondaryButton extends StatelessWidget {
  const RbSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final radius = BorderRadius.circular(RbRadius.lg);

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: enabled ? rb.brand : rb.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: RbPrimaryButton.height,
            ),
            child: Center(
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RbSpace.s3),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: RbText.bodyStrong.copyWith(
                    color: enabled ? rb.brandStrong : rb.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

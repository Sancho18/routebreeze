import 'package:flutter/material.dart';

import '../theme/rb_tokens.dart';

/// DS text field (ADDR-01, ADDR-05).
///
/// `surface-200` fill, `border` outline with `radius-md` (brand when focused,
/// danger on error), padding 16, placeholder in `ink-muted`, [errorText] in
/// `caption`/`danger` under the field, optional [trailing] widget.
class RbTextField extends StatelessWidget {
  const RbTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.errorText,
    this.trailing,
    this.focusNode,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final String? errorText;
  final Widget? trailing;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Caps the input; no counter is shown.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLength: maxLength,
      buildCounter: _noCounter,
      style: RbText.body.copyWith(color: RbColors.ink),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: RbText.body.copyWith(color: RbColors.inkMuted),
        errorText: errorText,
        errorStyle: RbText.caption.copyWith(color: RbColors.danger),
        filled: true,
        fillColor: RbColors.surface200,
        contentPadding: const EdgeInsets.all(RbSpace.s3),
        suffixIcon: trailing,
        border: _outline(RbColors.border),
        enabledBorder: _outline(RbColors.border),
        focusedBorder: _outline(RbColors.brand),
        errorBorder: _outline(RbColors.danger),
        focusedErrorBorder: _outline(RbColors.danger),
      ),
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) => null;

OutlineInputBorder _outline(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(RbRadius.md),
  borderSide: BorderSide(color: color),
);

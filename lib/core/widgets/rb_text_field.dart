import 'package:flutter/material.dart';

import '../theme/rb_palette.dart';
import '../theme/rb_tokens.dart';

/// Design-system text field.
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
    final rb = context.rb;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLength: maxLength,
      buildCounter: _noCounter,
      style: RbText.body.copyWith(color: rb.ink),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: RbText.body.copyWith(color: rb.inkMuted),
        errorText: errorText,
        errorStyle: RbText.caption.copyWith(color: rb.dangerStrong),
        filled: true,
        fillColor: rb.surface200,
        contentPadding: const EdgeInsets.all(RbSpace.s3),
        suffixIcon: trailing,
        border: _outline(rb.border),
        enabledBorder: _outline(rb.border),
        focusedBorder: _outline(rb.brand),
        errorBorder: _outline(rb.danger),
        focusedErrorBorder: _outline(rb.danger),
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

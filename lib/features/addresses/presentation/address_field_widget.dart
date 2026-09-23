import 'package:flutter/material.dart';

import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_text_field.dart';
import '../domain/address_field.dart';
import '../domain/suggestion.dart';
import 'address_form_cubit.dart';

/// One address input with its suggestion list under it.
class AddressFieldWidget extends StatefulWidget {
  const AddressFieldWidget({
    super.key,
    required this.field,
    required this.placeholder,
    required this.onChanged,
    required this.onSuggestionSelected,
    this.onRemove,
  });

  final AddressField field;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<Suggestion> onSuggestionSelected;

  /// Present only for fields beyond the first three.
  final VoidCallback? onRemove;

  @override
  State<AddressFieldWidget> createState() => _AddressFieldWidgetState();
}

class _AddressFieldWidgetState extends State<AddressFieldWidget> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.field.text,
  );

  @override
  void didUpdateWidget(AddressFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.field.text;
    if (text != _controller.text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final onRemove = widget.onRemove;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RbTextField(
          controller: _controller,
          placeholder: widget.placeholder,
          errorText: field.error,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.next,
          maxLength: AddressFormCubit.maxChars,
          trailing: field.loading
              ? const Padding(
                  padding: EdgeInsets.all(RbSpace.s3),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : onRemove == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: RbColors.inkMuted),
                  tooltip: 'Remover ponto',
                  onPressed: onRemove,
                ),
        ),
        if (field.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: RbSpace.s1),
            child: Material(
              color: RbColors.surface200,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RbRadius.md),
                side: const BorderSide(color: RbColors.border),
              ),
              child: Column(
                children: [
                  for (final suggestion in field.suggestions)
                    ListTile(
                      dense: true,
                      title: Text(
                        suggestion.mainText,
                        style: RbText.bodyStrong.copyWith(color: RbColors.ink),
                      ),
                      subtitle: suggestion.secondaryText.isEmpty
                          ? null
                          : Text(
                              suggestion.secondaryText,
                              style: RbText.caption.copyWith(
                                color: RbColors.inkMuted,
                              ),
                            ),
                      onTap: () => widget.onSuggestionSelected(suggestion),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

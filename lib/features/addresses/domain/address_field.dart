import 'package:equatable/equatable.dart';

import 'stop.dart';
import 'suggestion.dart';

const Object _unset = Object();

/// One address input with its autocomplete session.
class AddressField extends Equatable {
  const AddressField({
    required this.id,
    required this.sessionToken,
    this.text = '',
    this.selected,
    this.suggestions = const [],
    this.loading = false,
    this.error,
  });

  final String id;
  final String text;

  final Stop? selected;

  /// Places session token; rotated after each successful details call.
  final String sessionToken;
  final List<Suggestion> suggestions;
  final bool loading;
  final String? error;

  /// Valid only while a suggestion is selected and the text was not edited
  /// since.
  bool get isValid => selected != null && text == selected!.address;

  AddressField copyWith({
    String? text,
    Object? selected = _unset,
    String? sessionToken,
    List<Suggestion>? suggestions,
    bool? loading,
    Object? error = _unset,
  }) => AddressField(
    id: id,
    text: text ?? this.text,
    selected: identical(selected, _unset) ? this.selected : selected as Stop?,
    sessionToken: sessionToken ?? this.sessionToken,
    suggestions: suggestions ?? this.suggestions,
    loading: loading ?? this.loading,
    error: identical(error, _unset) ? this.error : error as String?,
  );

  @override
  List<Object?> get props => [
    id,
    text,
    selected,
    sessionToken,
    suggestions,
    loading,
    error,
  ];

  @override
  bool get stringify => true;
}

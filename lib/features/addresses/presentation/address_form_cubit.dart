import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/failure.dart';
import '../../../core/geo/geo_point.dart';
import '../data/places_api.dart';
import '../domain/address_field.dart';
import '../domain/address_form_validator.dart';
import '../domain/stop.dart';
import '../domain/suggestion.dart';

const Object _unset = Object();

class AddressFormState extends Equatable {
  const AddressFormState({
    required this.fields,
    this.online = true,
    this.submitting = false,
    this.submitted,
    this.failure,
  });

  final List<AddressField> fields;
  final bool online;
  final bool submitting;

  /// The stops handed over by a successful [AddressFormCubit.confirm].
  final List<Stop>? submitted;
  final Failure? failure;

  /// "Confirmar rota" is enabled only online with every field valid
  /// (ADDR-10, OFFL-02).
  bool get canConfirm =>
      online && AddressFormValidator.validate(fields).isValid;

  AddressFormState copyWith({
    List<AddressField>? fields,
    bool? online,
    bool? submitting,
    Object? submitted = _unset,
    Object? failure = _unset,
  }) => AddressFormState(
    fields: fields ?? this.fields,
    online: online ?? this.online,
    submitting: submitting ?? this.submitting,
    submitted: identical(submitted, _unset)
        ? this.submitted
        : submitted as List<Stop>?,
    failure: identical(failure, _unset) ? this.failure : failure as Failure?,
  );

  @override
  List<Object?> get props => [fields, online, submitting, submitted, failure];
}

/// Address list with autocomplete sessions, debounce and validation
/// (ADDR-02..ADDR-04, ADDR-08..ADDR-12, OFFL-02).
class AddressFormCubit extends Cubit<AddressFormState> {
  AddressFormCubit(
    this._places, {
    required this.bias,
    Uuid uuid = const Uuid(),
    bool online = true,
  }) : _uuid = uuid,
       super(
         AddressFormState(
           fields: [
             for (var i = 1; i <= AddressFormValidator.minFields; i++)
               AddressField(id: 'f$i', sessionToken: uuid.v4()),
           ],
           online: online,
         ),
       );

  final PlacesApi _places;

  /// Start position used as the autocomplete location bias (ADDR-02).
  final GeoPoint bias;
  final Uuid _uuid;
  final Map<String, Timer> _timers = {};
  int _nextId = AddressFormValidator.minFields;

  static const Duration debounce = Duration(milliseconds: 300);
  static const int minChars = 3;
  static const String searchError =
      'Não foi possível buscar endereços. Tente novamente.';

  static const Set<String> _validatorMessages = {
    AddressFormValidator.required,
    AddressFormValidator.notSelected,
    AddressFormValidator.duplicate,
  };

  void onTextChanged(String id, String text) {
    final field = _field(id);
    final selected = field.selected;
    _update(
      field.copyWith(
        text: text,
        selected: selected != null && text == selected.address
            ? selected
            : null,
        suggestions: text.trim().length < minChars ? const [] : null,
        loading: false,
        error: null,
      ),
    );
    _timers[id]?.cancel();
    _timers[id] = Timer(debounce, () => _search(id));
  }

  Future<void> _search(String id) async {
    final field = _fieldOrNull(id);
    if (field == null) return;
    final input = field.text.trim();
    if (input.length < minChars || !state.online) return;
    _update(field.copyWith(loading: true));
    try {
      final suggestions = await _places.autocomplete(
        input: input,
        sessionToken: field.sessionToken,
        bias: bias,
      );
      final current = _currentFor(field);
      if (current == null) return;
      _update(current.copyWith(loading: false, suggestions: suggestions));
    } on Object {
      final current = _currentFor(field);
      if (current == null) return;
      _update(current.copyWith(loading: false, error: searchError));
    }
  }

  Future<void> selectSuggestion(String id, Suggestion suggestion) async {
    _timers.remove(id)?.cancel();
    final field = _field(id);
    _update(field.copyWith(loading: true, error: null));
    try {
      final stop = await _places.details(
        placeId: suggestion.placeId,
        sessionToken: field.sessionToken,
      );
      final current = _currentFor(field);
      if (current == null) return;
      _update(
        current.copyWith(
          loading: false,
          text: stop.address,
          selected: stop,
          sessionToken: _uuid.v4(),
          suggestions: const [],
        ),
      );
    } on Object {
      final current = _currentFor(field);
      if (current == null) return;
      _update(current.copyWith(loading: false, error: searchError));
    }
  }

  void addField() =>
      emit(state.copyWith(fields: [...state.fields, _newField()]));

  /// Only fields beyond the first three can go; validator messages on the
  /// remaining fields are re-derived (ADDR-09, duplicate edge case).
  void removeField(String id) {
    final index = state.fields.indexWhere((f) => f.id == id);
    if (index < AddressFormValidator.minFields) return;
    _timers.remove(id)?.cancel();
    final remaining = [...state.fields]..removeAt(index);
    final errors = AddressFormValidator.validate(remaining).errors;
    emit(
      state.copyWith(
        fields: [
          for (final f in remaining)
            _validatorMessages.contains(f.error)
                ? f.copyWith(error: errors[f.id])
                : f,
        ],
      ),
    );
  }

  void confirm() {
    final result = AddressFormValidator.validate(state.fields);
    if (!result.isValid) {
      emit(
        state.copyWith(
          fields: [
            for (final f in state.fields)
              f.copyWith(error: result.errors[f.id]),
          ],
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        submitted: [for (final f in state.fields) f.selected!],
        failure: null,
      ),
    );
  }

  void setOnline(bool online) => emit(state.copyWith(online: online));

  /// Clears the submission outcome; the fields stay so the form is intact
  /// when the user comes back (ADDR-12).
  void reset() =>
      emit(state.copyWith(submitting: false, submitted: null, failure: null));

  @override
  Future<void> close() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    return super.close();
  }

  AddressField _newField() =>
      AddressField(id: 'f${++_nextId}', sessionToken: _uuid.v4());

  AddressField _field(String id) => state.fields.firstWhere((f) => f.id == id);

  AddressField? _fieldOrNull(String id) {
    for (final f in state.fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The field as it is now, or null when it was removed, the cubit closed
  /// or its text changed while the request was in flight (stale response).
  AddressField? _currentFor(AddressField requested) {
    if (isClosed) return null;
    final current = _fieldOrNull(requested.id);
    if (current == null || current.text != requested.text) return null;
    return current;
  }

  void _update(AddressField field) => emit(
    state.copyWith(
      fields: [for (final f in state.fields) f.id == field.id ? field : f],
    ),
  );
}

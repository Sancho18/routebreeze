import 'package:equatable/equatable.dart';

import 'address_field.dart';

class ValidationResult extends Equatable {
  const ValidationResult(this.errors, this.isValid);

  /// Error copy per field id; fields without an error are absent.
  final Map<String, String> errors;
  final bool isValid;

  @override
  List<Object?> get props => [errors, isValid];
}

/// Form rules (ADDR-05..ADDR-07, ADDR-09, ADDR-10): every present field
/// must hold a selected suggestion, placeIds must be unique (the later
/// field gets the error) and at least [minFields] fields must exist.
abstract final class AddressFormValidator {
  static const int minFields = 3;

  static const String required = 'Campo obrigatório';
  static const String notSelected = 'Selecione um endereço da lista';
  static const String duplicate = 'Endereço repetido';

  static ValidationResult validate(List<AddressField> fields) {
    final errors = <String, String>{};
    final seen = <String>{};
    for (final field in fields) {
      if (field.text.trim().isEmpty) {
        errors[field.id] = required;
      } else if (!field.isValid) {
        errors[field.id] = notSelected;
      } else if (!seen.add(field.selected!.placeId)) {
        errors[field.id] = duplicate;
      }
    }
    return ValidationResult(
      errors,
      errors.isEmpty && fields.length >= minFields,
    );
  }
}

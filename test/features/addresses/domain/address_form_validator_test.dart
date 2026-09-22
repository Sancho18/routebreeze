import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/address_field.dart';
import 'package:routebreeze/features/addresses/domain/address_form_validator.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';

void main() {
  Stop stop(String id) =>
      Stop(id, 'Endereço $id', const GeoPoint(-23.5, -46.6));

  AddressField valid(String id, [String? placeId]) => AddressField(
    id: id,
    sessionToken: 'tok-$id',
    text: 'Endereço ${placeId ?? id}',
    selected: stop(placeId ?? id),
  );

  AddressField empty(String id) =>
      AddressField(id: id, sessionToken: 'tok-$id');

  AddressField typed(String id, String text) =>
      AddressField(id: id, sessionToken: 'tok-$id', text: text);

  group('AddressFormValidator.validate', () {
    test('three valid distinct fields → valid with no errors', () {
      final result = AddressFormValidator.validate([
        valid('a'),
        valid('b'),
        valid('c'),
      ]);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('empty field → "Campo obrigatório" under it; form invalid', () {
      final result = AddressFormValidator.validate([
        valid('a'),
        empty('b'),
        valid('c'),
      ]);

      expect(result.isValid, isFalse);
      expect(result.errors, {'b': 'Campo obrigatório'});
    });

    test('whitespace-only text counts as empty', () {
      final result = AddressFormValidator.validate([
        typed('a', '   '),
        valid('b'),
        valid('c'),
      ]);

      expect(result.errors, {'a': 'Campo obrigatório'});
    });

    test('text without a selection → "Selecione um endereço da lista"', () {
      final result = AddressFormValidator.validate([
        valid('a'),
        valid('b'),
        typed('c', 'Rua qualquer'),
      ]);

      expect(result.isValid, isFalse);
      expect(result.errors, {'c': 'Selecione um endereço da lista'});
    });

    test('selection edited afterwards → "Selecione um endereço da lista"', () {
      final edited = valid('b').copyWith(text: 'Endereço b editado');
      final result = AddressFormValidator.validate([
        valid('a'),
        edited,
        valid('c'),
      ]);

      expect(result.isValid, isFalse);
      expect(result.errors, {'b': 'Selecione um endereço da lista'});
    });

    test('duplicate placeId → "Endereço repetido" on the later field only', () {
      final result = AddressFormValidator.validate([
        valid('a', 'p1'),
        valid('b'),
        valid('c', 'p1'),
      ]);

      expect(result.isValid, isFalse);
      expect(result.errors, {'c': 'Endereço repetido'});
    });

    test('removing the field that held the duplicate clears the error on '
        'the remaining one', () {
      final fields = [
        valid('a', 'p1'),
        valid('b'),
        valid('c'),
        valid('d', 'p1'),
      ];
      expect(AddressFormValidator.validate(fields).errors, {
        'd': 'Endereço repetido',
      });

      final result = AddressFormValidator.validate(
        fields.where((f) => f.id != 'd').toList(),
      );

      expect(result.errors, isEmpty);
      expect(result.isValid, isTrue);
    });

    test('every invalid field gets its own error', () {
      final result = AddressFormValidator.validate([
        empty('a'),
        typed('b', 'Rua'),
        valid('c', 'p9'),
        valid('d', 'p9'),
      ]);

      expect(result.errors, {
        'a': 'Campo obrigatório',
        'b': 'Selecione um endereço da lista',
        'd': 'Endereço repetido',
      });
      expect(result.isValid, isFalse);
    });

    test('four valid fields → valid', () {
      final result = AddressFormValidator.validate([
        valid('a'),
        valid('b'),
        valid('c'),
        valid('d'),
      ]);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('three valid + one empty added field → invalid', () {
      final result = AddressFormValidator.validate([
        valid('a'),
        valid('b'),
        valid('c'),
        empty('d'),
      ]);

      expect(result.isValid, isFalse);
      expect(result.errors, {'d': 'Campo obrigatório'});
    });

    test('fewer than three fields → invalid even when all are valid', () {
      final result = AddressFormValidator.validate([valid('a'), valid('b')]);

      expect(result.isValid, isFalse);
      expect(result.errors, isEmpty);
    });
  });
}

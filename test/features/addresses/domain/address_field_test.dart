import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/address_field.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';

void main() {
  const stop = Stop('p1', 'Av. Paulista, 1000', GeoPoint(-23.56, -46.65));

  group('AddressField.isValid', () {
    test('false while nothing is selected', () {
      const field = AddressField(id: 'a', sessionToken: 't', text: 'Av. P');
      expect(field.isValid, isFalse);
    });

    test('true once a suggestion is selected and the text matches it', () {
      const field = AddressField(
        id: 'a',
        sessionToken: 't',
        text: 'Av. Paulista, 1000',
        selected: stop,
      );
      expect(field.isValid, isTrue);
    });

    test('false again after editing the text of a selected field', () {
      const field = AddressField(
        id: 'a',
        sessionToken: 't',
        text: 'Av. Paulista, 100',
        selected: stop,
      );
      expect(field.isValid, isFalse);
    });
  });

  test('copyWith clears selected and error when null is passed explicitly '
      'and keeps them when omitted', () {
    const field = AddressField(
      id: 'a',
      sessionToken: 't',
      text: 'x',
      selected: stop,
      error: 'Campo obrigatório',
    );

    expect(field.copyWith(text: 'y').selected, stop);
    expect(field.copyWith(text: 'y').error, 'Campo obrigatório');
    expect(field.copyWith(selected: null).selected, isNull);
    expect(field.copyWith(error: null).error, isNull);
    expect(field.copyWith(text: 'y').id, 'a');
  });
}

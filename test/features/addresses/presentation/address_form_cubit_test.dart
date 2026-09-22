import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/domain/address_field.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/addresses/domain/suggestion.dart';
import 'package:routebreeze/features/addresses/presentation/address_form_cubit.dart';

class MockPlacesApi extends Mock implements PlacesApi {}

void main() {
  const bias = GeoPoint(-23.5614, -46.6559);
  const searchError = 'Não foi possível buscar endereços. Tente novamente.';
  const suggestion = Suggestion('p1', 'Avenida Paulista, 1000', 'São Paulo');
  const stop = Stop(
    'p1',
    'Av. Paulista, 1000 - Bela Vista, São Paulo - SP',
    GeoPoint(-23.5651, -46.6507),
  );
  Stop stopFor(String placeId) =>
      Stop(placeId, 'Endereço $placeId', const GeoPoint(-23.5, -46.6));

  late MockPlacesApi places;

  setUp(() => places = MockPlacesApi());

  AddressFormCubit build({bool online = true}) =>
      AddressFormCubit(places, bias: bias, online: online);

  AddressField field(AddressFormCubit cubit, String id) =>
      cubit.state.fields.firstWhere((f) => f.id == id);

  void stubAutocomplete({
    required String input,
    required String token,
    Object result = const [suggestion],
  }) {
    final stub = when(
      () => places.autocomplete(input: input, sessionToken: token, bias: bias),
    );
    if (result is Failure) {
      stub.thenThrow(result);
    } else {
      stub.thenAnswer((_) async => result as List<Suggestion>);
    }
  }

  void stubDetails({
    required String placeId,
    required String token,
    Object result = stop,
  }) {
    final stub = when(
      () => places.details(placeId: placeId, sessionToken: token),
    );
    if (result is Failure) {
      stub.thenThrow(result);
    } else {
      stub.thenAnswer((_) async => result as Stop);
    }
  }

  /// Types, selects the stubbed suggestion and returns the selected stop.
  void fillValid(FakeAsync async, AddressFormCubit cubit, String id, Stop s) {
    final token = field(cubit, id).sessionToken;
    stubDetails(placeId: s.placeId, token: token, result: s);
    cubit.selectSuggestion(id, Suggestion(s.placeId, s.address, ''));
    async.flushMicrotasks();
  }

  test('starts with three empty fields, distinct ids and session tokens, '
      'online, nothing submitted', () {
    final cubit = build();
    final fields = cubit.state.fields;

    expect(fields, hasLength(3));
    expect(fields.map((f) => f.id), ['f1', 'f2', 'f3']);
    expect(fields.map((f) => f.text), ['', '', '']);
    expect(fields.map((f) => f.sessionToken).toSet(), hasLength(3));
    expect(fields.every((f) => f.sessionToken.length == 36), isTrue);
    expect(cubit.state.online, isTrue);
    expect(cubit.state.submitted, isNull);
    expect(cubit.state.canConfirm, isFalse);
  });

  group('onTextChanged debounce', () {
    test('2 characters never call autocomplete', () {
      fakeAsync((async) {
        final cubit = build();

        cubit.onTextChanged('f1', 'Av');
        async.elapse(const Duration(seconds: 1));

        verifyNever(
          () => places.autocomplete(
            input: any(named: 'input'),
            sessionToken: any(named: 'sessionToken'),
            bias: bias,
          ),
        );
        expect(field(cubit, 'f1').text, 'Av');
        expect(field(cubit, 'f1').loading, isFalse);
      });
    });

    test('3 characters: no call at 299 ms, one call at 300 ms with the '
        'field token and the bias, then suggestions', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        stubAutocomplete(input: 'Av.', token: token);
        final states = <AddressFormState>[];
        cubit.stream.listen(states.add);

        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 299));
        verifyNever(
          () => places.autocomplete(
            input: 'Av.',
            sessionToken: token,
            bias: bias,
          ),
        );

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        verify(
          () => places.autocomplete(
            input: 'Av.',
            sessionToken: token,
            bias: bias,
          ),
        ).called(1);
        expect(field(cubit, 'f1').suggestions, [suggestion]);
        expect(field(cubit, 'f1').loading, isFalse);
        expect(field(cubit, 'f1').error, isNull);
        expect(states.map((s) => s.fields.first.loading), [false, true, false]);
      });
    });

    test('typing again within 300 ms restarts the timer; one call with the '
        'latest text', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        stubAutocomplete(input: 'Av. P', token: token);

        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 200));
        cubit.onTextChanged('f1', 'Av. P');
        async.elapse(const Duration(milliseconds: 299));
        verifyNever(
          () => places.autocomplete(
            input: any(named: 'input'),
            sessionToken: token,
            bias: bias,
          ),
        );

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        verify(
          () => places.autocomplete(
            input: 'Av. P',
            sessionToken: token,
            bias: bias,
          ),
        ).called(1);
        verifyNever(
          () => places.autocomplete(
            input: 'Av.',
            sessionToken: token,
            bias: bias,
          ),
        );
      });
    });

    test('closing the cubit while the debounce is pending drops the '
        'request (leaving the screen makes no Places call)', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        stubAutocomplete(input: 'Av.', token: token);

        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 100));
        cubit.close();
        async.elapse(const Duration(seconds: 1));

        verifyNever(
          () => places.autocomplete(
            input: any(named: 'input'),
            sessionToken: any(named: 'sessionToken'),
            bias: bias,
          ),
        );
      });
    });

    test('a response for text that changed meanwhile is ignored', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        final pending = Completer<List<Suggestion>>();
        when(
          () => places.autocomplete(
            input: 'Av.',
            sessionToken: token,
            bias: bias,
          ),
        ).thenAnswer((_) => pending.future);

        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 300));
        expect(field(cubit, 'f1').loading, isTrue);
        cubit.onTextChanged('f1', 'Av. Paulista');
        pending.complete(const [suggestion]);
        async.flushMicrotasks();

        expect(field(cubit, 'f1').text, 'Av. Paulista');
        expect(field(cubit, 'f1').suggestions, isEmpty);
        expect(field(cubit, 'f1').loading, isFalse);
      });
    });

    test('the query sent to autocomplete is capped at 200 characters', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        final long = 'Rua ${'a' * 300}';
        stubAutocomplete(input: long.substring(0, 200), token: token);

        cubit.onTextChanged('f1', long);
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        final sent = verify(
          () => places.autocomplete(
            input: captureAny(named: 'input'),
            sessionToken: token,
            bias: bias,
          ),
        ).captured.single;
        expect(sent, long.substring(0, 200));
        expect(field(cubit, 'f1').suggestions, [suggestion]);
      });
    });

    test('offline: no request; typed text is kept (OFFL-02)', () {
      fakeAsync((async) {
        final cubit = build();
        cubit.setOnline(false);

        cubit.onTextChanged('f1', 'Av. Paulista');
        async.elapse(const Duration(seconds: 1));

        verifyNever(
          () => places.autocomplete(
            input: any(named: 'input'),
            sessionToken: any(named: 'sessionToken'),
            bias: bias,
          ),
        );
        expect(cubit.state.online, isFalse);
        expect(field(cubit, 'f1').text, 'Av. Paulista');
      });
    });

    test('autocomplete failure → field error, text kept (ADDR-11)', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        stubAutocomplete(
          input: 'Av. Paulista',
          token: token,
          result: const NoConnection(),
        );

        cubit.onTextChanged('f1', 'Av. Paulista');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(field(cubit, 'f1').error, searchError);
        expect(field(cubit, 'f1').text, 'Av. Paulista');
        expect(field(cubit, 'f1').loading, isFalse);

        cubit.onTextChanged('f1', 'Av. Paulista,');
        expect(field(cubit, 'f1').error, isNull);
      });
    });
  });

  group('selectSuggestion', () {
    test('calls details with the same token, stores the stop, sets the text '
        'to the address, clears suggestions and rotates the token', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        stubAutocomplete(input: 'Av.', token: token);
        stubDetails(placeId: 'p1', token: token);
        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        cubit.selectSuggestion('f1', suggestion);
        expect(field(cubit, 'f1').loading, isTrue);
        async.flushMicrotasks();

        verify(() => places.details(placeId: 'p1', sessionToken: token))
            .called(1);
        final selected = field(cubit, 'f1');
        expect(selected.selected, stop);
        expect(selected.text, stop.address);
        expect(selected.isValid, isTrue);
        expect(selected.suggestions, isEmpty);
        expect(selected.loading, isFalse);
        expect(selected.sessionToken, isNot(token));
        expect(selected.sessionToken.length, 36);

        // The next search on this field uses the new token.
        stubAutocomplete(input: 'Rua', token: selected.sessionToken);
        cubit.onTextChanged('f1', 'Rua');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();
        verify(
          () => places.autocomplete(
            input: 'Rua',
            sessionToken: selected.sessionToken,
            bias: bias,
          ),
        ).called(1);
      });
    });

    test('editing after a selection invalidates the field (ADDR-04)', () {
      fakeAsync((async) {
        final cubit = build();
        fillValid(async, cubit, 'f1', stop);
        expect(field(cubit, 'f1').isValid, isTrue);

        cubit.onTextChanged('f1', '${stop.address}x');

        expect(field(cubit, 'f1').selected, isNull);
        expect(field(cubit, 'f1').isValid, isFalse);
        expect(field(cubit, 'f1').text, '${stop.address}x');
      });
    });

    test('text equal to the selected address keeps the selection and does '
        'not query autocomplete (ADDR-02, ADDR-04)', () {
      fakeAsync((async) {
        final cubit = build();
        fillValid(async, cubit, 'f1', stop);
        final token = field(cubit, 'f1').sessionToken;

        cubit.onTextChanged('f1', stop.address);
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        final f = field(cubit, 'f1');
        expect(f.selected, stop);
        expect(f.isValid, isTrue);
        expect(f.suggestions, isEmpty);
        expect(f.loading, isFalse);
        expect(f.sessionToken, token);
        verifyNever(
          () => places.autocomplete(
            input: any(named: 'input'),
            sessionToken: any(named: 'sessionToken'),
            bias: bias,
          ),
        );
      });
    });

    test('details failure → field error, typed text and suggestions kept', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        stubAutocomplete(input: 'Av.', token: token);
        stubDetails(
          placeId: 'p1',
          token: token,
          result: const ApiFailure(500, 'boom'),
        );
        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        cubit.selectSuggestion('f1', suggestion);
        async.flushMicrotasks();

        final f = field(cubit, 'f1');
        expect(f.error, searchError);
        expect(f.text, 'Av.');
        expect(f.selected, isNull);
        expect(f.suggestions, [suggestion]);
        expect(f.loading, isFalse);
        expect(f.sessionToken, token);
      });
    });
  });

  group('non-Failure errors from the API (ADDR-11)', () {
    test('details throwing a TypeError → field error, loading off, text and '
        'suggestions kept', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        stubAutocomplete(input: 'Av.', token: token);
        when(() => places.details(placeId: 'p1', sessionToken: token))
            .thenThrow(TypeError());
        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        cubit.selectSuggestion('f1', suggestion);
        async.flushMicrotasks();

        final f = field(cubit, 'f1');
        expect(f.loading, isFalse);
        expect(f.error, searchError);
        expect(f.text, 'Av.');
        expect(f.selected, isNull);
        expect(f.suggestions, [suggestion]);
        expect(f.sessionToken, token);
      });
    });

    test('autocomplete throwing a StateError → field error, loading off, '
        'text kept', () {
      fakeAsync((async) {
        final cubit = build();
        final token = field(cubit, 'f1').sessionToken;
        when(
          () => places.autocomplete(
            input: 'Av.',
            sessionToken: token,
            bias: bias,
          ),
        ).thenThrow(StateError('bad'));
        cubit.onTextChanged('f1', 'Av.');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        final f = field(cubit, 'f1');
        expect(f.loading, isFalse);
        expect(f.error, searchError);
        expect(f.text, 'Av.');
      });
    });
  });

  group('addField / removeField', () {
    test('addField appends an empty field with a fresh id and token', () {
      final cubit = build();

      cubit.addField();

      expect(cubit.state.fields, hasLength(4));
      final added = cubit.state.fields.last;
      expect(added.id, 'f4');
      expect(added.text, '');
      expect(added.selected, isNull);
      expect(
        cubit.state.fields.map((f) => f.sessionToken).toSet(),
        hasLength(4),
      );
    });

    test('removeField drops an added field and ignores the first three', () {
      final cubit = build();
      cubit.addField();

      cubit.removeField('f1');
      expect(cubit.state.fields.map((f) => f.id), ['f1', 'f2', 'f3', 'f4']);

      cubit.removeField('f4');
      expect(cubit.state.fields.map((f) => f.id), ['f1', 'f2', 'f3']);
    });

    test('removing the field that held the duplicate clears "Endereço '
        'repetido" on the remaining one (edge case, ADDR-09)', () {
      fakeAsync((async) {
        final cubit = build();
        fillValid(async, cubit, 'f1', stopFor('a'));
        fillValid(async, cubit, 'f2', stopFor('b'));
        fillValid(async, cubit, 'f3', stopFor('c'));
        cubit.addField();
        cubit.addField();
        fillValid(async, cubit, 'f4', stopFor('d'));
        fillValid(async, cubit, 'f5', stopFor('d'));
        cubit.confirm();
        expect(field(cubit, 'f5').error, 'Endereço repetido');
        expect(cubit.state.submitted, isNull);

        cubit.removeField('f4');

        expect(cubit.state.fields.map((f) => f.id), ['f1', 'f2', 'f3', 'f5']);
        expect(field(cubit, 'f5').error, isNull);
        expect(cubit.state.canConfirm, isTrue);
      });
    });
  });

  group('confirm', () {
    test('three valid fields → submitted with the stops in order', () {
      fakeAsync((async) {
        final cubit = build();
        fillValid(async, cubit, 'f1', stopFor('a'));
        fillValid(async, cubit, 'f2', stopFor('b'));
        fillValid(async, cubit, 'f3', stopFor('c'));
        expect(cubit.state.canConfirm, isTrue);

        cubit.confirm();

        expect(cubit.state.submitted, [
          stopFor('a'),
          stopFor('b'),
          stopFor('c'),
        ]);
        expect(cubit.state.fields.every((f) => f.error == null), isTrue);
      });
    });

    test(
      'invalid form → validator errors in the fields, nothing submitted',
      () {
        fakeAsync((async) {
          final cubit = build();
          fillValid(async, cubit, 'f1', stopFor('a'));
          cubit.onTextChanged('f2', 'Rua sem seleção');

          cubit.confirm();

          expect(field(cubit, 'f1').error, isNull);
          expect(field(cubit, 'f2').error, 'Selecione um endereço da lista');
          expect(field(cubit, 'f3').error, 'Campo obrigatório');
          expect(cubit.state.submitted, isNull);
        });
      },
    );

    test('offline blocks confirmation even when every field is valid', () {
      fakeAsync((async) {
        final cubit = build();
        fillValid(async, cubit, 'f1', stopFor('a'));
        fillValid(async, cubit, 'f2', stopFor('b'));
        fillValid(async, cubit, 'f3', stopFor('c'));

        cubit.setOnline(false);
        expect(cubit.state.canConfirm, isFalse);
        cubit.setOnline(true);
        expect(cubit.state.canConfirm, isTrue);
      });
    });

    test('reset clears the submission and keeps the fields (ADDR-12)', () {
      fakeAsync((async) {
        final cubit = build();
        fillValid(async, cubit, 'f1', stopFor('a'));
        fillValid(async, cubit, 'f2', stopFor('b'));
        fillValid(async, cubit, 'f3', stopFor('c'));
        cubit.confirm();
        final fields = cubit.state.fields;

        cubit.reset();

        expect(cubit.state.submitted, isNull);
        expect(cubit.state.fields, fields);
        expect(cubit.state.fields.every((f) => f.isValid), isTrue);
      });
    });
  });
}

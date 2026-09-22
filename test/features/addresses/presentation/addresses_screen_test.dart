import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/core/widgets/rb_feedback.dart';
import 'package:routebreeze/core/widgets/rb_text_field.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/domain/address_field.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/addresses/domain/suggestion.dart';
import 'package:routebreeze/features/addresses/presentation/address_form_cubit.dart';
import 'package:routebreeze/features/addresses/presentation/addresses_screen.dart';

class MockAddressFormCubit extends MockCubit<AddressFormState>
    implements AddressFormCubit {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockPlacesApi extends Mock implements PlacesApi {}

void main() {
  const start = GeoPoint(-23.5614, -46.6559);
  const suggestion = Suggestion('p1', 'Avenida Paulista, 1000', 'São Paulo');
  Stop stopFor(String id) =>
      Stop(id, 'Endereço $id', const GeoPoint(-23.5, -46.6));
  AddressField empty(String id) => AddressField(id: id, sessionToken: 't-$id');
  AddressField valid(String id) => AddressField(
    id: id,
    sessionToken: 't-$id',
    text: 'Endereço $id',
    selected: stopFor(id),
  );
  final threeEmpty = [empty('f1'), empty('f2'), empty('f3')];
  final threeValid = [valid('f1'), valid('f2'), valid('f3')];

  late MockAddressFormCubit cubit;
  late MockConnectivityService connectivity;
  late StreamController<bool> online;
  late List<List<Stop>> confirmed;

  setUpAll(() => registerFallbackValue(suggestion));

  setUp(() {
    cubit = MockAddressFormCubit();
    connectivity = MockConnectivityService();
    online = StreamController<bool>();
    confirmed = [];
    when(() => connectivity.check()).thenAnswer((_) async => true);
    when(() => connectivity.isOnline).thenAnswer((_) => online.stream);
    when(() => cubit.setOnline(any())).thenReturn(null);
    when(() => cubit.onTextChanged(any(), any())).thenReturn(null);
    when(() => cubit.selectSuggestion(any(), any())).thenAnswer((_) async {});
    when(() => cubit.addField()).thenReturn(null);
    when(() => cubit.removeField(any())).thenReturn(null);
    when(() => cubit.confirm()).thenReturn(null);
    when(() => cubit.reset()).thenReturn(null);
  });

  tearDown(() => online.close());

  Future<void> pumpScreen(
    WidgetTester tester,
    AddressFormState state, {
    Stream<AddressFormState>? stream,
  }) async {
    whenListen(
      cubit,
      stream ?? const Stream<AddressFormState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AddressesScreen(
          start: start,
          cubit: cubit,
          connectivity: connectivity,
          onConfirmed: confirmed.add,
        ),
      ),
    );
    await tester.pump();
  }

  final confirmFinder = find.widgetWithText(RbPrimaryButton, 'Confirmar rota');
  RbPrimaryButton confirmButton(WidgetTester tester) =>
      tester.widget<RbPrimaryButton>(confirmFinder);

  List<String?> placeholders(WidgetTester tester) => tester
      .widgetList<RbTextField>(find.byType(RbTextField))
      .map((f) => f.placeholder)
      .toList();

  group('AddressesScreen', () {
    testWidgets('initial layout: title, three fields A/B/C, "Adicionar ponto" '
        'link, disabled "Confirmar rota" and the helper', (tester) async {
      await pumpScreen(tester, AddressFormState(fields: threeEmpty));

      final title = tester.widget<Text>(find.text('Para onde vamos?'));
      expect(title.style!.fontSize, 22);
      expect(title.style!.fontWeight, FontWeight.w700);
      expect(title.style!.color, RbColors.ink);

      expect(placeholders(tester), ['Ponto A', 'Ponto B', 'Ponto C']);
      expect(find.byIcon(Icons.close), findsNothing);

      final link = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Adicionar ponto'),
      );
      expect(link.style!.foregroundColor!.resolve({}), RbColors.brand);
      expect(link.style!.textStyle!.resolve({})!.fontWeight, FontWeight.w600);
      expect(link.style!.textStyle!.resolve({})!.fontSize, 15);
      expect(
        find.descendant(
          of: find.widgetWithText(TextButton, 'Adicionar ponto'),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );

      expect(confirmButton(tester).enabled, isFalse);
      final helper = tester.widget<Text>(
        find.text('Preencha os 3 endereços para continuar'),
      );
      expect(helper.style!.fontSize, 13);
      expect(helper.style!.color, RbColors.inkMuted);
      expect(find.text('Sem conexão'), findsNothing);
      verify(() => cubit.setOnline(true)).called(1);
    });

    testWidgets('shows the validation errors under their fields', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        AddressFormState(
          fields: [
            valid('f1'),
            empty('f2').copyWith(error: 'Campo obrigatório'),
            empty('f3')
                .copyWith(text: 'Rua', error: 'Selecione um endereço da lista'),
          ],
        ),
      );

      final errors = tester
          .widgetList<RbTextField>(find.byType(RbTextField))
          .map((f) => f.errorText)
          .toList();
      expect(errors, [
        null,
        'Campo obrigatório',
        'Selecione um endereço da lista',
      ]);
      expect(confirmButton(tester).enabled, isFalse);
    });

    testWidgets('valid state enables "Confirmar rota", hides the helper and '
        'confirms on tap', (tester) async {
      await pumpScreen(tester, AddressFormState(fields: threeValid));

      expect(confirmButton(tester).enabled, isTrue);
      expect(find.text('Preencha os 3 endereços para continuar'), findsNothing);

      await tester.tap(confirmFinder);
      await tester.pump();

      verify(() => cubit.confirm()).called(1);
    });

    testWidgets('"Adicionar ponto" adds a field; the added field gets the '
        'next letter and a remove control', (tester) async {
      await pumpScreen(
        tester,
        AddressFormState(fields: [...threeEmpty, empty('f4')]),
      );

      expect(placeholders(tester), [
        'Ponto A',
        'Ponto B',
        'Ponto C',
        'Ponto D',
      ]);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.text('Adicionar ponto'));
      await tester.pump();
      verify(() => cubit.addField()).called(1);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      verify(() => cubit.removeField('f4')).called(1);
    });

    testWidgets('typing forwards to onTextChanged and a tapped suggestion '
        'to selectSuggestion', (tester) async {
      await pumpScreen(
        tester,
        AddressFormState(
          fields: [
            empty('f1').copyWith(text: 'Av.', suggestions: [suggestion]),
            empty('f2'),
            empty('f3'),
          ],
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Av. P');
      verify(() => cubit.onTextChanged('f1', 'Av. P')).called(1);

      await tester.tap(find.text('Avenida Paulista, 1000'));
      await tester.pump();
      verify(() => cubit.selectSuggestion('f1', suggestion)).called(1);
    });

    testWidgets('offline: "Sem conexão" danger banner on top and the button '
        'stays disabled even with valid fields', (tester) async {
      await pumpScreen(
        tester,
        AddressFormState(fields: threeValid, online: false),
      );

      final banner = tester.widget<RbBanner>(find.byType(RbBanner));
      expect(banner.text, 'Sem conexão');
      expect(banner.tone, RbTone.danger);
      final bannerBox = tester.getTopLeft(find.byType(RbBanner));
      final titleBox = tester.getTopLeft(find.text('Para onde vamos?'));
      expect(bannerBox.dy, lessThan(titleBox.dy));
      expect(confirmButton(tester).enabled, isFalse);
    });

    testWidgets('connectivity changes reach the cubit', (tester) async {
      await pumpScreen(tester, AddressFormState(fields: threeEmpty));

      online.add(false);
      await tester.pump();
      verify(() => cubit.setOnline(false)).called(1);

      online.add(true);
      await tester.pump();
      verify(() => cubit.setOnline(true)).called(2);
    });

    testWidgets('a connectivity check that answers after the screen is gone '
        'does not touch the closed cubit', (tester) async {
      final realCubit = AddressFormCubit(MockPlacesApi(), bias: start);
      final check = Completer<bool>();
      when(() => connectivity.check()).thenAnswer((_) => check.future);
      await tester.pumpWidget(
        MaterialApp(
          home: AddressesScreen(
            start: start,
            cubit: realCubit,
            connectivity: connectivity,
            onConfirmed: confirmed.add,
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await realCubit.close();
      check.complete(false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(realCubit.state.online, isTrue);
    });

    testWidgets('submitted stops reach onConfirmed once and the cubit is '
        'reset', (tester) async {
      final stops = [stopFor('a'), stopFor('b'), stopFor('c')];
      await pumpScreen(
        tester,
        AddressFormState(fields: threeValid),
        stream: Stream.fromIterable([
          AddressFormState(fields: threeValid, submitted: stops),
        ]),
      );
      await tester.pump();

      expect(confirmed, [stops]);
      verify(() => cubit.reset()).called(1);
    });
  });
}

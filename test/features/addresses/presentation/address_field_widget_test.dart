import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_text_field.dart';
import 'package:routebreeze/features/addresses/domain/address_field.dart';
import 'package:routebreeze/features/addresses/domain/suggestion.dart';
import 'package:routebreeze/features/addresses/presentation/address_field_widget.dart';

void main() {
  const s1 = Suggestion('p1', 'Avenida Paulista, 1000', 'São Paulo - SP');
  const s2 = Suggestion('p2', 'Praça da Sé', '');

  late List<String> changes;
  late List<Suggestion> selections;
  late int removals;

  setUp(() {
    changes = [];
    selections = [];
    removals = 0;
  });

  Widget wrap(AddressField field, {bool removable = false}) => MaterialApp(
    home: Scaffold(
      body: AddressFieldWidget(
        field: field,
        placeholder: 'Ponto A',
        onChanged: changes.add,
        onSuggestionSelected: selections.add,
        onRemove: removable ? () => removals++ : null,
      ),
    ),
  );

  RbTextField textField(WidgetTester tester) =>
      tester.widget<RbTextField>(find.byType(RbTextField));

  group('AddressFieldWidget', () {
    testWidgets('renders the placeholder, forwards typing and shows no '
        'remove control or suggestions by default', (tester) async {
      await tester.pumpWidget(
        wrap(const AddressField(id: 'f1', sessionToken: 't')),
      );

      expect(textField(tester).placeholder, 'Ponto A');
      expect(textField(tester).errorText, isNull);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(ListTile), findsNothing);

      await tester.enterText(find.byType(TextField), 'Av. P');

      expect(changes, ['Av. P']);
    });

    testWidgets('caps the input at 200 characters', (tester) async {
      await tester.pumpWidget(
        wrap(const AddressField(id: 'f1', sessionToken: 't')),
      );

      await tester.enterText(find.byType(TextField), 'x' * 201);
      await tester.pump();

      expect(textField(tester).maxLength, 200);
      expect(changes.last.length, 200);
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .length,
        200,
      );
    });

    testWidgets('shows the field error under the input', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AddressField(
            id: 'f1',
            sessionToken: 't',
            error: 'Campo obrigatório',
          ),
        ),
      );

      expect(textField(tester).errorText, 'Campo obrigatório');
      final message = tester.widget<Text>(find.text('Campo obrigatório'));
      expect(message.style!.color, RbColors.danger);
      expect(message.style!.fontSize, 13);
    });

    testWidgets('lists the suggestions in a surface-200 card and reports '
        'the tapped one', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AddressField(
            id: 'f1',
            sessionToken: 't',
            text: 'Av.',
            suggestions: [s1, s2],
          ),
        ),
      );

      expect(find.byType(ListTile), findsNWidgets(2));
      final main = tester.widget<Text>(find.text('Avenida Paulista, 1000'));
      expect(main.style!.fontWeight, FontWeight.w600);
      expect(main.style!.color, RbColors.ink);
      final secondary = tester.widget<Text>(find.text('São Paulo - SP'));
      expect(secondary.style!.fontSize, 13);
      expect(secondary.style!.color, RbColors.inkMuted);
      final card = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(ListTile),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, RbColors.surface200);
      expect(
        (card.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );

      await tester.tap(find.text('Praça da Sé'));
      await tester.pump();

      expect(selections, [s2]);
    });

    testWidgets('removable field shows the close control that calls '
        'onRemove', (tester) async {
      await tester.pumpWidget(
        wrap(const AddressField(id: 'f4', sessionToken: 't'), removable: true),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removals, 1);
    });

    testWidgets('loading shows a spinner as trailing', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AddressField(
            id: 'f1',
            sessionToken: 't',
            text: 'Av.',
            loading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('an external text update (selection) replaces the input '
        'text', (tester) async {
      await tester.pumpWidget(
        wrap(const AddressField(id: 'f1', sessionToken: 't', text: 'Av.')),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Av.',
      );

      await tester.pumpWidget(
        wrap(
          const AddressField(
            id: 'f1',
            sessionToken: 't2',
            text: 'Av. Paulista, 1000 - São Paulo',
          ),
        ),
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Av. Paulista, 1000 - São Paulo',
      );
      expect(changes, isEmpty);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'accessibility.dart';

void main() {
  group('expectNoClippedText', () {
    // Several lines at 100 px wide.
    const text = 'Rua Augusta, 500, Consolação';

    Future<void> pumpText(WidgetTester tester, Widget child) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: SizedBox(width: 100, child: child)),
            ),
          ),
        );

    testWidgets('fails on a paragraph cut by a fixed-height box', (
      tester,
    ) async {
      await pumpText(tester, const SizedBox(height: 20, child: Text(text)));

      expect(() => expectNoClippedText(tester), throwsA(isA<TestFailure>()));
    });

    testWidgets('fails on a paragraph cut by a line limit without an '
        'ellipsis', (tester) async {
      await pumpText(tester, const Text(text, maxLines: 2));

      expect(() => expectNoClippedText(tester), throwsA(isA<TestFailure>()));
    });

    testWidgets('passes on a two-line paragraph that ends in an ellipsis', (
      tester,
    ) async {
      await pumpText(
        tester,
        const Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      );
      expect(
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
        isTrue,
      );

      expectNoClippedText(tester);
    });
  });
}

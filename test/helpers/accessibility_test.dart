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

    testWidgets('fails on a paragraph cut sideways', (tester) async {
      await pumpText(tester, const Text(text, softWrap: false));

      expect(() => expectNoClippedText(tester), throwsA(isA<TestFailure>()));
    });

    Future<Size> oneLineSize(WidgetTester tester) async {
      await pumpText(tester, const Text('Rua'));
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Rua'));
      return Size(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        paragraph.getMaxIntrinsicHeight(double.infinity),
      );
    }

    testWidgets('fails on a line cut 2 px short of its height', (tester) async {
      final line = await oneLineSize(tester);
      await pumpText(
        tester,
        Center(
          child: SizedBox(height: line.height - 2, child: const Text('Rua')),
        ),
      );

      expect(() => expectNoClippedText(tester), throwsA(isA<TestFailure>()));
    });

    testWidgets('fails on a line that does not wrap, 2 px wider than its '
        'box', (tester) async {
      final line = await oneLineSize(tester);
      await pumpText(
        tester,
        Center(
          child: SizedBox(
            width: line.width - 2,
            child: const Text('Rua', softWrap: false),
          ),
        ),
      );

      expect(() => expectNoClippedText(tester), throwsA(isA<TestFailure>()));
    });

    testWidgets('passes on a line in a box of exactly its size', (
      tester,
    ) async {
      final line = await oneLineSize(tester);
      await pumpText(
        tester,
        Center(
          child: SizedBox.fromSize(
            size: line,
            child: const Text('Rua', softWrap: false),
          ),
        ),
      );

      expectNoClippedText(tester);
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

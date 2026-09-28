import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks the current tree against Flutter's text contrast, Android and iOS
/// tap target and labeled tap target guidelines. Settle animations first:
/// the contrast check samples the rendered pixels.
Future<void> expectAccessibleGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

/// A 360×800 dp phone with the system text at 200%, both reset on tear-down.
/// Call it before pumping the screen.
Future<void> setLargeTextPhone(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(360, 800);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Fails when a laid-out paragraph is shorter than its text at its width:
/// cut by a fixed-height parent, which raises no overflow error, or by a line
/// limit without an ellipsis. A paragraph with a line limit and an ellipsis
/// counts as its visible lines.
void expectNoClippedText(WidgetTester tester) {
  final clipped = [
    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    ))
      if (paragraph.size.height < paragraph.textSize.height - _clipTolerance ||
          (paragraph.didExceedMaxLines &&
              paragraph.overflow != TextOverflow.ellipsis))
        '"${paragraph.text.toPlainText()}" in ${paragraph.size}',
  ];
  expect(clipped, isEmpty, reason: 'clipped text');
}

/// Height, in logical pixels, a paragraph may lose to rounding.
const double _clipTolerance = 0.5;

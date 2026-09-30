import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/widgets/measure_size.dart';

void main() {
  late List<Size> reported;

  setUp(() => reported = []);

  Widget box(double height, {double width = 100}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: MeasureSize(
        onChange: reported.add,
        child: SizedBox(width: width, height: height),
      ),
    ),
  );

  group('MeasureSize', () {
    testWidgets('reports the first layout after the frame', (tester) async {
      await tester.pumpWidget(box(40));

      expect(reported, [const Size(100, 40)]);
    });

    testWidgets('reports again only when the size changes', (tester) async {
      await tester.pumpWidget(box(40));
      await tester.pumpWidget(box(40));
      await tester.pumpWidget(box(64));
      await tester.pumpWidget(box(64));

      expect(reported, [const Size(100, 40), const Size(100, 64)]);
    });

    testWidgets('a callback replaced on rebuild gets the next change', (
      tester,
    ) async {
      final second = <Size>[];
      await tester.pumpWidget(box(40));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: MeasureSize(
              onChange: second.add,
              child: const SizedBox(width: 100, height: 80),
            ),
          ),
        ),
      );

      expect(reported, [const Size(100, 40)]);
      expect(second, [const Size(100, 80)]);
    });
  });
}

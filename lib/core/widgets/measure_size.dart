import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports its child's size after every layout that changes it (the first
/// one included), once that frame is done. Screens use it to tell the map
/// how much of it an overlay covers.
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onChange, super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderMeasureSize createRenderObject(BuildContext context) =>
      RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasureSize renderObject,
  ) => renderObject.onChange = onChange;
}

class RenderMeasureSize extends RenderProxyBox {
  RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    if (measured == _reported) return;
    _reported = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}

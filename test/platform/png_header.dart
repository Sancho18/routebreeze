import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Width, height and color type from a PNG's IHDR chunk. Color type 2 is RGB
/// (no alpha), 6 is RGBA.
({int width, int height, int colorType}) pngHeader(String path) {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  return (
    width: bytes.getUint32(16),
    height: bytes.getUint32(20),
    colorType: bytes.getUint8(25),
  );
}

/// RGBA of the pixel at ([x], [y]) of the PNG at [path].
Future<List<int>> pngPixel(String path, int x, int y) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * image.width + x) * 4;
  image.dispose();
  return [for (var c = 0; c < 4; c++) rgba.getUint8(i + c)];
}

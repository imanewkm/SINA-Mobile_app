import 'dart:typed_data';

/// YUV420 → packed RGB conversion, isolated as a **pure** function (no plugins)
/// so it is unit-testable and free of per-pixel object/method overhead.
///
/// Uses integer fixed-point BT.601 (JFIF full-range) math — the per-frame hot
/// path — instead of floating-point multiplies + round + clamp. Coefficients are
/// the full-range constants scaled by 256 (`<<8`):
///   r = y + 1.402·v'            ≈ y + (359·v') >> 8
///   g = y − 0.344·u' − 0.714·v' ≈ y − (88·u' + 183·v') >> 8
///   b = y + 1.772·u'            ≈ y + (454·u') >> 8     (u'=u−128, v'=v−128)
///
/// Returns a `width*height*3` buffer, row-major, channel-interleaved (R,G,B).
Uint8List yuv420ToRgbBytes({
  required int width,
  required int height,
  required Uint8List yBytes,
  required Uint8List uBytes,
  required Uint8List vBytes,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
}) {
  final rgb = Uint8List(width * height * 3);
  int o = 0;
  for (int y = 0; y < height; y++) {
    final yRow = y * yRowStride;
    final uvRow = (y >> 1) * uvRowStride;
    for (int x = 0; x < width; x++) {
      final yp = yBytes[yRow + x];
      final uvCol = (x >> 1) * uvPixelStride;
      final up = uBytes[uvRow + uvCol] - 128;
      final vp = vBytes[uvRow + uvCol] - 128;

      final r = yp + ((359 * vp) >> 8);
      final g = yp - ((88 * up + 183 * vp) >> 8);
      final b = yp + ((454 * up) >> 8);

      rgb[o++] = r < 0 ? 0 : (r > 255 ? 255 : r);
      rgb[o++] = g < 0 ? 0 : (g > 255 ? 255 : g);
      rgb[o++] = b < 0 ? 0 : (b > 255 ? 255 : b);
    }
  }
  return rgb;
}

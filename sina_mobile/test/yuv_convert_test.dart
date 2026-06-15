// Integer fixed-point YUV420 -> RGB conversion (the per-frame hot path).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sina_mobile/services/yuv_convert.dart';

/// First pixel (R,G,B) of a 2x2 frame with uniform luma [y] and one chroma
/// sample (u,v) shared by all pixels.
List<int> firstPixel(int y, int u, int v) {
  final rgb = yuv420ToRgbBytes(
    width: 2,
    height: 2,
    yBytes: Uint8List.fromList([y, y, y, y]),
    uBytes: Uint8List.fromList([u]),
    vBytes: Uint8List.fromList([v]),
    yRowStride: 2,
    uvRowStride: 1,
    uvPixelStride: 1,
  );
  return [rgb[0], rgb[1], rgb[2]];
}

void main() {
  group('yuv420ToRgbBytes', () {
    test('output buffer is width*height*3', () {
      final rgb = yuv420ToRgbBytes(
        width: 2,
        height: 2,
        yBytes: Uint8List.fromList([10, 20, 30, 40]),
        uBytes: Uint8List.fromList([128]),
        vBytes: Uint8List.fromList([128]),
        yRowStride: 2,
        uvRowStride: 1,
        uvPixelStride: 1,
      );
      expect(rgb.length, 2 * 2 * 3);
    });

    test('neutral chroma → grayscale equal to luma', () {
      expect(firstPixel(128, 128, 128), [128, 128, 128]);
      expect(firstPixel(255, 128, 128), [255, 255, 255]); // white
      expect(firstPixel(0, 128, 128), [0, 0, 0]); // black
    });

    test('red-dominant YUV decodes to a red pixel', () {
      final p = firstPixel(82, 90, 240); // classic "red" sample
      expect(p[0], greaterThan(200)); // R high
      expect(p[1], lessThan(40)); // G low
      expect(p[2], lessThan(40)); // B low
    });

    test('clamps out-of-range results to [0,255]', () {
      expect(firstPixel(255, 128, 255)[0], 255); // would overflow → 255
      expect(firstPixel(0, 128, 0)[0], 0); // would go negative → 0
    });

    test('luma maps row-major across the frame', () {
      final rgb = yuv420ToRgbBytes(
        width: 2,
        height: 2,
        yBytes: Uint8List.fromList([10, 20, 30, 40]),
        uBytes: Uint8List.fromList([128]),
        vBytes: Uint8List.fromList([128]),
        yRowStride: 2,
        uvRowStride: 1,
        uvPixelStride: 1,
      );
      // Neutral chroma → each pixel's channels equal its luma.
      expect(rgb[0], 10); // (0,0)
      expect(rgb[3], 20); // (1,0)
      expect(rgb[6], 30); // (0,1)
      expect(rgb[9], 40); // (1,1)
    });
  });
}

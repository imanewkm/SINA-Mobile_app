// int8 / uint8 quantization helpers for running quantized TFLite models.

import 'package:flutter_test/flutter_test.dart';
import 'package:sina_mobile/services/quant.dart';

void main() {
  group('quantizeInt8', () {
    // A common YOLO int8 input tensor: scale 1/255, zero_point -128 → maps the
    // normalized [0,1] range onto the full int8 range [-128,127].
    const scale = 1 / 255;
    const zero = -128;

    test('maps the [0,1] range across int8', () {
      expect(quantizeInt8(0.0, scale, zero), -128);
      expect(quantizeInt8(1.0, scale, zero), 127);
      expect(quantizeInt8(0.5, scale, zero), closeTo(0, 1)); // ~ -0.5 → 0/-1
    });

    test('clamps out-of-range reals to the int8 limits', () {
      expect(quantizeInt8(2.0, scale, zero), 127);
      expect(quantizeInt8(-1.0, scale, zero), -128);
    });

    test('non-positive scale is treated as the zero point', () {
      expect(quantizeInt8(0.7, 0, 5), 5);
    });
  });

  group('quantizeUint8', () {
    // uint8 input: scale 1/255, zero_point 0 → byte value directly.
    const scale = 1 / 255;
    const zero = 0;

    test('maps the [0,1] range across uint8', () {
      expect(quantizeUint8(0.0, scale, zero), 0);
      expect(quantizeUint8(1.0, scale, zero), 255);
    });

    test('clamps to [0,255]', () {
      expect(quantizeUint8(2.0, scale, zero), 255);
      expect(quantizeUint8(-0.5, scale, zero), 0);
    });
  });

  group('dequantize', () {
    test('inverts quantization', () {
      expect(dequantize(0, 0.1, 0), closeTo(0.0, 1e-9));
      expect(dequantize(10, 0.1, 0), closeTo(1.0, 1e-9));
      expect(dequantize(-118, 1 / 255, -128), closeTo(10 / 255, 1e-9));
    });

    test('round-trips with quantizeInt8 within one step', () {
      const scale = 0.02;
      const zero = -10;
      for (final real in [0.0, 0.25, 0.5, 0.9]) {
        final q = quantizeInt8(real, scale, zero);
        final back = dequantize(q, scale, zero);
        expect(back, closeTo(real, scale)); // within one quantization step
      }
    });
  });
}

/// Integer quantization helpers for running int8 / uint8 TFLite models.
///
/// tflite_flutter copies raw bytes by tensor dtype and does **no** automatic
/// (de)quantization, so a quantized model needs its float input quantized and
/// its integer output dequantized using each tensor's affine params
/// (`scale`, `zeroPoint`):  q = round(real / scale) + zeroPoint  /  real =
/// (q − zeroPoint) · scale.  Pure (no plugins) so it is unit-testable.
library;

int _clampInt8(int v) => v < -128 ? -128 : (v > 127 ? 127 : v);
int _clampUint8(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

/// Quantize [real] to int8 for a tensor with [scale]/[zeroPoint].
/// A non-positive scale (no/invalid quantization) maps to the zero point.
int quantizeInt8(double real, double scale, int zeroPoint) {
  if (scale <= 0) return _clampInt8(zeroPoint);
  return _clampInt8((real / scale).round() + zeroPoint);
}

/// Quantize [real] to uint8 for a tensor with [scale]/[zeroPoint].
int quantizeUint8(double real, double scale, int zeroPoint) {
  if (scale <= 0) return _clampUint8(zeroPoint);
  return _clampUint8((real / scale).round() + zeroPoint);
}

/// Dequantize a stored integer [q] back to a real value.
double dequantize(num q, double scale, int zeroPoint) =>
    (q - zeroPoint) * scale;

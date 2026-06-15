// Monocular depth relative-value → metres conversion + calibration invariants.

import 'package:flutter_test/flutter_test.dart';
import 'package:sina_mobile/constants/depth_config.dart';

void main() {
  group('depthValueToMeters', () {
    test('defaults target an inverse-depth model (MiDaS-style)', () {
      expect(kDepthIsInverse, isTrue);
    });

    test('inverse mapping is consistent with the scale constant', () {
      // metres = kDepthScale / raw, so raw == kDepthScale -> 1 m.
      expect(depthValueToMeters(kDepthScale), closeTo(1.0, 1e-9));
      expect(depthValueToMeters(kDepthScale / 2), closeTo(2.0, 1e-9));
      expect(depthValueToMeters(kDepthScale / 4), closeTo(4.0, 1e-9));
    });

    test('nearer (larger raw) reads as a smaller distance', () {
      final near = depthValueToMeters(kDepthScale); // raw high
      final far = depthValueToMeters(kDepthScale / 5); // raw low
      expect(near, lessThan(far));
    });

    test('invalid / unknown samples return non-positive (use heuristic)', () {
      expect(depthValueToMeters(0), lessThanOrEqualTo(0));
      expect(depthValueToMeters(-3), lessThanOrEqualTo(0));
      expect(depthValueToMeters(double.nan), lessThanOrEqualTo(0));
      expect(depthValueToMeters(double.infinity), lessThanOrEqualTo(0));
    });
  });
}

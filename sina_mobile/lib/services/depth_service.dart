import 'package:flutter/services.dart';

/// Optional depth provider (Android / ARCore). When a native depth source is
/// wired (see docs/arcore_depth.md), this returns per-point distance in metres
/// so SINA's distance tiers come from real depth instead of the bounding-box
/// area heuristic. Degrades gracefully to "unavailable" — the app then keeps
/// using the heuristic with no behaviour change.
class DepthService {
  static const MethodChannel _ch = MethodChannel('com.sina.mobility/depth');

  bool _available = false;
  bool get isAvailable => _available;

  Future<void> init() async {
    try {
      _available = (await _ch.invokeMethod<bool>('isAvailable')) ?? false;
    } catch (_) {
      _available = false; // no native handler / not ARCore-capable
    }
  }

  /// Depth (metres) at normalized points — (0,0) top-left … (1,1) bottom-right.
  /// Returns a list parallel to [points]; a non-positive value means "unknown".
  /// Returns an empty list when depth is unavailable.
  Future<List<double>> depthAt(List<Offset> points) async {
    if (!_available || points.isEmpty) return const [];
    try {
      final flat = <double>[];
      for (final p in points) {
        flat.add(p.dx);
        flat.add(p.dy);
      }
      final res =
          await _ch.invokeMethod<List<dynamic>>('queryDepth', {'points': flat});
      if (res == null) return const [];
      return res.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return const [];
    }
  }

  void dispose() {}
}

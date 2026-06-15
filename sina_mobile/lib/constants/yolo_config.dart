/// YOLOv8 detection configuration — ported from app.py.
///
/// The model is COCO-pretrained yolov8n (80 classes); SINA only cares about
/// 11 mobility-relevant classes.
library;

import 'dart:math' as math;

/// Path to the bundled TFLite model (see assets/models/README.md).
const String kModelAsset = 'assets/models/yolov8n.tflite';

/// Model input side length (square). Matches `imgsz=320` export.
const int kInputSize = 320;

/// IoU threshold for non-maximum suppression.
const double kNmsIoU = 0.45;

/// Default confidence threshold (sensitivity 2 / normal).
const double kDefaultConf = 0.5;

/// Minimum seconds between spoken detection announcements (cooldown).
const double kDetectionCooldownSec = 2.0;

/// Minimum milliseconds between inference attempts. Inference runs on a worker
/// isolate and drops frames while busy, so this is a light cap, not the limiter.
const int kInferenceThrottleMs = 120;

/// Above this many distinct objects → speak a "many obstacles" summary.
const int kManyObstaclesThreshold = 5;

/// Lowest confidence at which an *unnamed* "object detected" warning is spoken.
/// Detections between this floor and the sensitivity threshold are announced
/// generically — and only when near (see app_controller) — instead of dropped.
const double kUncertainObjectFloor = 0.25;

/// Confidence floor for generic (unnamed) detection, given the active naming
/// [threshold]. Sits ~0.2 below it, never under [kUncertainObjectFloor].
double genericConfidenceFor(double threshold) {
  final floor = threshold - 0.20;
  return floor < kUncertainObjectFloor ? kUncertainObjectFloor : floor;
}

/// Class index of "traffic light" in the *active* model — used by the colour
/// classifier and the crossing announcer. Emitted by Section 7 of the Colab
/// notebook for the active model (custom navigation model = 16).
const int kTrafficLightClassId = 16;

/// Class IDs to announce. Defaults to all classes of the custom navigation
/// model. You can trim low-value / weak performers here (e.g. 5 crutch,
/// 15 street light, 18 tree) without retraining.
const Set<int> targetClassIds = {
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
  22, 23
};

/// Model class index → canonical English label. Must match the trained model's
/// class order (Section 7 of the Colab notebook prints this exactly). Keys here
/// must match the entries in labels.dart.
const Map<int, String> cocoLabels = {
  0: 'bench',
  1: 'bicycle',
  2: 'bus',
  3: 'bus stop',
  4: 'car',
  5: 'crutch',
  6: 'curb',
  7: 'dog',
  8: 'fire hydrant',
  9: 'motorcycle',
  10: 'person',
  11: 'pole',
  12: 'spherical roadblock',
  13: 'stairs',
  14: 'stop sign',
  15: 'street light',
  16: 'traffic light',
  17: 'train',
  18: 'tree',
  19: 'truck',
  20: 'warning column',
  21: 'waste container',
  22: 'door',
  23: 'crosswalk',
};

/// Detection sensitivity (1=quiet, 2=normal, 3=noisy) → confidence threshold.
double confidenceForSensitivity(int sensitivity) {
  switch (sensitivity) {
    case 1:
      return 0.60;
    case 3:
      return 0.40;
    case 2:
    default:
      return 0.50;
  }
}

/// Distance rank ordering (closest first) — used to keep the closest instance
/// of each label, mirroring `list(DIST_LABELS).index(...)` in app.py.
const List<String> distanceRank = ['very_close', 'close', 'medium', 'far'];

int distanceRankIndex(String dist) {
  final i = distanceRank.indexOf(dist);
  return i < 0 ? distanceRank.length : i;
}

/// Map a real distance in metres (e.g. from ARCore depth) to a SINA tier.
/// Mirrors the spoken thresholds: <1m stop, 1–2m close, 2–4m medium, >4m far.
String distanceTierFromMeters(double m) {
  if (m <= 0) return 'far'; // invalid/unknown → treat as no immediate danger
  if (m < 1.0) return 'very_close';
  if (m < 2.0) return 'close';
  if (m < 4.0) return 'medium';
  return 'far';
}

/// Distance estimation from bounding-box area ratio (port of _estimate_distance).
/// Class-agnostic last resort — [distanceFromBoxArea] supersedes it when the
/// object's class size is known.
String estimateDistance(
    double x1, double y1, double x2, double y2, int frameW, int frameH) {
  final ratio = ((x2 - x1) * (y2 - y1)) / (frameW * frameH);
  if (ratio > 0.20) return 'very_close';
  if (ratio > 0.06) return 'close';
  if (ratio > 0.01) return 'medium';
  return 'far';
}

// ── Class-aware monocular distance ───────────────────────────────────────────

/// Camera constant C = 1 / (4·tan(FoVx/2)·tan(FoVy/2)) for a typical phone back
/// camera (~65°×51°). Scales all distances uniformly — tune it (or the per-class
/// areas) on-device. Only the product C·area matters per class.
const double kCameraAreaConst = 0.82;

/// Approximate real frontal bounding-box area (m²) per class. Rough values: they
/// only need to rank distance into the four coarse tiers. Because the estimate
/// uses **box area**, it is invariant to sensor/device rotation (the raw camera
/// frame is landscape while the phone is held portrait).
const Map<String, double> kClassFrontalArea = {
  'person': 0.7,
  'bicycle': 0.8,
  'car': 3.0,
  'motorcycle': 1.2,
  'bus': 7.5,
  'truck': 8.0,
  'train': 10.0,
  'dog': 0.25,
  'bench': 1.0,
  'pole': 0.35,
  'tree': 4.0,
  'crutch': 0.15,
  'bus stop': 4.0,
  'curb': 0.3,
  'fire hydrant': 0.2,
  'spherical roadblock': 0.25,
  'stairs': 1.5,
  'stop sign': 0.5,
  'street light': 1.0,
  'traffic light': 0.3,
  'warning column': 0.3,
  'waste container': 0.6,
  'door': 1.8,
  'crosswalk': 4.0,
};

/// Class-aware distance in metres from a box's normalized area and the object's
/// known real area: d = sqrt(C·A / area_ratio). Returns a non-positive value
/// (unknown) for a zero-area box or a class with no known size, so callers fall
/// back to [estimateDistance].
double distanceFromBoxArea(
    String label, double x1, double y1, double x2, double y2) {
  final areaRatio = (x2 - x1) * (y2 - y1);
  final area = kClassFrontalArea[label];
  if (area == null || areaRatio <= 0) return -1;
  return math.sqrt(kCameraAreaConst * area / areaRatio);
}

/// Position estimation from x-center (port of _estimate_position).
String estimatePosition(double x1, double x2, int frameW) {
  final xCenter = (x1 + x2) / 2;
  final rel = xCenter / frameW;
  if (rel < 0.35) return 'left';
  if (rel > 0.65) return 'right';
  return 'center';
}

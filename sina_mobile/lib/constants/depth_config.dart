/// Monocular depth model configuration.
///
/// When `assets/models/depth.tflite` is bundled, a small monocular depth model
/// (MiDaS-small / Depth-Anything-small, int8/float16) runs in the *same*
/// detector isolate, on the *same* RGB frame as YOLO, and provides per-object
/// distance — overriding the bounding-box area heuristic. When the asset is
/// absent the pipeline is silently disabled (exactly like the YOLO model), so
/// the app keeps working with the heuristic and nothing changes.
///
/// Distance-source priority (see AppController._onFrame):
///   1. native ARCore/ARKit metres  (com.sina.mobility/depth, if > 0)
///   2. monocular model metres       (this file, if a model is loaded)
///   3. area-ratio heuristic         (always available)
library;

/// Path to the optional monocular depth model. Absent → monocular depth off.
/// Defaults below target **MiDaS v2.1 small** (256×256, ImageNet-normalized,
/// inverse relative depth). Install/verify it with:
///   `python scripts/export_depth_tflite.py --input <midas_small.tflite>`
const String kDepthModelAsset = 'assets/models/depth.tflite';

/// Square input side for the depth model. MiDaS-small / Depth-Anything-small
/// commonly use 256. The RGB frame is stretch-resized to this (normalized box
/// centres still map directly, since both span the full original frame).
const int kDepthInputSize = 256;

/// ImageNet normalization. MiDaS / Depth-Anything expect it; set false for a
/// model trained on plain 0–1 input.
const bool kDepthNormalize = true;
const List<double> kDepthMean = [0.485, 0.456, 0.406];
const List<double> kDepthStd = [0.229, 0.224, 0.225];

/// Most monocular models output *inverse* relative depth (larger = nearer).
/// Set false if the model outputs forward depth (larger = farther).
const bool kDepthIsInverse = true;

/// Calibration constant mapping the model's relative output to metres. The
/// default is an **uncalibrated ballpark for MiDaS-small** (whose inverse-depth
/// output lands in the low hundreds); it MUST be tuned once on-device. Point at
/// an object at a known distance, read `depth raw:` from the debug HUD, then:
///   `python scripts/export_depth_tflite.py --calibrate --raw <hud> --meters <m>`
/// and paste the printed value here. SINA only needs coarse tiers
/// (<1, 1–2, 2–4, >4 m), so one reference point is enough.
const double kDepthScale = 300.0;

/// Convert a raw model value [v] (relative, possibly inverse) sampled at a box
/// centre into approximate metres. Returns <= 0 for invalid / unknown samples
/// (the distance tier mapper treats <= 0 as "use the heuristic / far").
double depthValueToMeters(double v) {
  if (v <= 0 || v.isNaN || v.isInfinite) return -1.0;
  return kDepthIsInverse ? kDepthScale / v : kDepthScale * v;
}

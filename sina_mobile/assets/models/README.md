# YOLOv8n TFLite model

The app loads `assets/models/yolov8n.tflite` at runtime. If the file is
absent, the app still runs (camera preview, voice, GPS, SOS all work) but
object detection is disabled and SINA will say nothing about obstacles.

## Get / regenerate the model

Use the helper script from the repo root:

```bash
pip install ultralytics
python scripts/export_tflite.py          # float16 (default) — ~6 MB, GPU-friendly
python scripts/export_tflite.py --int8   # int8 — ~3 MB, see caveat below
```

The script exports from `yolov8n.pt` and copies the result here.

### float16 vs int8
- **float16 (default, recommended):** half the size of float32, works well with
  the GPU delegate, and keeps **float32 input/output** so the Dart decoder in
  `lib/services/detector_service.dart` uses the plain float path.
- **int8 (now supported):** smallest (~3–4 MB) and fastest on CPU/NNAPI. Its
  input/output tensors are quantized integers, and the detector **auto-detects
  this** (`Tensor.type`/`params`) and quantizes the input / dequantizes the
  output (`services/quant.dart`) — no code change to swap models. The HUD shows
  `model:OK-int8`. Full int8 needs a **representative dataset** for calibration:
  ```python
  # Colab / Linux (the TF converter does not install on Windows):
  from ultralytics import YOLO
  YOLO('yolov8n.pt').export(format='tflite', imgsz=320, int8=True, data='data.yaml')
  ```
  Accuracy can drop a little vs float16 — verify detections on-device. The Colab
  notebook's verify cell hard-asserts float32; relax it to accept int8/uint8.

## Expected tensor shapes
- Input:  `[1, 320, 320, 3]` — float32 (0–1) for a float model, or int8/uint8
  (quantized) for an int8 model. RGB, letterboxed.
- Output: `[1, 84, 2100]` (84 = 4 bbox + 80 class scores, 2100 candidate boxes);
  float32 or quantized int8/uint8 (dequantized in `_decode`).
  - Some exports produce `[1, 2100, 84]`; the detector handles both orientations.

---

# Monocular depth model (optional) — `assets/models/depth.tflite`

Bundle a small monocular depth model here to give SINA **real per-object
distance** instead of the bounding-box-area estimate. It runs in the *same*
detector isolate, on the *same* RGB frame as YOLO, so there is no extra camera
or isolate. If the file is absent, depth is silently disabled and distance falls
back to the area heuristic (no behaviour change).

Distance-source priority (`AppController._onFrame`):
1. native ARCore / ARKit metres (`com.sina.mobility/depth`, when > 0)
2. this monocular model's metres (when `depth.tflite` is loaded)
3. area-ratio heuristic (always)

## Get a model
Use an int8 / float16 TFLite of **MiDaS-small** (recommended) or
**Depth-Anything-small** at 256×256. Any single-channel relative-depth output
works; the decoder (`_DepthMap` in `detector_service.dart`) auto-detects
`[1,H,W]`, `[1,H,W,1]` and `[1,1,H,W]` layouts.

Install + verify it with the helper (mirrors `export_tflite.py`):
```bash
python scripts/export_depth_tflite.py --input path/to/midas_small.tflite
# or best-effort download:
python scripts/export_depth_tflite.py --download
```
It validates the I/O shapes/dtypes, copies the file here, and prints the exact
`depth_config.dart` values to confirm. Sources for MiDaS-small: Kaggle Models
(`intel/midas` → TFLite → v2-1-small-lite) or the isl-org/MiDaS GitHub releases.

## Expected tensor shapes
- Input:  `[1, 256, 256, 3]` float32, RGB. ImageNet-normalized by default
  (`kDepthNormalize`/mean/std in `lib/constants/depth_config.dart`).
- Output: a single-channel depth/disparity map, e.g. `[1, 256, 256]`.

## Calibration (one-time, on-device)
Monocular depth is *relative*, so it needs a scale to become metres. Tune these
in `lib/constants/depth_config.dart`:
- `kDepthIsInverse` — true for MiDaS-style inverse depth (larger = nearer).
- `kDepthScale` — multiply/divide constant to metres.

Procedure: enable the debug HUD, point at an object at a known distance, read
`depth raw:` from the HUD, then run:
```bash
python scripts/export_depth_tflite.py --calibrate --raw <hud_raw> --meters <real_m>
```
and paste the printed `kDepthScale` into `depth_config.dart`. SINA only needs
coarse tiers (<1 / 1–2 / 2–4 / >4 m), so one reference point is enough.

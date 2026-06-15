#!/usr/bin/env python3
"""Prepare the optional monocular depth model for SINA.

SINA gives real per-object distance when `assets/models/depth.tflite` is present
(see `sina_mobile/lib/constants/depth_config.dart` and `assets/models/README.md`).
The default config targets **MiDaS v2.1 small** (256x256, ImageNet-normalized,
inverse relative depth), which is the recommended model.

This helper does three things:
  1. obtain a depth TFLite (a local file you pass, or a best-effort download),
  2. verify its input/output are compatible with the in-app decoder, and
  3. install it to sina_mobile/assets/models/depth.tflite and print the exact
     `depth_config.dart` values to confirm.

It deliberately avoids the heavy PyTorch->TF conversion chain (which, like the
YOLO export, does not install cleanly on Windows/Py3.12): bring a ready TFLite.

Usage
-----
  # Install + verify a model you already downloaded:
  python scripts/export_depth_tflite.py --input path/to/midas_small.tflite

  # Best-effort download of MiDaS-small, then install + verify:
  python scripts/export_depth_tflite.py --download
  python scripts/export_depth_tflite.py --download --url <direct-tflite-url>

  # Compute kDepthScale from one on-device reference reading (see below):
  python scripts/export_depth_tflite.py --calibrate --raw 152.0 --meters 2.0

Where to get MiDaS-small TFLite
-------------------------------
  - Kaggle Models: "intel/midas" -> TFLite -> v2-1-small-lite
    (https://www.kaggle.com/models/intel/midas)
  - isl-org/MiDaS GitHub releases (TF/TFLite assets)
Download the .tflite, then pass it with --input.

Calibration (one-time, on device)
----------------------------------
Monocular depth is *relative*; one constant maps it to metres. Enable the debug
HUD, point at an object at a known distance, read the `depth raw:` value, then:
  python scripts/export_depth_tflite.py --calibrate --raw <hud_raw> --meters <real_m>
Paste the printed kDepthScale into depth_config.dart. SINA only needs coarse
tiers (<1 / 1-2 / 2-4 / >4 m), so a single reference point is enough.
"""

import argparse
import os
import shutil
import sys
import urllib.request

# Must mirror lib/constants/depth_config.dart.
EXPECTED_INPUT = 256          # kDepthInputSize
EXPECTED_CHANNELS = 3
DEFAULT_INVERSE = True        # kDepthIsInverse (MiDaS = inverse depth)

# Best-effort default source (may change as hosts migrate; override with --url).
DEFAULT_URL = (
    "https://github.com/isl-org/MiDaS/releases/download/v2_1/model_opt.tflite"
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "sina_mobile", "assets", "models", "depth.tflite")


def _interpreter():
    """Return a TFLite Interpreter class (LiteRT or TensorFlow), or None."""
    try:
        from ai_edge_litert.interpreter import Interpreter
        return Interpreter
    except Exception:
        pass
    try:
        from tensorflow.lite import Interpreter
        return Interpreter
    except Exception:
        return None


def calibrate(raw, meters, inverse):
    """Print the kDepthScale that makes `raw` map to `meters`.

    In-app conversion (depth_config.dart):
        inverse:  metres = kDepthScale / raw   ->  scale = meters * raw
        forward:  metres = kDepthScale * raw   ->  scale = meters / raw
    """
    if raw <= 0:
        print("ERROR: --raw must be > 0 (read it from the debug HUD).")
        return 1
    scale = meters * raw if inverse else meters / raw
    print("// ---- paste into lib/constants/depth_config.dart ----")
    print("const bool kDepthIsInverse = %s;" % ("true" if inverse else "false"))
    print("const double kDepthScale = %.4f;" % scale)
    print("\n// Check: %.3f %s %.4f = %.3f m (target %.3f m)" % (
        raw, "->" if inverse else "*", scale,
        (scale / raw) if inverse else (scale * raw), meters))
    return 0


def fetch(url, out_path):
    print("Downloading depth model:\n  %s" % url)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "sina-export"})
        with urllib.request.urlopen(req, timeout=60) as r, \
                open(out_path, "wb") as f:
            shutil.copyfileobj(r, f)
    except Exception as e:
        print("ERROR: download failed (%s)." % e)
        print("Fetch a MiDaS-small TFLite manually (see this file's header)")
        print("and re-run with:  --input <file.tflite>")
        return None
    print("Saved %s (%.1f MB)" % (out_path, os.path.getsize(out_path) / 1e6))
    return out_path


def verify(path):
    """Check input/output are decoder-compatible. Returns (ok, in_size, inverse_hint)."""
    Interpreter = _interpreter()
    if Interpreter is None:
        print("WARNING: no TFLite runtime found (pip install ai-edge-litert OR "
              "tensorflow) - skipping deep verification.")
        return True, EXPECTED_INPUT, DEFAULT_INVERSE

    import numpy as np
    it = Interpreter(model_path=path)
    it.allocate_tensors()
    i, o = it.get_input_details()[0], it.get_output_details()[0]
    in_shape, in_dtype = list(i["shape"]), np.dtype(i["dtype"]).name
    out_shape, out_dtype = list(o["shape"]), np.dtype(o["dtype"]).name
    print("INPUT : %s %s" % (in_dtype, in_shape))
    print("OUTPUT: %s %s" % (out_dtype, out_shape))

    ok = True
    # Input: [1, S, S, 3] float32 (NHWC). Some MiDaS exports are NCHW [1,3,S,S].
    if in_dtype != "float32":
        print("  ! input dtype is %s, not float32. The isolate feeds a "
              "Float32List; a quantized depth model needs a quant/dequant step "
              "(prefer float16/float32 I/O, like the YOLO model)." % in_dtype)
        ok = False
    nhwc = len(in_shape) == 4 and in_shape[3] == EXPECTED_CHANNELS
    nchw = len(in_shape) == 4 and in_shape[1] == EXPECTED_CHANNELS
    if nchw and not nhwc:
        print("  ! input looks NCHW [1,3,S,S]. The isolate builds NHWC "
              "[1,S,S,3]; re-export as NHWC or adjust _runDepth.")
        ok = False
    in_size = in_shape[1] if nhwc else (in_shape[2] if nchw else EXPECTED_INPUT)
    if in_size != EXPECTED_INPUT:
        print("  ! input side is %d, but kDepthInputSize = %d. Update "
              "kDepthInputSize in depth_config.dart to %d."
              % (in_size, EXPECTED_INPUT, in_size))
    # Output: single-channel HxW map in one of the supported layouts.
    supported = (len(out_shape) == 3 or
                 (len(out_shape) == 4 and (out_shape[1] == 1 or out_shape[3] == 1)))
    if not supported:
        print("  ! output %s is not a recognized single-channel layout "
              "([1,H,W] / [1,H,W,1] / [1,1,H,W]). _DepthMap won't read it." % out_shape)
        ok = False
    return ok, in_size, DEFAULT_INVERSE


def print_config(in_size, inverse):
    print("\n// ---- confirm in lib/constants/depth_config.dart ----")
    print("const int kDepthInputSize = %d;" % in_size)
    print("const bool kDepthNormalize = true;            // ImageNet (MiDaS)")
    print("const List<double> kDepthMean = [0.485, 0.456, 0.406];")
    print("const List<double> kDepthStd  = [0.229, 0.224, 0.225];")
    print("const bool kDepthIsInverse = %s;              // MiDaS = inverse depth"
          % ("true" if inverse else "false"))
    print("// kDepthScale still needs ONE on-device calibration:")
    print("//   python scripts/export_depth_tflite.py --calibrate --raw <hud> --meters <m>")


def main():
    ap = argparse.ArgumentParser(description="Install/verify SINA's depth model.")
    ap.add_argument("--input", help="path to a depth .tflite to install")
    ap.add_argument("--download", action="store_true",
                    help="download the default MiDaS-small TFLite first")
    ap.add_argument("--url", default=DEFAULT_URL, help="override the download URL")
    ap.add_argument("--calibrate", action="store_true",
                    help="compute kDepthScale from --raw and --meters")
    ap.add_argument("--raw", type=float, help="HUD raw value at a known distance")
    ap.add_argument("--meters", type=float, help="that known distance, in metres")
    ap.add_argument("--forward", action="store_true",
                    help="model outputs forward depth (larger=farther), not inverse")
    args = ap.parse_args()

    inverse = not args.forward

    if args.calibrate:
        if args.raw is None or args.meters is None:
            print("ERROR: --calibrate needs --raw and --meters.")
            return 1
        return calibrate(args.raw, args.meters, inverse)

    os.makedirs(os.path.dirname(DEST), exist_ok=True)
    src = args.input

    if args.download:
        tmp = os.path.join(os.path.dirname(DEST), "_depth_download.tflite")
        src = fetch(args.url, tmp)
        if src is None:
            return 1

    if not src:
        print("Nothing to install. Pass --input <file.tflite> or --download.")
        print("Run with -h for details on where to get MiDaS-small.")
        return 1
    if not os.path.isfile(src):
        print("ERROR: no such file: %s" % src)
        return 1

    ok, in_size, inv = verify(src)
    shutil.copyfile(src, DEST)
    print("\nInstalled -> %s" % DEST)
    if args.download:
        try:
            os.remove(src)
        except OSError:
            pass

    print_config(in_size, inverse and inv)
    if not ok:
        print("\nNOTE: verification flagged issues above - resolve them before "
              "shipping, or the depth pass will be skipped at runtime.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

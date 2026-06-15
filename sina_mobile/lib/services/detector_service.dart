import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../constants/depth_config.dart';
import '../constants/yolo_config.dart';
import '../models/detection.dart';
import 'quant.dart';
import 'yuv_convert.dart';

/// GPU delegate is OFF by default: on some devices it hard-crashes (native,
/// uncatchable) during inference. CPU + XNNPACK (2 threads) is reliable and
/// still fast. Flip to true to try GPU once the app is confirmed stable.
const bool kUseGpuDelegate = false;

/// YOLOv8n TFLite inference pipeline — runs entirely on a background isolate.
///
/// The main isolate only sends raw camera planes and receives decoded
/// [RawBox]es, so heavy work (YUV→RGB, letterbox resize, interpreter.run,
/// decode, NMS) never blocks the UI / STT / TTS event loop.
///
/// Pipeline (per frame):
///   CameraImage(YUV420) → RGB → letterbox to 320×320 → Float32List[1,320,320,3]
///   → interpreter.run → decode [1,84,N] (or [1,N,84]) → conf filter
///   → target-class filter → NMS(IoU 0.45) → RawBox (normalized to frame)
class DetectorService {
  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _fromWorker;
  StreamSubscription? _sub;
  Completer<_ResultMsg>? _pending;
  bool _busy = false;
  bool _ready = false;

  // Diagnostics (surfaced in the debug HUD).
  String loadError = '-';
  int framesProcessed = 0;
  int lastRawCount = 0;
  double lastMaxConf = 0;
  /// Raw monocular-depth value at the closest box (0 when no depth model / box).
  /// Surfaced in the debug HUD to calibrate [kDepthScale] on-device.
  double lastDepthRaw = 0;

  /// True once a model has been loaded successfully on the worker isolate.
  bool get isLoaded => _ready;

  /// True when the optional monocular depth model loaded on the worker isolate.
  bool depthLoaded = false;
  bool get isDepthLoaded => depthLoaded;

  /// True when the active YOLO model has quantized (int8/uint8) I/O — the worker
  /// then quantizes the input and dequantizes the output. Shown in the HUD.
  bool quantized = false;

  /// Spawn the worker isolate and load the model there. Safe to call when the
  /// asset is missing — the app keeps working without detection.
  Future<void> init() async {
    if (_isolate != null) return;
    final fromWorker = ReceivePort();
    _fromWorker = fromWorker;
    final ready = Completer<void>();

    _sub = fromWorker.listen((msg) {
      if (msg is _ReadyMsg) {
        _workerPort = msg.workerPort;
        if (msg.error != null) {
          loadError = msg.error!;
          _ready = false;
        } else {
          _ready = true;
          depthLoaded = msg.depthLoaded;
          quantized = msg.quantized;
          // ignore: avoid_print
          print('[Detector] model loaded on isolate. '
              'in=${msg.inShape} out=${msg.outShape} depth=${msg.depthLoaded} '
              'quant=${msg.quantized}');
        }
        if (!ready.isCompleted) ready.complete();
      } else if (msg is _ResultMsg) {
        lastRawCount = msg.rawCount;
        lastMaxConf = msg.maxConf;
        lastDepthRaw = msg.depthRaw;
        _pending?.complete(msg);
        _pending = null;
      }
    });

    try {
      final data = await rootBundle.load(kModelAsset);
      final bytes = data.buffer.asUint8List();
      // Optional monocular depth model — absent is fine (depth stays off).
      Uint8List? depthBytes;
      try {
        final dd = await rootBundle.load(kDepthModelAsset);
        depthBytes = dd.buffer.asUint8List();
      } catch (_) {
        depthBytes = null;
      }
      _isolate = await Isolate.spawn(
        _detectorEntry,
        _InitMsg(fromWorker.sendPort, bytes, depthBytes, kUseGpuDelegate),
      );
      await ready.future;
    } catch (e) {
      loadError = e.toString();
      _ready = false;
      // ignore: avoid_print
      print('[Detector] model not loaded ($e). Detection disabled.');
    }
  }

  void dispose() {
    try {
      _workerPort?.send('dispose');
    } catch (_) {}
    _sub?.cancel();
    _fromWorker?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _ready = false;
  }

  /// Run detection on one frame. Returns post-NMS boxes (normalized to the
  /// original frame), or an empty list if the model is absent or a frame is
  /// already in flight (frames are dropped while busy).
  Future<List<RawBox>> detect(CameraImage image,
      {required double confThreshold,
      double? genericConf,
      bool runDepth = true}) async {
    if (!_ready || _busy || _workerPort == null) return const [];
    if (image.planes.length < 3) return const [];
    _busy = true;
    framesProcessed++;
    try {
      final p0 = image.planes[0];
      final p1 = image.planes[1];
      final p2 = image.planes[2];
      final completer = Completer<_ResultMsg>();
      _pending = completer;
      _workerPort!.send(_FrameMsg(
        width: image.width,
        height: image.height,
        yBytes: p0.bytes,
        uBytes: p1.bytes,
        vBytes: p2.bytes,
        yRowStride: p0.bytesPerRow,
        uvRowStride: p1.bytesPerRow,
        uvPixelStride: p1.bytesPerPixel ?? 1,
        conf: confThreshold,
        genericConf: genericConf ?? confThreshold,
        runDepth: runDepth && depthLoaded,
      ));
      final result = await completer.future
          .timeout(const Duration(seconds: 2), onTimeout: () {
        _pending = null;
        return const _ResultMsg([], 0, 0);
      });
      return result.boxes;
    } catch (e) {
      // ignore: avoid_print
      print('[Detector] error: $e');
      return const [];
    } finally {
      _busy = false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolate messages
// ─────────────────────────────────────────────────────────────────────────────

class _InitMsg {
  final SendPort mainPort;
  final Uint8List modelBytes;
  final Uint8List? depthBytes;
  final bool useGpu;
  _InitMsg(this.mainPort, this.modelBytes, this.depthBytes, this.useGpu);
}

class _ReadyMsg {
  final SendPort workerPort;
  final List<int>? inShape;
  final List<int>? outShape;
  final String? error;
  final bool depthLoaded;
  final bool quantized;
  _ReadyMsg(this.workerPort, this.inShape, this.outShape, this.error,
      {this.depthLoaded = false, this.quantized = false});
}

class _FrameMsg {
  final int width, height;
  final Uint8List yBytes, uBytes, vBytes;
  final int yRowStride, uvRowStride, uvPixelStride;
  final double conf;
  final double genericConf;
  final bool runDepth;
  _FrameMsg({
    required this.width,
    required this.height,
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.conf,
    required this.genericConf,
    required this.runDepth,
  });
}

class _ResultMsg {
  final List<RawBox> boxes;
  final int rawCount;
  final double maxConf;
  final double depthRaw;
  const _ResultMsg(this.boxes, this.rawCount, this.maxConf,
      [this.depthRaw = 0]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolate worker
// ─────────────────────────────────────────────────────────────────────────────

void _detectorEntry(_InitMsg init) {
  final port = ReceivePort();
  Interpreter? interpreter;
  Interpreter? depthInterp;
  List<int> outShape = const [];
  List<int> depthOutShape = const [];
  _Quant quant = const _Quant.float();
  // Inference buffers allocated once and reused across frames. interpreter.run
  // overwrites them in place, so a long walk doesn't churn the GC re-allocating
  // large input/output arrays every frame (the budget-phone hot path).
  _Buffers? buffers;
  _Buffers? depthBuffers;

  try {
    final options = InterpreterOptions()..threads = 2;
    if (init.useGpu) {
      try {
        options.addDelegate(GpuDelegateV2());
      } catch (_) {
        // GPU delegate unavailable; CPU (XNNPACK) path is used instead.
      }
    }
    interpreter = Interpreter.fromBuffer(init.modelBytes, options: options);
    interpreter.allocateTensors();
    final inT = interpreter.getInputTensor(0);
    final outT = interpreter.getOutputTensor(0);
    final inShape = inT.shape;
    outShape = outT.shape;

    // Detect quantized I/O so the worker can quantize the input and dequantize
    // the output. A float16 export keeps float32 I/O → the float path is used.
    final inParams = inT.params;
    final outParams = outT.params;
    quant = _Quant(
      inFloat: inT.type == TensorType.float32,
      inUint8: inT.type == TensorType.uint8,
      inScale: inParams.scale,
      inZero: inParams.zeroPoint,
      outFloat: outT.type == TensorType.float32,
      outUint8: outT.type == TensorType.uint8,
      outScale: outParams.scale,
      outZero: outParams.zeroPoint,
    );

    buffers = _Buffers.forYolo(quant, outShape);

    // Optional monocular depth model on the same isolate. Failure to load is
    // non-fatal: detection continues, distance falls back to the heuristic.
    if (init.depthBytes != null) {
      try {
        final dOpts = InterpreterOptions()..threads = 2;
        depthInterp = Interpreter.fromBuffer(init.depthBytes!, options: dOpts);
        depthInterp.allocateTensors();
        depthOutShape = depthInterp.getOutputTensor(0).shape;
        depthBuffers = _Buffers.forDepth(depthOutShape);
      } catch (_) {
        depthInterp = null;
      }
    }

    init.mainPort.send(_ReadyMsg(port.sendPort, inShape, outShape, null,
        depthLoaded: depthInterp != null, quantized: quant.quantized));
  } catch (e) {
    init.mainPort.send(_ReadyMsg(port.sendPort, null, null, e.toString()));
  }

  port.listen((msg) {
    if (msg == 'dispose') {
      interpreter?.close();
      depthInterp?.close();
      port.close();
      return;
    }
    if (msg is _FrameMsg && interpreter != null && buffers != null) {
      try {
        final di = msg.runDepth ? depthInterp : null;
        init.mainPort.send(_processFrame(interpreter, outShape, buffers, di,
            depthOutShape, depthBuffers, msg, quant));
      } catch (_) {
        init.mainPort.send(const _ResultMsg([], 0, 0));
      }
    }
  });
}

_ResultMsg _processFrame(
    Interpreter interp,
    List<int> outShape,
    _Buffers buf,
    Interpreter? depthInterp,
    List<int> depthOutShape,
    _Buffers? depthBuf,
    _FrameMsg m,
    _Quant quant) {
  final rgb = _yuv420ToImage(m);

  // Letterbox (aspect-preserving) into a square kInputSize canvas.
  final scale = kInputSize / math.max(m.width, m.height);
  final contentW = (m.width * scale).round();
  final contentH = (m.height * scale).round();
  final padX = ((kInputSize - contentW) / 2).floor();
  final padY = ((kInputSize - contentH) / 2).floor();

  final resized = img.copyResize(rgb, width: contentW, height: contentH);
  final canvas = img.Image(width: kInputSize, height: kInputSize);
  img.fill(canvas, color: img.ColorRgb8(114, 114, 114)); // YOLO gray padding
  img.compositeImage(canvas, resized, dstX: padX, dstY: padY);

  // Read the canvas as one packed RGB byte buffer (row-major, channel-
  // interleaved) — avoids ~100k per-pixel getPixel() allocations.
  final canvasBytes = canvas.getBytes(order: img.ChannelOrder.rgb);
  const n = kInputSize * kInputSize * 3;

  // Fill the reused input buffer in place: float32 [0,1] for a float model, or
  // quantized bytes (q = round(real/scale)+zero) for an int8/uint8 model.
  if (quant.inFloat) {
    final input = buf.inFloat!;
    for (int j = 0; j < n; j++) {
      input[j] = canvasBytes[j] / 255.0;
    }
  } else if (quant.inUint8) {
    final q = buf.inSend;
    for (int j = 0; j < n; j++) {
      q[j] = quantizeUint8(canvasBytes[j] / 255.0, quant.inScale, quant.inZero);
    }
  } else {
    final q = buf.inInt8!;
    for (int j = 0; j < n; j++) {
      q[j] = quantizeInt8(canvasBytes[j] / 255.0, quant.inScale, quant.inZero);
    }
  }

  // Run into the reused raw-byte output buffer. Passing a Uint8List in/out hits
  // tflite_flutter's fast byte-copy path (no per-element conversion or nested
  // List allocation), and the output is read back through a typed view.
  interp.run(buf.inSend, buf.outBytes);

  final result = _decode(
    buf,
    outShape,
    m.conf,
    m.genericConf,
    padX: padX,
    padY: padY,
    contentW: contentW,
    contentH: contentH,
    quantized: !quant.outFloat,
    outUint8: quant.outUint8,
    outScale: quant.outScale,
    outZero: quant.outZero,
  );

  // Classify traffic-light colour from the original RGB frame.
  for (final b in result.boxes) {
    if (b.classId == kTrafficLightClassId) {
      b.lightState = _classifyTrafficLight(rgb, b);
    }
  }

  // Monocular depth: fill each box's distanceMeters from the depth map.
  double depthRaw = 0;
  if (depthInterp != null && depthBuf != null && result.boxes.isNotEmpty) {
    depthRaw = _runDepth(depthInterp, depthOutShape, depthBuf, rgb, result.boxes);
  }
  return _ResultMsg(result.boxes, result.rawCount, result.maxConf, depthRaw);
}

/// Run the monocular depth model on [rgb], then sample each box centre and set
/// its [RawBox.distanceMeters]. Returns the raw (pre-conversion) median value at
/// the closest box, for HUD calibration. Never throws into the frame loop.
double _runDepth(Interpreter interp, List<int> outShape, _Buffers buf,
    img.Image rgb, List<RawBox> boxes) {
  // Stretch-resize the full frame to the depth model's square input. Because the
  // resize spans the whole frame, a box centre normalized to the original frame
  // maps directly to (nx*W, ny*H) in the depth map.
  final resized = img.copyResize(rgb, width: kDepthInputSize, height: kDepthInputSize);
  final bytes = resized.getBytes(order: img.ChannelOrder.rgb);
  final input = buf.inFloat!;
  for (int i = 0; i < input.length; i += 3) {
    double r = bytes[i] / 255.0, g = bytes[i + 1] / 255.0, b = bytes[i + 2] / 255.0;
    if (kDepthNormalize) {
      r = (r - kDepthMean[0]) / kDepthStd[0];
      g = (g - kDepthMean[1]) / kDepthStd[1];
      b = (b - kDepthMean[2]) / kDepthStd[2];
    }
    input[i] = r;
    input[i + 1] = g;
    input[i + 2] = b;
  }

  interp.run(buf.inSend, buf.outBytes);

  final map = _DepthMap(buf.outF32!, outShape);
  if (map.w == 0 || map.h == 0) return 0;

  double closestRaw = 0;
  double closestMeters = double.infinity;
  for (final b in boxes) {
    final nx = (b.x1 + b.x2) / 2;
    final ny = (b.y1 + b.y2) / 2;
    final raw = map.sampleMedian(nx, ny);
    final metres = depthValueToMeters(raw);
    if (metres > 0) {
      b.distanceMeters = metres;
      if (metres < closestMeters) {
        closestMeters = metres;
        closestRaw = raw;
      }
    }
  }
  return closestRaw;
}

/// Read-only view over a depth model's output tensor, handling the common
/// shapes: [1,H,W], [1,H,W,1] and [1,1,H,W]. All three are contiguous H·W in
/// row-major order (the singleton dims have size 1), so a flat Float32List view
/// indexes the same as the nested form: value(y,x) = data[y·w + x].
class _DepthMap {
  final Float32List _out;
  late final int h;
  late final int w;

  _DepthMap(this._out, List<int> shape) {
    if (shape.length == 3) {
      h = shape[1];
      w = shape[2];
    } else if (shape.length == 4 && shape[1] == 1) {
      h = shape[2];
      w = shape[3];
    } else if (shape.length == 4 && shape[3] == 1) {
      h = shape[1];
      w = shape[2];
    } else {
      h = 0;
      w = 0;
    }
  }

  double _at(int y, int x) => _out[y * w + x];

  /// Median of a 3×3 neighbourhood around normalized (nx,ny), for robustness.
  double sampleMedian(double nx, double ny) {
    final cx = (nx * w).round().clamp(0, w - 1);
    final cy = (ny * h).round().clamp(0, h - 1);
    final vals = <double>[];
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final x = (cx + dx).clamp(0, w - 1);
        final y = (cy + dy).clamp(0, h - 1);
        vals.add(_at(y, x));
      }
    }
    vals.sort();
    return vals[vals.length ~/ 2];
  }
}

/// Heuristic red/green/yellow classification of a traffic-light box by sampling
/// the brightest coloured pixels inside it. Returns null when unsure. This is a
/// colour heuristic, not a trained classifier — it favours staying silent over
/// announcing a wrong state.
String? _classifyTrafficLight(img.Image rgb, RawBox b) {
  final w = rgb.width, h = rgb.height;
  final x1 = (b.x1 * w).floor().clamp(0, w - 1);
  final y1 = (b.y1 * h).floor().clamp(0, h - 1);
  final x2 = (b.x2 * w).ceil().clamp(0, w - 1);
  final y2 = (b.y2 * h).ceil().clamp(0, h - 1);
  if (x2 <= x1 || y2 <= y1) return null;

  final stepX = ((x2 - x1) / 24).ceil().clamp(1, 1 << 20);
  final stepY = ((y2 - y1) / 24).ceil().clamp(1, 1 << 20);

  int red = 0, green = 0, yellow = 0, bright = 0;
  for (int y = y1; y <= y2; y += stepY) {
    for (int x = x1; x <= x2; x += stepX) {
      final p = rgb.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), bl = p.b.toInt();
      final mx = r > g ? (r > bl ? r : bl) : (g > bl ? g : bl);
      if (mx < 90) continue; // skip the dark housing
      bright++;
      if (r > 110 && r > g + 40 && r > bl + 30) {
        red++;
      } else if (g > 100 && g > r + 10 && g > bl + 20) {
        green++;
      } else if (r > 120 && g > 110 && bl < 110 && (r - g).abs() < 70) {
        yellow++;
      }
    }
  }

  if (bright < 4) return null;
  if (red >= 3 && red >= green && red >= yellow) return 'red';
  if (green >= 3 && green > red && green >= yellow) return 'green';
  if (yellow >= 3 && yellow > red && yellow > green) return 'yellow';
  return null;
}

_ResultMsg _decode(
  _Buffers buf,
  List<int> outShape,
  double confThreshold,
  double genericConf, {
  required int padX,
  required int padY,
  required int contentW,
  required int contentH,
  bool quantized = false,
  bool outUint8 = false,
  double outScale = 1.0,
  int outZero = 0,
}) {
  // [1,F,N] or [1,N,F], F = 4 + numClasses. The feature dim (4 + classes) is
  // much smaller than the candidate-box dim, so detect orientation by size.
  // Works for 80-class COCO and custom models.
  final bool featuresMajor = outShape[1] < outShape[2]; // [1,F,N]
  final int numFeatures = featuresMajor ? outShape[1] : outShape[2];
  final int numBoxes = featuresMajor ? outShape[2] : outShape[1];
  final int numClasses = numFeatures - 4;

  // Read the raw output as a flat, row-major typed view (no per-frame nested
  // List allocation). For a quantized model the raw int is dequantized via
  // real = (q - zero) * scale.
  final Float32List? f32 = buf.outF32;
  final Int8List? i8 = buf.outI8;
  final Uint8List u8 = buf.outBytes;
  double getVal(int feature, int box) {
    final idx =
        featuresMajor ? feature * numBoxes + box : box * numFeatures + feature;
    final double v;
    if (f32 != null) {
      v = f32[idx];
    } else if (outUint8) {
      v = u8[idx].toDouble();
    } else {
      v = i8![idx].toDouble();
    }
    return quantized ? dequantize(v, outScale, outZero) : v;
  }

  final boxes = <RawBox>[];
  double maxConf = 0;

  for (int b = 0; b < numBoxes; b++) {
    double bestScore = 0;
    int bestClass = -1;
    for (int c = 0; c < numClasses; c++) {
      final s = getVal(4 + c, b);
      if (s > bestScore) {
        bestScore = s;
        bestClass = c;
      }
    }
    if (bestScore > maxConf) maxConf = bestScore;
    // Keep down to the generic floor; boxes below the naming threshold are
    // flagged uncertain and later announced as an unnamed "object".
    if (bestScore < genericConf) continue;
    if (!targetClassIds.contains(bestClass)) continue;
    final uncertain = bestScore < confThreshold;

    double cx = getVal(0, b);
    double cy = getVal(1, b);
    double w = getVal(2, b);
    double h = getVal(3, b);
    // Normalize to the 320 square if the export emits pixel coords.
    if (cx > 2 || cy > 2 || w > 2 || h > 2) {
      cx /= kInputSize;
      cy /= kInputSize;
      w /= kInputSize;
      h /= kInputSize;
    }

    // Undo letterbox → normalized coords relative to the original frame.
    final fx = (cx * kInputSize - padX) / contentW;
    final fy = (cy * kInputSize - padY) / contentH;
    final fw = (w * kInputSize) / contentW;
    final fh = (h * kInputSize) / contentH;

    final x1 = (fx - fw / 2).clamp(0.0, 1.0);
    final y1 = (fy - fh / 2).clamp(0.0, 1.0);
    final x2 = (fx + fw / 2).clamp(0.0, 1.0);
    final y2 = (fy + fh / 2).clamp(0.0, 1.0);

    boxes.add(RawBox(
      bestClass,
      cocoLabels[bestClass] ?? 'object',
      bestScore,
      x1,
      y1,
      x2,
      y2,
      uncertain: uncertain,
    ));
  }

  final kept = _filterUncertain(_nms(boxes, kNmsIoU));
  return _ResultMsg(kept, kept.length, maxConf);
}

/// Drop uncertain boxes that overlap a confident one — the named detection
/// already covers that object, so we don't also say "object detected".
List<RawBox> _filterUncertain(List<RawBox> boxes) {
  final confident = boxes.where((b) => !b.uncertain).toList();
  if (confident.isEmpty) return boxes;
  return boxes.where((b) {
    if (!b.uncertain) return true;
    for (final c in confident) {
      if (_iou(b, c) > 0.4) return false;
    }
    return true;
  }).toList();
}

/// Per-model quantization info captured at load. The default is a float32 model
/// (the current float16 export keeps float32 I/O), so the float path is used.
class _Quant {
  final bool inFloat;
  final bool inUint8; // when inFloat is false: uint8 if true, else int8
  final double inScale;
  final int inZero;
  final bool outFloat;
  final bool outUint8; // when outFloat is false: uint8 if true, else int8
  final double outScale;
  final int outZero;
  const _Quant({
    required this.inFloat,
    required this.inUint8,
    required this.inScale,
    required this.inZero,
    required this.outFloat,
    required this.outUint8,
    required this.outScale,
    required this.outZero,
  });
  const _Quant.float()
      : inFloat = true,
        inUint8 = false,
        inScale = 0,
        inZero = 0,
        outFloat = true,
        outUint8 = false,
        outScale = 0,
        outZero = 0;
  bool get quantized => !inFloat || !outFloat;
}

/// Reusable inference buffers, allocated once per interpreter. The input is
/// filled in place each frame and passed to `interpreter.run` as a flat
/// Uint8List (tflite's fast byte-copy path); the output is read back through a
/// typed view over the same raw-byte buffer. Reusing these avoids re-allocating
/// large arrays — and the boxed-double nested lists tflite would otherwise build
/// — on every frame.
class _Buffers {
  /// Float input values [0,1] (length = inputSize²·3); null for quant models.
  final Float32List? inFloat;

  /// Int8 view over [inSend] for an int8 model; null otherwise.
  final Int8List? inInt8;

  /// The flat byte buffer handed to `interpreter.run` as input.
  final Uint8List inSend;

  /// Raw output bytes (reused); read via [outF32]/[outI8]/itself.
  final Uint8List outBytes;

  /// Float32 view over [outBytes] for a float output; null for quant output.
  final Float32List? outF32;

  /// Int8 view over [outBytes] for an int8 output; null otherwise (uint8 reads
  /// [outBytes] directly).
  final Int8List? outI8;

  _Buffers._(this.inFloat, this.inInt8, this.inSend, this.outBytes, this.outF32,
      this.outI8);

  factory _Buffers.forYolo(_Quant q, List<int> outShape) {
    const n = kInputSize * kInputSize * 3;
    Float32List? inFloat;
    Int8List? inInt8;
    final Uint8List inSend;
    if (q.inFloat) {
      inFloat = Float32List(n);
      inSend = inFloat.buffer.asUint8List();
    } else {
      inSend = Uint8List(n);
      if (!q.inUint8) inInt8 = inSend.buffer.asInt8List();
    }
    final elems = _numElements(outShape);
    final outBytes = Uint8List(elems * (q.outFloat ? 4 : 1));
    final outF32 = q.outFloat ? Float32List.view(outBytes.buffer) : null;
    final outI8 =
        (!q.outFloat && !q.outUint8) ? Int8List.view(outBytes.buffer) : null;
    return _Buffers._(inFloat, inInt8, inSend, outBytes, outF32, outI8);
  }

  /// Depth model: float32 input and output.
  factory _Buffers.forDepth(List<int> outShape) {
    const n = kDepthInputSize * kDepthInputSize * 3;
    final inFloat = Float32List(n);
    final inSend = inFloat.buffer.asUint8List();
    final outBytes = Uint8List(_numElements(outShape) * 4);
    return _Buffers._(
        inFloat, null, inSend, outBytes, Float32List.view(outBytes.buffer), null);
  }
}

int _numElements(List<int> shape) {
  var n = 1;
  for (final d in shape) {
    n *= d;
  }
  return n;
}

// ── YUV420 → RGB ──────────────────────────────────────────────────────────────
/// Convert a YUV420 frame to an RGB [img.Image] using **integer fixed-point**
/// BT.601 (full-range) math, writing straight into a packed RGB byte buffer.
/// Avoids per-pixel float multiplies, `.round()`, `.clamp()` and the per-pixel
/// `setPixelRgb()` call overhead of the original — the dominant per-frame cost.
///
/// Coefficients are the JFIF full-range constants scaled by 256 (`<<8`):
///   r = y + 1.402·v'           ≈ y + (359·v')>>8
///   g = y − 0.344·u' − 0.714·v'≈ y − (88·u' + 183·v')>>8
///   b = y + 1.772·u'           ≈ y + (454·u')>>8   (u'=u−128, v'=v−128)
img.Image _yuv420ToImage(_FrameMsg m) {
  final rgb = yuv420ToRgbBytes(
    width: m.width,
    height: m.height,
    yBytes: m.yBytes,
    uBytes: m.uBytes,
    vBytes: m.vBytes,
    yRowStride: m.yRowStride,
    uvRowStride: m.uvRowStride,
    uvPixelStride: m.uvPixelStride,
  );
  return img.Image.fromBytes(
    width: m.width,
    height: m.height,
    bytes: rgb.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
}

// ── Class-aware non-maximum suppression ──────────────────────────────────────
List<RawBox> _nms(List<RawBox> boxes, double iouThr) {
  boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
  final kept = <RawBox>[];
  final removed = List<bool>.filled(boxes.length, false);

  for (int i = 0; i < boxes.length; i++) {
    if (removed[i]) continue;
    kept.add(boxes[i]);
    for (int j = i + 1; j < boxes.length; j++) {
      if (removed[j]) continue;
      if (boxes[j].classId != boxes[i].classId) continue;
      if (_iou(boxes[i], boxes[j]) > iouThr) removed[j] = true;
    }
  }
  return kept;
}

double _iou(RawBox a, RawBox b) {
  final ix1 = math.max(a.x1, b.x1);
  final iy1 = math.max(a.y1, b.y1);
  final ix2 = math.min(a.x2, b.x2);
  final iy2 = math.min(a.y2, b.y2);
  final iw = math.max(0.0, ix2 - ix1);
  final ih = math.max(0.0, iy2 - iy1);
  final inter = iw * ih;
  final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
  final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
  final union = areaA + areaB - inter;
  return union <= 0 ? 0 : inter / union;
}

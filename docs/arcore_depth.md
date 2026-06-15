# ARCore Depth → real distance for SINA

This documents how to feed **real per-object distance (metres)** into SINA using
the ARCore Depth API, replacing the bounding-box-area heuristic.

The Dart side is **already wired** (`lib/services/depth_service.dart` +
`AppController`): when the native depth channel reports `isAvailable = true` and
returns metres for queried points, SINA maps them to distance tiers
(`distanceTierFromMeters`: <1 m stop, 1–2 m close, 2–4 m medium, >4 m far) and
falls back to the heuristic otherwise. So this guide is purely the **native
Android (Kotlin) half** you implement on a device.

## Where this fits: the layered depth chain

Depth now has **three sources**, tried in priority order (`AppController._onFrame`):

1. **native ARCore / ARKit metres** (this guide) — used when a reading is > 0.
2. **monocular depth model** — a small TFLite depth net (`assets/models/depth.tflite`)
   that runs *in the detector isolate on the existing `package:camera` RGB frame*
   and is the **default, all-device** source. See `assets/models/README.md` and
   `lib/constants/depth_config.dart`.
3. **area-ratio heuristic** — always available, last resort.

> **Important for coexistence:** because the monocular model (and YOLO) consume
> the `package:camera` stream, the native ARCore override must use **Option B
> (SharedCamera)** below, *not* Option A. Option A makes ARCore own the camera,
> which would starve both YOLO and the monocular model. Use ARCore here purely as
> a depth *supplement* layered on top of the existing camera pipeline.

---

## The key architectural decision: who owns the camera?

ARCore runs a `Session` that **owns the camera**. The app currently uses the
Flutter `package:camera` plugin to stream YUV frames into the YOLO isolate. Both
cannot own the camera at once. Two options:

### Option A — ARCore as the camera source (recommended, most correct)
ARCore drives the camera and gives you **both**:
- the RGB image (`frame.acquireCameraImage()` → YUV) → feed to the YOLO isolate
  (same `DetectorService` pipeline), and
- the depth image (`frame.acquireDepthImage16Bits()`) → sample at box centres.

This replaces `package:camera`. More work, but a single coherent pipeline and
correct depth↔image alignment.

### Option B — ARCore SharedCamera alongside camera2 (use this for the layered chain)
ARCore's `SharedCamera` lets an ARCore session and a camera2 capture session
share the device camera. Advanced and fiddly, but it is the **required** option
when keeping the existing `package:camera` pipeline (YOLO + monocular depth) —
ARCore then only supplies depth and never owns the camera. This is the option
that matches the layered depth chain described above.

### Option C — keep current behaviour
Don't enable depth. `isAvailable` stays `false`, area heuristic is used. This is
the shipped default.

---

## 1. Gradle

`android/app/build.gradle.kts`:
```kotlin
dependencies {
    implementation("com.google.ar:core:1.45.0")
    // For acquireCameraImage()/depth helpers you only need core; image
    // conversion can reuse your existing YUV→RGB code in the isolate.
}
```

## 2. Manifest

`android/app/src/main/AndroidManifest.xml` — inside `<application>`:
```xml
<meta-data android:name="com.google.ar.core" android:value="optional" />
```
and at the top level:
```xml
<uses-feature android:name="android.hardware.camera.ar" android:required="false" />
<uses-feature android:glEsVersion="0x00030000" android:required="false" />
```
`optional` (not `required`) keeps the app installable on non-ARCore phones — they
just use the heuristic.

## 3. Check availability & install

```kotlin
import com.google.ar.core.ArCoreApk

fun arcoreUsable(activity: Activity): Boolean {
    val a = ArCoreApk.getInstance().checkAvailability(activity)
    // May return TRANSIENT-checking on first call; re-check on next frame.
    return a.isSupported
}
```

## 4. Session with depth enabled

```kotlin
import com.google.ar.core.*

fun createDepthSession(ctx: Context): Session? {
    val session = Session(ctx)
    val config = Config(session)
    if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
        config.depthMode = Config.DepthMode.AUTOMATIC
    } else {
        return null // device has no depth → fall back to heuristic
    }
    config.focusMode = Config.FocusMode.AUTO
    config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
    session.configure(config)
    return session
}
```

ARCore needs a render/update loop with an OpenGL context (it expects a GL texture
to draw the camera into). The simplest robust host is a small `GLSurfaceView`
whose `onDrawFrame` calls `session.update()`; you don't have to render anything
useful, but the texture must be set via `session.setCameraTextureName(texId)`.

## 5. Per-frame: RGB for YOLO + depth for distance

```kotlin
val frame = session.update()

// (Option A) RGB for YOLO — convert and forward to your detector pipeline.
val cameraImage = frame.acquireCameraImage()  // YUV_420_888
// ... convert + send to the Dart/YOLO isolate, then:
cameraImage.close()

// Depth (16-bit, millimetres), aligned to the camera image.
val depth = frame.acquireDepthImage16Bits()   // throws if not yet available
val w = depth.width
val h = depth.height
val plane = depth.planes[0]
val buffer = plane.buffer.order(java.nio.ByteOrder.nativeOrder())
val rowStride = plane.rowStride
// Keep a snapshot for queryDepth():
lastDepth = DepthFrame(buffer, w, h, rowStride)
depth.close()
```

Sampling depth at a normalized point (x,y ∈ [0,1]):
```kotlin
fun depthMetres(d: DepthFrame, nx: Float, ny: Float): Double {
    val px = (nx * d.w).toInt().coerceIn(0, d.w - 1)
    val py = (ny * d.h).toInt().coerceIn(0, d.h - 1)
    val idx = py * d.rowStride + px * 2          // 2 bytes per sample
    val mm = (d.buffer.getShort(idx).toInt() and 0xFFFF)
    if (mm == 0) return -1.0                      // 0 = no depth at this pixel
    return mm / 1000.0
}
```
Sample a few neighbours and take the median for robustness. Note the depth image
resolution is small (~160×120); a box centre maps fine.

> Alignment: ARCore's depth image is aligned to the **camera image** coordinate
> frame. SINA's box centres are normalized to the (letterboxed-undone) frame, so
> normalized x/y map directly. If you rotate/crop the RGB before YOLO, apply the
> same transform to the depth query coordinates.

## 6. MethodChannel — replace the stub in `MainActivity`

Today `MainActivity` answers the `com.sina.mobility/depth` channel with
`isAvailable=false`. Wire it to your session:
```kotlin
MethodChannel(messenger, "com.sina.mobility/depth").setMethodCallHandler { call, result ->
    when (call.method) {
        "isAvailable" -> result.success(depthSession != null && depthSupported)
        "queryDepth" -> {
            val flat = call.argument<List<Double>>("points") ?: emptyList()
            val d = lastDepth
            if (d == null) { result.success(emptyList<Double>()); return@setMethodCallHandler }
            val out = ArrayList<Double>(flat.size / 2)
            var i = 0
            while (i + 1 < flat.size) {
                out.add(depthMetres(d, flat[i].toFloat(), flat[i + 1].toFloat()))
                i += 2
            }
            result.success(out)
        }
        else -> result.notImplemented()
    }
}
```
The Dart `DepthService.depthAt(points)` already sends `points` as a flat
`[x0,y0,x1,y1,…]` list and reads back a parallel metres list.

## 7. Lifecycle & permissions
- Call `session.resume()`/`session.pause()` with the activity lifecycle.
- Camera permission is already requested by SINA.
- Run `ArCoreApk.requestInstall()` if ARCore APK isn't installed yet.

---

## Caveats
- **Device support:** depth needs an ARCore-supported device (most mid/high-end
  Android since ~2019). Non-supported devices keep the heuristic automatically.
- **Range/accuracy:** ARCore depth is best ~0.5–5 m, degrades on textureless or
  very bright/dark scenes — exactly SINA's "very_close/close/medium" band, which
  is fine. Treat 0/invalid as unknown (the Dart side already maps ≤0 → "far").
- **Performance:** running ARCore + YOLO is heavier; reuse the battery-aware
  throttle (`_checkBattery`) and consider lowering inference rate when depth is on.
- **iOS:** ARCore is Android-only. For iOS use ARKit (`ARFrame.sceneDepth`,
  LiDAR/`smoothedSceneDepth`) behind the same `com.sina.mobility/depth` channel.

## Alternative (no ARCore): monocular depth model
If you'd rather avoid the camera-ownership change, run a small **quantized
monocular depth model** (MiDaS-small / Depth-Anything-small, int8 TFLite) in the
same isolate on the existing RGB frame, output a relative depth map, sample box
centres, and calibrate to metres. Less accurate, but no session/camera conflict
and works with the current `package:camera` pipeline.

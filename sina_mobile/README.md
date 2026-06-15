# SINA — Mobile (Flutter / Android)

Voice-guided mobility assistant for visually impaired users. Native Android
port of the SINA web app — everything runs **on-device and offline**: camera,
YOLOv8 obstacle detection (TFLite), OS-native speech recognition, text-to-speech,
GPS, and emergency SOS. No Flask server, no login, no cloud.

> Ported from the Flask + vanilla-JS web app per `../OPUS_PROMPT.md`.
> Detection logic, multilingual strings, voice commands, and the SOS flow are
> ported 1:1 from `app.py` and `static/js/assistant.js`.

---

## Features

- **Obstacle detection** — YOLOv8n TFLite, 11 mobility classes, distance +
  direction estimation, 2 s announcement cooldown, grouped / "many obstacles"
  summaries (exact port of `app.py`).
- **Voice commands** (FR / EN / AR) — camera, SOS, describe scene, settings,
  language switch, volume, GPS, location, status, help.
- **Speech recognition** — `speech_to_text` (Google on-device engine, 0 MB).
- **Text-to-speech** — `flutter_tts` with speak-then-listen loop.
- **GPS tracking** + family dashboard map (OpenStreetMap via `flutter_map`).
- **Emergency SOS** — haptics, GPS capture, phone dialer, WhatsApp deep link,
  local notification, 30 s check-in.
- **Settings** persisted with `shared_preferences`.
- **Accessibility** — large tap targets, high contrast, RTL for Arabic,
  full-screen tap-to-start, screen kept awake during detection.

---

## Prerequisites

- Flutter SDK **3.19+**, Dart 3.3+
- Android SDK **34**, Java **17**
- A physical Android phone (camera + mic). minSdk 24, arm64 / armeabi-v7a.

---

## Build & run

### 1. Generate platform scaffolding (one time)

This repo ships all source (`lib/`), `pubspec.yaml`, the Android config
(`android/app/build.gradle`, `AndroidManifest.xml`, …) and assets — but **not**
the binary Gradle wrapper (`gradlew`, `gradle-wrapper.jar`), which can't be
checked in as text. Materialize it with:

```bash
cd sina_mobile
flutter create . --org com.sina --project-name sina_mobile --platforms=android
```

`flutter create .` fills in only the missing generated files (the wrapper, etc.)
and leaves your `lib/`, `pubspec.yaml`, and assets intact. If it overwrites any
of the provided Android config files, restore these three (they contain the
required permissions, `minSdk 24`, and `abiFilters`):

- `android/app/build.gradle`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/sina/mobility/MainActivity.kt`

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Add the YOLOv8 model

Place `yolov8n.tflite` in `assets/models/` (see
`assets/models/README.md`). Quick path, reusing the existing `yolov8n.pt`:

```bash
pip install ultralytics
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='tflite', imgsz=320)"
cp yolov8n_saved_model/yolov8n_float32.tflite assets/models/yolov8n.tflite
```

> The app runs without the model (voice, GPS, SOS all work) — only obstacle
> detection is disabled until the file is present.

### 4. Build / install

```bash
flutter run                      # debug on a connected device
flutter build apk --release      # → build/app/outputs/flutter-apk/app-release.apk
flutter install                  # push the release APK to a connected phone
```

---

## Voice commands

| Intent | FR (examples) | EN (examples) |
|---|---|---|
| Open camera | ouvre caméra, détecter | open camera, detect |
| Close camera | ferme, stop, arrête | close, stop |
| SOS | aide, secours, danger | help, danger, emergency |
| Describe scene | qu'est-ce que tu vois, décris | what do you see, describe |
| Settings | paramètres, réglages | settings, preferences |
| Language | français / anglais / arabe | french / english / arabic |
| Volume | volume, plus / baisse, moins | volume up / down |
| GPS | gps, partage / arrête gps | gps on / off |
| Where am I | où suis-je, position | where am I, location |
| Status | état, comment ça va | status, system |
| Help | aide, commandes | help, commands |

The big red **SOS** button works without voice — tap it any time.

---

## Architecture

```
lib/
├── main.dart                     App entry, MaterialApp, routes, theme
├── controller/
│   └── app_controller.dart       The brain: state machine, command dispatch,
│                                  detection queue, SOS (port of assistant.js)
├── constants/
│   ├── yolo_config.dart          target classes, thresholds, distance/position
│   ├── labels.dart               all multilingual strings + spoken builders
│   └── commands.dart             voice command keyword tables + matcher
├── models/
│   ├── detection.dart            Detection / RawBox
│   ├── alert.dart                SinaAlert
│   └── app_state.dart            AppState enum (idle/listening/responding)
├── services/
│   ├── detector_service.dart     TFLite inference, YUV→RGB, decode, NMS
│   ├── tts_service.dart          flutter_tts wrapper
│   ├── stt_service.dart          speech_to_text wrapper (VAD-style loop)
│   ├── gps_service.dart          geolocator wrapper + staleness
│   ├── alert_service.dart        alert log (max 50) + SOS notification
│   └── settings_service.dart     SharedPreferences (keys match settings.html)
├── screens/
│   ├── main_screen.dart          orb, camera preview, actions, tap-to-start
│   ├── settings_screen.dart      port of settings.html
│   └── family_screen.dart        OSM map + alert log
└── widgets/
    ├── orb_widget.dart           animated pulsing orb
    ├── detection_banner.dart     slide-in detection notification
    ├── bbox_painter.dart         bounding-box overlay
    └── camera_view.dart          camera preview + overlay
```

---

## Notes / parity with the web app

- **Distance**: area ratio > 0.20 very_close, > 0.06 close, > 0.01 medium, else far.
- **Position**: x-center < 0.35 left, > 0.65 right, else center.
- **Cooldown**: 2 s between announcements; only the closest instance per label.
- **>5 objects**: single "many obstacles, <closest distance>" summary.
- **Sensitivity → confidence**: 1 → 0.60, 2 → 0.50, 3 → 0.40.
- **Speech rate** maps web 0.7–1.3 to flutter_tts ≈ 0.2–0.8.
- **No authentication, no backend** — settings + last 20 alerts persist locally.

## Build status

✅ **Builds successfully, detection works out of the box.** Produces
`build/app/outputs/flutter-apk/app-release.apk` (~81 MB, includes the bundled
`yolov8n.tflite`), signed with the debug key for sideloading (replace with a
real signing config before any store release). On Android, `tflite_flutter`
loads `libtensorflowlite_jni.so` (shipped by the TensorFlow Lite AAR, already in
the APK) — no extra native library needed.

Built with: Flutter 3.44.1 (Dart 3.12.1), JDK 17 (Temurin), Android SDK 36 +
build-tools 36, Gradle 9.1.0, AGP via Flutter template, applicationId
`com.sina.mobility`.

### Toolchain fixes applied to make it build on modern Gradle/AGP
These are already in the committed `android/` config and `pubspec.yaml`:

- **`speech_to_text` 6.x → 7.x** — 6.x used `jcenter()` (removed in Gradle 9).
  Its `listen()` now uses `SpeechListenOptions`.
- **`tflite_flutter` 0.10.x → 0.11.x** — 0.10 used `UnmodifiableUint8ListView`,
  removed in Dart 3.
- **`vibration` 1.9 → 2.x** — 1.9 referenced the removed v1 Android embedding.
- **`gradle.properties`**: `kotlin.jvm.target.validation.mode=warning` —
  tflite_flutter compiles Java at 1.8 / Kotlin at 17; relaxes the strict check.
- **`app/build.gradle.kts`**: core-library desugaring (for
  `flutter_local_notifications`); `minSdk 24`; `abiFilters` arm64/armv7;
  `resolutionStrategy.force` TensorFlow Lite **2.16.1** (the 2.11 AARs shared the
  `org.tensorflow.lite` namespace, which AGP 8 rejects); R8 disabled for release
  (we call TFLite via FFI, and the optional GPU-delegate classes aren't present).
- **`build.gradle.kts` (root)**: bumps any plugin compiling below SDK 34 up to 36
  (tflite_flutter pins compileSdk 31, incompatible with its newer androidx deps).

### Object detection
`assets/models/yolov8n.tflite` is bundled (exported from `yolov8n.pt` at
imgsz=320: input `[1,320,320,3]`, output `[1,84,2100]`). Detection runs on
device with no setup. If you re-export the model, run `flutter clean` before
rebuilding — Flutter caches the asset manifest and won't pick up a replaced
file in a globbed asset directory otherwise.

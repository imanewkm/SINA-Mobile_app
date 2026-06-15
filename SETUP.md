# SINA — Setup & Run Guide

This guide makes the **SINA** Flutter app build and run on a fresh machine.
It is written so a human *or* an AI coding agent can follow it top to bottom.

SINA is a **fully offline, Android-first** voice-guided mobility assistant for
visually impaired users (on-device YOLOv8n obstacle detection + TTS/STT in
French/English/Arabic + GPS + emergency SOS). There is no server, no cloud, and
no API keys to configure.

---

## 1. What you get when you clone

| Item | In the repo? | Notes |
|------|--------------|-------|
| Flutter app source (`sina_mobile/`) | ✅ | The whole app |
| **YOLO model** `sina_mobile/assets/models/yolov8n.tflite` | ✅ tracked (5.9 MB) | Detection works out of the box — no download |
| Earcon audio `assets/audio/beep.wav` | ✅ | Spatial cues |
| Optional depth model `assets/models/depth.tflite` | ❌ not included | Optional; app falls back to area-based distance |
| Training weights (`*.pt`), datasets, `runs/` | ❌ gitignored | Not needed to run the app |
| `report/`, Claude files (`.claude/`, `CLAUDE.md`) | ❌ gitignored | Not part of the app |

> **No model step required.** Because the `.tflite` is committed, you do **not**
> need to export or download a model to run obstacle detection.

---

## 2. Prerequisites

Install these once:

1. **Flutter SDK** — stable channel. The project requires:
   - Dart SDK `>=3.3.0 <4.0.0`
   - Flutter `>=3.19.0` (use the latest stable; newer is fine)
   - Get it from <https://docs.flutter.dev/get-started/install> and add
     `flutter/bin` to your `PATH`.
2. **Android toolchain** (this app is Android-first):
   - Android Studio **or** the Android command-line tools + a JDK 17.
   - An Android SDK with platform tools. Accept licenses:
     `flutter doctor --android-licenses`
3. **A target to run on** — either:
   - A physical Android phone (**Android 7.0 / API 24 or newer**) with USB
     debugging enabled, **or**
   - An Android emulator (API 24+). Note: the **camera/detection and on-device
     speech features need a real device**; an emulator is fine for UI work only.

Verify the environment:

```bash
flutter --version       # confirm stable, Dart >= 3.3
flutter doctor -v       # all Android checks should be green
```

---

## 3. Get the code & dependencies

```bash
git clone https://github.com/imanewkm/SINA-Navigation_system.git
cd SINA-Navigation_system/sina_mobile
flutter pub get
```

`flutter pub get` resolves all plugins listed in `pubspec.yaml` (camera,
tflite_flutter, flutter_tts, speech_to_text, geolocator, flutter_map,
permission_handler, etc.). No manual native setup is required.

---

## 4. Run the app

Plug in a device (`flutter devices` to confirm it's detected), then:

```bash
# Debug build on the connected device
flutter run

# Release APK → build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release
```

Install a built APK manually with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Android build facts (already configured — no action needed)
- **minSdk 24**, ABIs `arm64-v8a` + `armeabi-v7a`.
- Release builds **sign with the debug keystore**, so `flutter build apk
  --release` works with **no signing setup**.
- **R8 / code shrinking is disabled** (TFLite uses FFI + optional GPU delegate
  classes). This is intentional.

---

## 5. First launch on the device

On first run the app requests runtime permissions — **grant all** for full
functionality:

- **Camera** — obstacle detection
- **Microphone** — voice commands / on-device speech
- **Location** — GPS guidance and SOS location
- **Notifications** — SOS alert
- **Phone / SMS** — emergency SOS call + text

For the best voice experience, the device should have the **Google TTS engine**
with FR/EN/AR voice data and the matching speech-recognition language packs
(Android Settings → System → Languages → Text-to-speech / Voice input). The app
degrades gracefully if a language pack is missing.

Quick smoke test once running:
1. The app greets you and starts listening.
2. Say "open camera" (or "ouvre la caméra") → camera preview appears.
3. Point at a person/chair → SINA announces the obstacle with direction +
   distance.

---

## 6. Verify the project is healthy (for agents / CI)

From `sina_mobile/`:

```bash
flutter analyze     # expected: "No issues found!"
flutter test        # expected: all tests pass (pure-logic unit tests)
```

Both should be clean on a fresh checkout. Use these as the definition of "the
project works" when no device is available.

---

## 7. Optional: regenerate / swap the YOLO model

Not needed for normal use. Only if you want to retrain or shrink the model:

- **Train / re-export the model**: use the Colab notebook
  `scripts/sina_custom_model_colab.ipynb` (imgsz=320, exports float16 TFLite and
  prints the class indices). The local TF export chain does **not** install on
  Windows / Python 3.12 — use Colab or Linux.
- After swapping the `.tflite`, update `cocoLabels` / `targetClassIds` in
  `sina_mobile/lib/constants/yolo_config.dart` and the translations in
  `constants/labels.dart`. The Dart decoder is class-count-agnostic, so extra
  classes need no other code changes.
- **int8-quantized** model: the runtime auto-detects quantized I/O — just drop in
  the `.tflite`, no code change.
- **Optional depth model**: install/calibrate `assets/models/depth.tflite` with
  `scripts/export_depth_tflite.py`. Absent → depth silently off.

See `sina_mobile/assets/models/README.md` for model details.

---

## 8. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `flutter doctor` flags Android licenses | `flutter doctor --android-licenses` and accept all |
| Build fails on Gradle/JDK | Use **JDK 17**; let Android Studio install the matching Gradle/NDK |
| App runs but no detection | Confirm `assets/models/yolov8n.tflite` exists; camera permission granted; test on a **real device** |
| No speech / wrong accent | Install the Google TTS engine + the FR/EN/AR voice and speech packs on the device |
| Camera works in debug but app is killed in background | Expected on aggressive OEMs; the foreground service keeps detection alive while the screen is on |
| Emulator: camera/mic broken | Use a physical device for camera, speech, and SOS features |

---

## 9. Hard constraints (do not break)

- ❌ No authentication, no cloud, no server — single-user, trust-based.
- ✅ 100% free — no paid APIs/subscriptions.
- ✅ Offline-first — the family map is the only network-dependent feature.
- ✅ Must run on budget phones (Snapdragon 400+, minSdk 24).

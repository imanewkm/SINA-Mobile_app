# SINA — Voice-Guided Mobility Assistant (Mobile)

SINA is a free, open-source Android app that helps visually impaired users move
around safely. It runs **fully offline on the phone**: the camera detects
obstacles with an on-device YOLOv8n model, and SINA speaks guidance in
**French, English, or Arabic**. Voice commands, GPS, and an emergency SOS round
out the experience.

> This repository now contains **only the Flutter mobile app** (`sina_mobile/`).
> The earlier Flask web prototype has been removed; its behaviour was ported
> into the mobile app.

## Features

- **Real-time obstacle detection** (camera + YOLOv8n TFLite, on-device)
- **Voice commands** and spoken feedback (TTS) in FR / EN / AR
- **On-device speech recognition** (OS speech engine — no server)
- **Distance & direction guidance** ("car very close on your left")
- **Emergency SOS** — call + WhatsApp to a family contact, with GPS location
- **GPS tracking** and a family map screen
- **No accounts, no cloud** — trust-based, single-user, offline

## Project layout

```
sina_mobile/            # The Flutter app (see sina_mobile/lib)
  lib/
    controller/         # AppController — the app brain / state machine
    services/           # detector, stt, tts, gps, alerts, settings
    screens/            # main, settings, family
    widgets/            # camera view, bbox overlay, orb, banner
    constants/          # yolo config, commands, labels/translations
  assets/models/        # yolov8n.tflite (object detection model)
scripts/                # Model training / export tooling (Python)
yolov8n.pt              # Source YOLOv8n weights (export the TFLite from this)
```

## Build & run

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(>= 3.19) and an Android device/emulator.

```bash
cd sina_mobile
flutter pub get
flutter run                 # debug on a connected device
flutter build apk --release # release APK (build/app/outputs/flutter-apk/)
```

### Detection model

The app loads `sina_mobile/assets/models/yolov8n.tflite`. If it's missing the
app still runs (camera, voice, GPS, SOS) but won't announce obstacles. To
(re)generate the model from the bundled weights:

```bash
pip install ultralytics
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='tflite', imgsz=320, int8=True)"
cp yolov8n_saved_model/*int8*.tflite sina_mobile/assets/models/yolov8n.tflite
```

## License

MIT. Free and open-source, built for accessibility.

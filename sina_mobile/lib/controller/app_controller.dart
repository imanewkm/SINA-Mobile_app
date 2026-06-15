import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants/commands.dart';
import '../constants/labels.dart';
import '../constants/yolo_config.dart';
import '../models/app_state.dart';
import '../models/detection.dart';
import '../models/emergency_contact.dart';
import '../services/alert_service.dart';
import '../services/call_service.dart';
import '../services/depth_service.dart';
import '../services/detector_service.dart';
import '../services/gps_service.dart';
import '../services/ocr_service.dart';
import '../services/settings_service.dart';
import '../services/sms_service.dart';
import '../services/spatial_audio_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';

/// Global navigator key so the controller can push Settings/Family screens
/// in response to voice commands.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Central app brain. Coordinates STT/TTS/detector/GPS/alerts and runs the
/// idle → listening → responding state machine ported from assistant.js.
class AppController extends ChangeNotifier {
  AppController._();
  static final AppController instance = AppController._();

  /// Native → Dart channel for hardware triggers (volume-key SOS). Mirrors the
  /// channel name in MainActivity.kt.
  static const MethodChannel _sosChannel =
      MethodChannel('com.sina.mobility/sos');

  /// Dart → native channel to start/stop the foreground service.
  static const MethodChannel _serviceChannel =
      MethodChannel('com.sina.mobility/service');

  final Battery _battery = Battery();

  final SettingsService settings = SettingsService.instance;
  final TtsService _tts = TtsService();
  final SttService _stt = SttService();
  final DetectorService detector = DetectorService();
  final GpsService gps = GpsService();
  final AlertService alerts = AlertService();
  final SpatialAudioService _spatial = SpatialAudioService();
  final OcrService _ocr = OcrService();
  final DepthService depth = DepthService();
  final SmsService _sms = SmsService();
  final CallService _phone = CallService();

  // ── Public reactive state ───────────────────────────────────────────────────
  AppState state = AppState.idle;
  String curLang = 'fr';
  bool get isRtl => curLang == 'ar';
  bool cameraOn = false;
  String statusText = '';
  String? bannerText;

  /// True when a screen reader (TalkBack/VoiceOver) is active. Set from the UI's
  /// accessibility observer; used to give a spoken "your turn" cue that SINA's
  /// own TTS never provides.
  bool screenReaderOn = false;
  DateTime _lastSrCue = DateTime.fromMillisecondsSinceEpoch(0);

  void updateAccessibility(bool screenReader) => screenReaderOn = screenReader;

  /// Bounding boxes for the overlay. Kept in its own notifier so per-frame box
  /// updates repaint only the overlay instead of rebuilding the whole screen.
  final ValueNotifier<List<RawBox>> boxesNotifier =
      ValueNotifier<List<RawBox>>(const []);
  CameraController? cameraController;

  // ── Internal state ──────────────────────────────────────────────────────────
  bool _booted = false;
  /// True once the full welcome/tutorial has been spoken. Later activations
  /// (tapping the orb) give a short "I'm listening" cue instead of replaying it.
  bool _welcomed = false;
  bool _sosActive = false;
  Timer? _sosResumeT;
  Timer? _gpsMonitorT;
  /// True while waiting for the user to tap-confirm an SOS (false-alarm guard).
  /// The UI shows a full-screen tap target + the [sosCountdown] while true.
  bool sosConfirming = false;
  int sosCountdown = 0;
  /// Recurring "should I send a new location?" prompt after an SOS.
  Timer? _sosCheckInT;
  bool _locationSharingActive = false;
  /// Active guided voice dialog (SOS resend confirm, add-contact flow, …).
  _DialogStep _dialog = _DialogStep.none;
  String _draftName = '';
  String _draftPhone = '';
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAnnounce = DateTime.fromMillisecondsSinceEpoch(0);
  /// Inference gap in ms; raised on low battery / power-save (see _checkBattery).
  int _throttleMs = kInferenceThrottleMs;
  Map<String, List<String>> _lastScene = {};
  final List<Detection> _queue = [];
  bool _announcing = false;
  int _lastGpsWarningMs = 0;
  String? _lastLightState;
  DateTime _lastLightAnnounce = DateTime.fromMillisecondsSinceEpoch(0);

  String _label(AppState s) =>
      stateLabels[s.name]?[curLang] ?? stateLabels[s.name]?['fr'] ?? '';

  /// Multi-line diagnostics for the on-screen debug HUD.
  String get debugHud {
    final d = detector;
    final model = d.isLoaded
        ? (d.quantized ? 'OK-int8' : 'OK-float')
        : 'FAIL(${d.loadError})';
    final depthSrc = depth.isAvailable
        ? 'native'
        : (d.isDepthLoaded && settings.depthEnabled ? 'mono' : 'heuristic');
    return 'model:$model frames:${d.framesProcessed} raw:${d.lastRawCount} '
        'maxConf:${d.lastMaxConf.toStringAsFixed(2)}\n'
        'depth:$depthSrc raw:${d.lastDepthRaw.toStringAsFixed(2)}\n'
        'cam:${cameraOn ? "on" : "off"} state:${state.name} sos:$_sosActive\n'
        'stt:${_stt.lastStatus} err:${_stt.lastError} locOK:${_stt.localeAvailable(curLang)}\n'
        'heard:"${_stt.lastWords}"\n'
        'tts:${_tts.engine.split('.').last} lang:$curLang ttsLangOK:${_tts.langAvailable}';
  }

  // ── Boot ────────────────────────────────────────────────────────────────────
  Future<void> boot() async {
    if (_booted) return;
    _booted = true;
    await settings.init();
    curLang = settings.lang;
    await _tts.init();
    await alerts.init();
    await detector.init();
    await _spatial.init();
    await depth.init();
    statusText = _label(AppState.idle);
    _gpsMonitorT = Timer.periodic(const Duration(seconds: 15), (_) {
      _monitorGps();
      _checkBattery();
    });
    await _checkBattery();
    _sosChannel.setMethodCallHandler((call) async {
      if (call.method == 'sos') await triggerSOS();
    });
    notifyListeners();
  }

  // ── Foreground service (native) ─────────────────────────────────────────────
  Future<void> _startForegroundService() async {
    try {
      await _serviceChannel.invokeMethod('start');
    } catch (_) {}
  }

  Future<void> _stopForegroundService() async {
    try {
      await _serviceChannel.invokeMethod('stop');
    } catch (_) {}
  }

  // ── Battery-aware inference throttle ─────────────────────────────────────────
  /// Raises the inference gap when the battery is low or power-save is on, so a
  /// long walk doesn't drain the phone. Best-effort; never throws.
  Future<void> _checkBattery() async {
    try {
      final level = await _battery.batteryLevel;
      bool saver = false;
      try {
        saver = await _battery.isInBatterySaveMode;
      } catch (_) {}
      if (level <= 15 || saver) {
        _throttleMs = 400; // ~2.5 fps
      } else if (level <= 30) {
        _throttleMs = 220; // ~4.5 fps
      } else {
        _throttleMs = kInferenceThrottleMs;
      }
    } catch (_) {}
  }

  void _setState(AppState s) {
    state = s;
    statusText = _label(s);
    notifyListeners();
  }

  // ── Activation (tap-to-start overlay) ───────────────────────────────────────
  Future<void> activate() async {
    await Permission.microphone.request();
    await Permission.camera.request();
    await alerts.requestNotificationPermission();
    // Ask for SMS + call up front so the SOS path is never blocked mid-panic.
    await _sms.requestPermission();
    await _phone.requestPermission();

    final sttOk = await _stt.init();
    if (settings.gpsEnabled) {
      await gps.start();
    }
    if (!sttOk) {
      await _speak(pick(msgMicBlocked, curLang));
      try {
        await openAppSettings();
      } catch (_) {}
      return;
    }

    state = AppState.listening; // set before speak so loop resumes after
    // Full tutorial only on the first activation; a quick cue on every later tap.
    await _speak(_welcomed ? pick(msgResume, curLang) : t(curLang, 'welcome'));
    _welcomed = true;
    if (state != AppState.idle) {
      await Future.delayed(const Duration(milliseconds: 600));
      _startListening();
    }

    if (settings.autoCamera && !cameraOn) {
      startCamera();
    }
  }

  // ── Speaking ────────────────────────────────────────────────────────────────
  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _stt.cancel(); // mute mic while speaking
    _setState(AppState.responding);
    statusText = text;
    notifyListeners();
    await _tts.configure(
      lang: curLang,
      webSpeechRate: settings.speechRate,
      volume: settings.volume,
    );
    await _tts.speak(text);
  }

  Future<void> _speakThenListen(String text) async {
    await _speak(text);
    if (state != AppState.idle) {
      await Future.delayed(const Duration(milliseconds: 600));
      _startListening();
    }
  }

  // ── Listening loop ──────────────────────────────────────────────────────────
  void _startListening() {
    if (state == AppState.idle || _tts.isSpeaking || _announcing) return;
    _setState(AppState.listening);
    // Screen-reader users can't see the orb turn to "listening"; give them a
    // spoken turn-taking cue via TalkBack (debounced so it isn't chatty, and
    // not duplicated by SINA's own TTS which never says "listening").
    if (screenReaderOn) {
      final now = DateTime.now();
      if (now.difference(_lastSrCue).inSeconds >= 3) {
        _lastSrCue = now;
        SemanticsService.announce(
          _label(AppState.listening),
          isRtl ? TextDirection.rtl : TextDirection.ltr,
        );
      }
    }
    _stt.listen(curLang, _handle, _handleSttError);
  }

  void _handleSttError(String err) {
    if (state == AppState.idle) return;
    if (err == 'not-allowed') {
      _speak(pick(msgMicBlocked, curLang));
      return;
    }
    // empty / too-short / error → retry shortly (mirrors recorder.js)
    Future.delayed(const Duration(milliseconds: 600), _startListening);
  }

  // ── Command dispatch (port of handle() in assistant.js) ─────────────────────
  Future<void> _handle(String text) async {
    // An SOS phrase always takes over, even mid-dialog.
    if (commandMatches(text, 'sos', curLang)) {
      _resetDialog();
      await triggerSOS();
      return;
    }
    // A guided voice dialog (resend confirm / add-contact / clear) is in progress.
    if (_dialog != _DialogStep.none) {
      await _handleDialog(text);
      return;
    }
    final key = matchCommand(text, curLang);
    switch (key) {
      case 'list_contacts':
        await listContacts();
        return;
      case 'add_contact':
        await startAddContact();
        return;
      case 'remove_contacts':
        await startClearContacts();
        return;
      case 'sos':
        await triggerSOS();
        return;
      case 'camera_on':
        await startCamera();
        return;
      case 'camera_off':
        await stopCamera();
        return;
      case 'what_see':
        await describeScene();
        return;
      case 'read_text':
        await readText();
        return;
      case 'settings':
        await openSettings();
        return;
      case 'lang_fr':
        await setLang('fr');
        return;
      case 'lang_en':
        await setLang('en');
        return;
      case 'lang_ar':
        await setLang('ar');
        return;
      case 'volume_up':
        await adjustVolume(0.1);
        return;
      case 'volume_down':
        await adjustVolume(-0.1);
        return;
      case 'gps_on':
        await setGpsState(true);
        return;
      case 'gps_off':
        await setGpsState(false);
        return;
      case 'where_am_i':
        await announceLocation();
        return;
      case 'status':
        await announceStatus();
        return;
      case 'help':
        await announceHelp();
        return;
      default:
        await _speakThenListen(t(curLang, 'not_found'));
    }
  }

  // ── Camera ──────────────────────────────────────────────────────────────────
  Future<void> startCamera() async {
    if (cameraOn) {
      await _speakThenListen(t(curLang, 'camera_on'));
      return;
    }
    final granted = await Permission.camera.request().isGranted;
    if (!granted) {
      await _speakThenListen(t(curLang, 'camera_error'));
      return;
    }
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        await _speakThenListen(t(curLang, 'camera_error'));
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.startImageStream(_onFrame);
      cameraController = controller;
      cameraOn = true;
      await WakelockPlus.enable();
      await _startForegroundService();
      notifyListeners();
      _haptic(_Sfx.activate);
      await _speakThenListen(t(curLang, 'camera_on'));
    } catch (e) {
      cameraOn = false;
      cameraController = null;
      notifyListeners();
      await _speakThenListen(t(curLang, 'camera_error'));
    }
  }

  Future<void> stopCamera() async {
    try {
      await cameraController?.stopImageStream();
    } catch (_) {}
    try {
      await cameraController?.dispose();
    } catch (_) {}
    cameraController = null;
    cameraOn = false;
    boxesNotifier.value = const [];
    _lastScene = {};
    await WakelockPlus.disable();
    await _stopForegroundService();
    notifyListeners();
    _haptic(_Sfx.stop);
    await _speakThenListen(t(curLang, 'camera_off'));
  }

  void _onFrame(CameraImage image) async {
    final now = DateTime.now();
    // Inference now runs off the UI isolate and drops frames while busy, so we
    // can attempt detection often; the detector's own backpressure caps the
    // real rate. (Announcements are still rate-limited by kDetectionCooldownSec.)
    if (now.difference(_lastInfer).inMilliseconds < _throttleMs) {
      return;
    }
    if (!detector.isLoaded) return;
    _lastInfer = now;
    // async-void frame handler: an uncaught error here would become an unhandled
    // async exception, so the whole detection pass is guarded.
    try {
      final conf = confidenceForSensitivity(settings.sensitivity);
      // When the "warn about unrecognized objects" option is on, also keep boxes
      // down to a lower generic floor; they're flagged uncertain by the detector.
      final generic =
          settings.announceUnknownObjects ? genericConfidenceFor(conf) : conf;
      // Distance-source priority: native ARCore/ARKit metres > monocular model
      // metres (set inside the isolate when a depth model is loaded) > the area
      // heuristic. The monocular pass runs in-isolate per [settings.depthEnabled].
      final boxes = await detector.detect(image,
          confThreshold: conf,
          genericConf: generic,
          runDepth: settings.depthEnabled);
      // A native depth provider (ARCore via SharedCamera / ARKit) overrides the
      // monocular estimate where it returns a valid (> 0) reading; otherwise the
      // monocular value (or the heuristic) stands.
      if (depth.isAvailable && boxes.isNotEmpty) {
        final centers = boxes
            .map((b) => Offset((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2))
            .toList();
        final meters = await depth.depthAt(centers);
        if (meters.length == boxes.length) {
          for (int i = 0; i < boxes.length; i++) {
            if (meters[i] > 0) boxes[i].distanceMeters = meters[i];
          }
        }
      }
      boxesNotifier.value = boxes; // repaints only the overlay
      _processTrafficLights(boxes, now);
      _processScene(boxes, now);
    } catch (_) {
      // Drop this frame; the next one will try again.
    }
  }

  /// Distance tier for a box. Priority: real depth (native/monocular) → a
  /// class-aware area estimate (uses the object's known real size) → the plain
  /// area heuristic for classes with no known size.
  String _distanceTier(RawBox b) {
    final m = b.distanceMeters;
    if (m != null && m > 0) return distanceTierFromMeters(m);
    final est = distanceFromBoxArea(b.label, b.x1, b.y1, b.x2, b.y2);
    if (est > 0) return distanceTierFromMeters(est);
    return estimateDistance(b.x1, b.y1, b.x2, b.y2, 1, 1);
  }

  // ── Traffic-light state (street crossing) ───────────────────────────────────
  /// Announce the colour of the most confident traffic light. Speaks on state
  /// change immediately, and re-reminds at most once per (2× cooldown) so a red
  /// light keeps warning without spamming.
  void _processTrafficLights(List<RawBox> boxes, DateTime now) {
    RawBox? best;
    for (final b in boxes) {
      if (b.classId == kTrafficLightClassId && b.lightState != null) {
        if (best == null || b.confidence > best.confidence) best = b;
      }
    }
    if (best == null) {
      _lastLightState = null;
      return;
    }
    final state = best.lightState!;
    final changed = state != _lastLightState;
    final elapsed = now.difference(_lastLightAnnounce).inMilliseconds / 1000.0;
    if (!changed && elapsed <= kDetectionCooldownSec * 2) return;
    _lastLightState = state;
    _lastLightAnnounce = now;
    _enqueue(Detection(
      label: 'traffic light',
      distance: _distanceTier(best),
      position: estimatePosition(best.x1, best.x2, 1),
      confidence: best.confidence,
      box: const Rect.fromLTRB(0, 0, 0, 0),
      spoken: buildTrafficLightSpoken(state),
    ));
  }

  // ── Scene processing (port of Camera._loop in app.py) ───────────────────────
  void _processScene(List<RawBox> boxes, DateTime now) {
    // Build scene: keep closest instance per label.
    final scene = <String, List<String>>{};
    for (final b in boxes) {
      // Traffic lights are announced with their colour by _processTrafficLights.
      if (b.label == 'traffic light') continue;
      final dist = _distanceTier(b);
      // Unnamed (low-confidence) detections are only worth a generic warning
      // when they're near; far uncertain boxes are too noisy to announce.
      if (b.uncertain && dist != 'very_close' && dist != 'close') continue;
      final label = b.uncertain ? 'object' : b.label;
      final pos = estimatePosition(b.x1, b.x2, 1);
      final existing = scene[label];
      if (existing == null ||
          distanceRankIndex(dist) < distanceRankIndex(existing[0])) {
        scene[label] = [dist, pos];
      }
    }

    final changed = !_sceneEquals(scene, _lastScene);
    final elapsed = now.difference(_lastAnnounce).inMilliseconds / 1000.0;
    if (!changed || elapsed <= kDetectionCooldownSec) return;
    _lastAnnounce = now;
    _lastScene = scene;
    if (scene.isEmpty) return;

    // Group by (distance, position).
    final groups = <String, List<String>>{};
    scene.forEach((label, dp) {
      final k = '${dp[0]}|${dp[1]}';
      groups.putIfAbsent(k, () => []).add(label);
    });

    final total = scene.length;
    if (total > kManyObstaclesThreshold) {
      // Announce the closest group as a summary.
      for (final dist in distanceRank) {
        var found = false;
        for (final pos in const ['left', 'center', 'right']) {
          final k = '$dist|$pos';
          if (groups.containsKey(k)) {
            _enqueue(Detection(
              label: 'many',
              distance: dist,
              position: pos,
              confidence: 1.0,
              box: const Rect.fromLTRB(0, 0, 0, 0),
              spoken: buildManySpoken(dist),
            ));
            found = true;
            break;
          }
        }
        if (found) break;
      }
    } else {
      groups.forEach((k, labels) {
        final parts = k.split('|');
        final dist = parts[0];
        final pos = parts[1];
        final spoken = labels.length > 1
            ? buildGroupedSpoken(labels, dist, pos)
            : buildSpoken(labels[0], dist, pos);
        _enqueue(Detection(
          label: labels.join('+'),
          distance: dist,
          position: pos,
          confidence: 1.0,
          box: const Rect.fromLTRB(0, 0, 0, 0),
          spoken: spoken,
        ));
      });
    }
  }

  bool _sceneEquals(Map<String, List<String>> a, Map<String, List<String>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || o[0] != e.value[0] || o[1] != e.value[1]) return false;
    }
    return true;
  }

  // ── Detection announcement queue ────────────────────────────────────────────
  void _enqueue(Detection d) {
    _queue.add(d);
    if (!_announcing) _drainQueue();
  }

  Future<void> _drainQueue() async {
    if (_sosActive || sosConfirming) {
      _queue.clear();
      _announcing = false;
      return;
    }
    if (_queue.isEmpty) {
      _announcing = false;
      if (state != AppState.idle && !_tts.isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 600));
        _startListening();
      }
      return;
    }
    _announcing = true;
    final d = _queue.removeAt(0);
    bannerText = d.spokenFor(curLang);
    notifyListeners();
    // Spatial earcon: stereo-panned by position, pitched by distance — conveys
    // where/how close before the spoken sentence finishes.
    if (settings.soundEffects) {
      _spatial.cue(d.position, d.distance);
    }
    // Urgency tiers: a close/very-close hazard fires a strong, distinct buzz
    // *before* the spoken sentence so the user reacts to the cue immediately,
    // not after a full sentence has finished playing.
    final urgent = d.distance == 'very_close' || d.distance == 'close';
    if (urgent) {
      _haptic(_Sfx.danger);
      await Future.delayed(const Duration(milliseconds: 150));
    } else {
      _haptic(_Sfx.detection);
    }
    await _speak(d.spokenFor(curLang));
    await Future.delayed(const Duration(milliseconds: 500));
    _drainQueue();
  }

  // ── Describe scene ──────────────────────────────────────────────────────────
  /// Describe what's *currently* in view, recomputed from the latest frame's
  /// boxes (not the last enqueued announcement, which may already be stale).
  Future<void> describeScene() async {
    if (!cameraOn) {
      await _speakThenListen(pick(msgOpenCameraToSee, curLang));
      return;
    }
    final boxes = boxesNotifier.value;
    final scene = <String, List<String>>{};
    for (final b in boxes) {
      if (b.label == 'traffic light') continue;
      final dist = _distanceTier(b);
      if (b.uncertain && dist != 'very_close' && dist != 'close') continue;
      final label = b.uncertain ? 'object' : b.label;
      final pos = estimatePosition(b.x1, b.x2, 1);
      final existing = scene[label];
      if (existing == null ||
          distanceRankIndex(dist) < distanceRankIndex(existing[0])) {
        scene[label] = [dist, pos];
      }
    }
    if (scene.isEmpty) {
      await _speakThenListen(pick(msgNothingSeen, curLang));
      return;
    }

    final groups = <String, List<String>>{};
    scene.forEach((label, dp) {
      groups.putIfAbsent('${dp[0]}|${dp[1]}', () => []).add(label);
    });

    final sentences = <String>[];
    if (scene.length > kManyObstaclesThreshold) {
      for (final dist in distanceRank) {
        var found = false;
        for (final pos in const ['left', 'center', 'right']) {
          if (groups.containsKey('$dist|$pos')) {
            sentences.add(pick(buildManySpoken(dist), curLang));
            found = true;
            break;
          }
        }
        if (found) break;
      }
    } else {
      groups.forEach((k, labels) {
        final parts = k.split('|');
        final spoken = labels.length > 1
            ? buildGroupedSpoken(labels, parts[0], parts[1])
            : buildSpoken(labels[0], parts[0], parts[1]);
        sentences.add(pick(spoken, curLang));
      });
    }
    await _speakThenListen(sentences.join('. '));
  }

  // ── Read Text (OCR) ─────────────────────────────────────────────────────────
  /// Capture a still frame and read any text aloud (Latin script). The image
  /// stream must be paused for takePicture(), then resumed.
  Future<void> readText() async {
    final cam = cameraController;
    if (!cameraOn || cam == null || !cam.value.isInitialized) {
      await _speakThenListen(pick(msgOpenCameraToSee, curLang));
      return;
    }
    await _speak(pick(msgReadingText, curLang));
    String text = '';
    try {
      if (cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
      final shot = await cam.takePicture();
      text = await _ocr.readFromFile(shot.path);
    } catch (_) {
      text = '';
    } finally {
      try {
        await cam.startImageStream(_onFrame);
      } catch (_) {}
    }
    await _speakThenListen(text.isEmpty ? pick(msgNoText, curLang) : text);
  }

  // ── Language ────────────────────────────────────────────────────────────────
  Future<void> setLang(String lang) async {
    curLang = lang;
    settings.lang = lang;
    notifyListeners();
    await _speakThenListen(t(curLang, 'welcome'));
  }

  // ── Volume ──────────────────────────────────────────────────────────────────
  Future<void> adjustVolume(double delta) async {
    final vol = (settings.volume + delta).clamp(0.0, 1.0);
    settings.volume = vol;
    final pct = (vol * 100).round();
    _haptic(_Sfx.ready);
    await _speakThenListen(pick(msgVolume, curLang).replaceAll('{pct}', '$pct'));
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────
  Future<void> setGpsState(bool enabled) async {
    settings.gpsEnabled = enabled;
    notifyListeners();
    if (enabled) {
      await gps.start();
      _haptic(_Sfx.detection);
      await _speakThenListen(pick(msgGpsOn, curLang));
    } else {
      await gps.stop();
      _haptic(_Sfx.stop);
      await _speakThenListen(pick(msgGpsOff, curLang));
    }
  }

  Future<void> announceLocation() async {
    if (gps.hasFix) {
      await _speakThenListen(_locationMessage(gps.lat!, gps.lng!));
    } else {
      final pos = await gps.currentPosition();
      if (pos != null) {
        await _speakThenListen(_locationMessage(pos.latitude, pos.longitude));
      } else {
        await _speakThenListen(pick(msgLocationUnavailable, curLang));
      }
    }
  }

  String _locationMessage(double lat, double lng) {
    final la = lat.toStringAsFixed(4);
    final lo = lng.toStringAsFixed(4);
    switch (curLang) {
      case 'ar':
        return 'خط العرض $la، خط الطول $lo';
      case 'en':
        return 'Latitude $la, longitude $lo';
      default:
        return 'Latitude $la, longitude $lo';
    }
  }

  Future<void> announceStatus() async {
    final msg = buildStatusMessage(
      curLang,
      cameraOn: cameraOn,
      gpsOn: settings.gpsEnabled || gps.hasFix,
    );
    await _speakThenListen(msg);
  }

  Future<void> announceHelp() async {
    await _speakThenListen(pick(msgHelp, curLang));
  }

  void _monitorGps() {
    if (!settings.gpsEnabled) return;
    if (gps.isStale(thresholdSec: 30)) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastGpsWarningMs > 30000) {
        _lastGpsWarningMs = nowMs;
        statusText = pick(msgGpsStale, curLang);
        notifyListeners();
        gps.currentPosition();
      }
    }
  }

  // ── Settings / Family navigation ────────────────────────────────────────────
  Future<void> openSettings() async {
    await _speak(pick(msgOpeningSettings, curLang));
    stopListeningToIdle(keepCamera: true);
    await navigatorKey.currentState?.pushNamed('/settings');
    // On return, re-apply language and resume listening.
    curLang = settings.lang;
    await _tts.configure(
      lang: curLang,
      webSpeechRate: settings.speechRate,
      volume: settings.volume,
    );
    state = AppState.listening;
    notifyListeners();
    _startListening();
  }

  void openFamily() {
    navigatorKey.currentState?.pushNamed('/family');
  }

  // ── SOS ─────────────────────────────────────────────────────────────────────
  /// Entry point for every SOS trigger (voice, long-press, volume keys). When
  /// the confirm option is on, requires a tap within a 10s voiced countdown to
  /// avoid false alarms; otherwise sends immediately.
  Future<void> triggerSOS() async {
    if (sosConfirming) return; // already awaiting confirmation
    if (settings.confirmSos) {
      await _beginSosConfirm();
      return;
    }
    await _sendSos();
  }

  /// Announce the SOS, then wait up to 10s (voiced countdown) for a screen tap.
  Future<void> _beginSosConfirm() async {
    sosConfirming = true;
    sosCountdown = 10;
    _queue.clear();
    await _stt.cancel();
    _haptic(_Sfx.alert);
    state = AppState.responding;
    statusText = pick(msgSosConfirmPrompt, curLang);
    notifyListeners();
    await _tts.configure(
      lang: curLang,
      webSpeechRate: settings.speechRate,
      volume: settings.volume,
    );
    await _tts.speak(pick(msgSosConfirmPrompt, curLang));
    if (!sosConfirming) return; // tapped during the prompt
    // Sequential countdown so spoken numbers never overlap; a tap flips
    // sosConfirming and breaks the loop early.
    while (sosConfirming && sosCountdown > 0) {
      notifyListeners();
      try {
        await _tts.speak('$sosCountdown');
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 550));
      if (!sosConfirming) return;
      sosCountdown -= 1;
    }
    if (sosConfirming) await _cancelSosConfirm();
  }

  /// Called when the user taps the confirm overlay — send the alert for real.
  Future<void> confirmSosNow() async {
    if (!sosConfirming) return;
    sosConfirming = false;
    sosCountdown = 0;
    notifyListeners();
    await _tts.stop();
    _haptic(_Sfx.activate);
    await _sendSos();
  }

  /// Countdown expired with no tap — treat as a false alarm and resume listening.
  Future<void> _cancelSosConfirm() async {
    sosConfirming = false;
    sosCountdown = 0;
    notifyListeners();
    await _tts.stop();
    _haptic(_Sfx.stop);
    await _speakThenListen(pick(msgSosCancelled, curLang));
  }

  Future<void> _sendSos() async {
    _sosActive = true;
    _queue.clear();
    _sosResumeT?.cancel();
    _sosResumeT = Timer(const Duration(seconds: 10), () {
      _sosActive = false;
    });

    _haptic(_Sfx.alert);

    final pos = await gps.currentPosition();
    final lat = pos?.latitude;
    final lng = pos?.longitude;
    await alerts.addAlert(pick(msgSosAlert, curLang), lat, lng);
    await alerts.showSosNotification(t(curLang, 'alert_sent'));

    final contacts = settings.emergencyContacts;
    if (contacts.isEmpty) {
      await _speak(pick(msgSosNoContact, curLang));
      if (state != AppState.idle) {
        await Future.delayed(const Duration(seconds: 1));
        _startListening();
      }
      return;
    }

    // Primary channel: a direct SMS to every contact (hands-free, works without
    // internet) carrying a Google Maps location link.
    final body = buildSosSms(curLang, lat, lng);
    int sent = 0;
    for (final c in contacts) {
      if (await _sms.send(c.phone, body)) sent++;
    }
    final smsOk = sent > 0;

    if (smsOk) {
      // Optionally ring the first contact so they're sure to notice the alert.
      if (settings.autoCallOnSos) {
        await _speak(pick(msgSosSmsSentCalling, curLang));
        await _placeCall(contacts.first.phone, body);
      } else {
        await _speak(pick(msgSosSmsSent, curLang));
      }
    } else {
      // No text got through — fall back to a call (+ WhatsApp if configured).
      await _speak(pick(msgSosSmsFailed, curLang));
      await _placeCall(contacts.first.phone, body);
    }

    // Begin recurring location-update check-ins.
    _startLocationSharing();

    if (state != AppState.idle) {
      await Future.delayed(const Duration(seconds: 1));
      _startListening();
    }
  }

  /// Ring [phone] directly; if the OS call can't be placed (no permission),
  /// fall back to the dialer, and to a WhatsApp deep link when configured.
  Future<void> _placeCall(String phone, String smsBody) async {
    final ok = await _phone.call(phone);
    if (!ok) {
      try {
        await launchUrl(Uri.parse('tel:$phone'),
            mode: LaunchMode.externalApplication);
      } catch (_) {}
      final whatsapp = settings.familyWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      if (whatsapp.isNotEmpty) {
        final msg = Uri.encodeComponent(smsBody);
        try {
          await launchUrl(Uri.parse('https://wa.me/$whatsapp?text=$msg'),
              mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
  }

  // ── Recurring location-update check-in ──────────────────────────────────────
  /// After an SOS, periodically ask whether to send a fresh location to the
  /// contacts. Interval is the user-set [SettingsService.sosCheckInMinutes].
  void _startLocationSharing() {
    _locationSharingActive = true;
    _sosCheckInT?.cancel();
    final mins = settings.sosCheckInMinutes;
    _sosCheckInT = Timer.periodic(
        Duration(minutes: mins), (_) => _promptResendLocation());
  }

  void _stopLocationSharing() {
    _locationSharingActive = false;
    if (_dialog == _DialogStep.resendConfirm) _resetDialog();
    _sosCheckInT?.cancel();
    _sosCheckInT = null;
  }

  Future<void> _promptResendLocation() async {
    if (!_locationSharingActive || state == AppState.idle) {
      _stopLocationSharing();
      return;
    }
    // Don't cut into the welcome/an obstacle warning, or interrupt another
    // dialog; the next tick will ask.
    if (_tts.isSpeaking || _announcing || _sosActive || sosConfirming ||
        _dialog != _DialogStep.none) {
      return;
    }
    _dialog = _DialogStep.resendConfirm;
    await _speakThenListen(pick(msgSosResendPrompt, curLang));
  }

  Future<void> _resendLocation() async {
    final contacts = settings.emergencyContacts;
    if (contacts.isEmpty) {
      _stopLocationSharing();
      await _speakThenListen(pick(msgSosNoContact, curLang));
      return;
    }
    final pos = await gps.currentPosition();
    final body = buildSosSms(curLang, pos?.latitude, pos?.longitude);
    int sent = 0;
    for (final c in contacts) {
      if (await _sms.send(c.phone, body)) sent++;
    }
    await alerts.addAlert(pick(msgSosAlert, curLang), pos?.latitude, pos?.longitude);
    await _speakThenListen(
        sent > 0 ? pick(msgSosResendSent, curLang) : pick(msgSosSmsFailed, curLang));
  }

  // ── Hands-free contact management ───────────────────────────────────────────
  void _resetDialog() {
    _dialog = _DialogStep.none;
    _draftName = '';
    _draftPhone = '';
  }

  /// Read the saved emergency contacts aloud (name + spaced-out number).
  Future<void> listContacts() async {
    final cs = settings.emergencyContacts;
    if (cs.isEmpty) {
      await _speakThenListen(pick(msgContactsNone, curLang));
      return;
    }
    final spoken = cs.map((c) {
      final num = c.phone.split('').join(' ');
      return c.name.trim().isEmpty ? num : '${c.name.trim()}: $num';
    }).join('. ');
    await _speakThenListen('${pick(msgContactsList, curLang)} $spoken');
  }

  /// Start the guided "add a contact" dialog (name → number → confirm).
  Future<void> startAddContact() async {
    _dialog = _DialogStep.addName;
    _draftName = '';
    _draftPhone = '';
    await _speakThenListen(pick(msgAskName, curLang));
  }

  Future<void> startClearContacts() async {
    if (settings.emergencyContacts.isEmpty) {
      await _speakThenListen(pick(msgContactsNone, curLang));
      return;
    }
    _dialog = _DialogStep.clearConfirm;
    await _speakThenListen(pick(msgClearContactsConfirm, curLang));
  }

  void _saveDraftContact() {
    final list = List<EmergencyContact>.from(settings.emergencyContacts)
      ..add(EmergencyContact(name: _draftName.trim(), phone: _draftPhone.trim()));
    settings.emergencyContacts = list;
  }

  String _cap(String s) {
    s = s.trim();
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  /// Route a transcript while a guided dialog is active.
  Future<void> _handleDialog(String text) async {
    switch (_dialog) {
      case _DialogStep.resendConfirm:
        if (isNegative(text, curLang)) {
          _resetDialog();
          _stopLocationSharing();
          await _speakThenListen(pick(msgSosSharingStopped, curLang));
        } else if (isAffirmative(text, curLang)) {
          _resetDialog();
          await _resendLocation();
        } else {
          // Not a yes/no — treat it as a normal command.
          _resetDialog();
          await _handle(text);
        }
        return;

      case _DialogStep.addName:
        if (isCancel(text, curLang)) {
          _resetDialog();
          await _speakThenListen(pick(msgContactCancelled, curLang));
          return;
        }
        _draftName = _cap(text);
        _dialog = _DialogStep.addPhone;
        await _speakThenListen(pick(msgAskPhone, curLang));
        return;

      case _DialogStep.addPhone:
        if (isCancel(text, curLang)) {
          _resetDialog();
          await _speakThenListen(pick(msgContactCancelled, curLang));
          return;
        }
        final digits = parseSpokenDigits(text, curLang);
        if (digits.replaceAll('+', '').length < 6) {
          await _speakThenListen(pick(msgPhoneTooShort, curLang));
          return; // stay in addPhone
        }
        _draftPhone = digits;
        _dialog = _DialogStep.addConfirm;
        final spaced = digits.split('').join(' ');
        await _speakThenListen(
            pick(msgConfirmNumber, curLang).replaceAll('{num}', spaced));
        return;

      case _DialogStep.addConfirm:
        if (isAffirmative(text, curLang)) {
          final name = _draftName;
          _saveDraftContact();
          _resetDialog();
          await _speakThenListen(pick(msgContactSaved, curLang)
              .replaceAll('{name}', name.isEmpty ? '' : name));
        } else if (isNegative(text, curLang)) {
          _draftPhone = '';
          _dialog = _DialogStep.addPhone;
          await _speakThenListen(pick(msgAskPhoneAgain, curLang));
        } else {
          await _speakThenListen(pick(msgYesOrNo, curLang));
        }
        return;

      case _DialogStep.clearConfirm:
        if (isAffirmative(text, curLang)) {
          settings.emergencyContacts = const [];
          _resetDialog();
          await _speakThenListen(pick(msgContactsCleared, curLang));
        } else {
          _resetDialog();
          await _speakThenListen(pick(msgContactsKept, curLang));
        }
        return;

      case _DialogStep.none:
        return;
    }
  }

  // ── Mic button (idle <-> listening) ─────────────────────────────────────────
  void toggleListening() {
    if (state == AppState.idle) {
      activate();
    } else {
      stopListeningToIdle();
    }
  }

  void stopListeningToIdle({bool keepCamera = false}) {
    _stt.cancel();
    _tts.stop();
    _queue.clear();
    _announcing = false;
    _stopLocationSharing();
    _resetDialog();
    if (!keepCamera && cameraOn) {
      stopCameraSilently();
    }
    _setState(AppState.idle);
  }

  Future<void> stopCameraSilently() async {
    try {
      await cameraController?.stopImageStream();
    } catch (_) {}
    try {
      await cameraController?.dispose();
    } catch (_) {}
    cameraController = null;
    cameraOn = false;
    boxesNotifier.value = const [];
    await WakelockPlus.disable();
    await _stopForegroundService();
    notifyListeners();
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  void onAppPause() {
    _stt.cancel();
    _tts.stop();
    if (cameraOn) {
      try {
        cameraController?.stopImageStream();
      } catch (_) {}
    }
  }

  void onAppResume() {
    if (cameraOn && cameraController != null) {
      try {
        cameraController!.startImageStream(_onFrame);
      } catch (_) {}
    }
    if (state != AppState.idle && !_tts.isSpeaking) {
      _startListening();
    }
  }

  // ── Haptics (replace web sfx) ───────────────────────────────────────────────
  Future<void> _haptic(_Sfx sfx) async {
    if (!settings.soundEffects) return;
    try {
      final has = await Vibration.hasVibrator();
      if (!has) return;
      switch (sfx) {
        case _Sfx.activate:
          Vibration.vibrate(duration: 50);
          break;
        case _Sfx.stop:
          Vibration.vibrate(duration: 100);
          break;
        case _Sfx.alert:
          Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
          break;
        case _Sfx.detection:
          Vibration.vibrate(duration: 30);
          break;
        case _Sfx.danger:
          // Strong double buzz — felt clearly before the spoken warning.
          Vibration.vibrate(pattern: [0, 180, 70, 180]);
          break;
        case _Sfx.ready:
          Vibration.vibrate(duration: 20);
          break;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _gpsMonitorT?.cancel();
    _sosResumeT?.cancel();
    _sosCheckInT?.cancel();
    detector.dispose();
    gps.stop();
    cameraController?.dispose();
    boxesNotifier.dispose();
    _spatial.dispose();
    _ocr.dispose();
    depth.dispose();
    super.dispose();
  }
}

enum _Sfx { activate, stop, alert, detection, danger, ready }

/// The guided voice dialog the controller is currently running, if any.
enum _DialogStep {
  none,
  resendConfirm, // "send a new location?" (yes/no)
  addName, // capturing the new contact's name
  addPhone, // capturing the new contact's number
  addConfirm, // reading the number back for confirmation
  clearConfirm, // "delete all contacts?" (yes/no)
}

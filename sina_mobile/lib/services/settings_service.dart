import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';

/// Thin typed wrapper over SharedPreferences. Keys and defaults match
/// settings.html exactly.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _prefs;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  // ── Keys ───────────────────────────────────────────────────────────────────
  static const _kLang = 'sina_lang';
  static const _kSpeechRate = 'sina_speechRate';
  static const _kVolume = 'sina_volume';
  static const _kSoundEffects = 'sina_soundEffects';
  static const _kHighContrast = 'sina_highContrast';
  static const _kSensitivity = 'sina_detectionSensitivity';
  static const _kGpsEnabled = 'sina_gpsEnabled';
  static const _kAutoCamera = 'sina_autoCamera';
  static const _kFamilyPhone = 'family_phone';
  static const _kFamilyWhatsapp = 'family_whatsapp';
  static const _kContacts = 'sina_emergency_contacts';
  static const _kAutoCall = 'sina_autoCallOnSos';
  static const _kCheckInMin = 'sina_sosCheckInMinutes';
  static const _kConfirmSos = 'sina_confirmSos';
  static const _kAnnounceUnknown = 'sina_announceUnknownObjects';
  static const _kDepthEnabled = 'sina_depthEnabled';
  static const _kFirstRunDone = 'sina_firstRunDone';

  // ── Language ────────────────────────────────────────────────────────────────
  String get lang => _prefs.getString(_kLang) ?? 'fr';
  set lang(String v) => _prefs.setString(_kLang, v);

  // ── TTS speech rate (web scale 0.7–1.3, default 0.95) ──────────────────────
  double get speechRate => _prefs.getDouble(_kSpeechRate) ?? 0.95;
  set speechRate(double v) => _prefs.setDouble(_kSpeechRate, v);

  // ── TTS volume (0.0–1.0) ───────────────────────────────────────────────────
  double get volume => _prefs.getDouble(_kVolume) ?? 1.0;
  set volume(double v) => _prefs.setDouble(_kVolume, v.clamp(0.0, 1.0));

  // ── Sound effects (haptics) ────────────────────────────────────────────────
  bool get soundEffects => _prefs.getBool(_kSoundEffects) ?? true;
  set soundEffects(bool v) => _prefs.setBool(_kSoundEffects, v);

  // ── High-contrast / large-target mode (low-vision users) ───────────────────
  bool get highContrast => _prefs.getBool(_kHighContrast) ?? false;
  set highContrast(bool v) => _prefs.setBool(_kHighContrast, v);

  // ── Detection sensitivity (1=quiet, 2=normal, 3=noisy) ─────────────────────
  int get sensitivity => _prefs.getInt(_kSensitivity) ?? 2;
  set sensitivity(int v) => _prefs.setInt(_kSensitivity, v.clamp(1, 3));

  // ── Announce low-confidence detections as a generic "object" (when near) ───
  bool get announceUnknownObjects => _prefs.getBool(_kAnnounceUnknown) ?? true;
  set announceUnknownObjects(bool v) => _prefs.setBool(_kAnnounceUnknown, v);

  // ── Monocular depth-based distance (runs only if depth.tflite is bundled) ──
  bool get depthEnabled => _prefs.getBool(_kDepthEnabled) ?? true;
  set depthEnabled(bool v) => _prefs.setBool(_kDepthEnabled, v);

  // ── GPS sharing ────────────────────────────────────────────────────────────
  bool get gpsEnabled => _prefs.getBool(_kGpsEnabled) ?? false;
  set gpsEnabled(bool v) => _prefs.setBool(_kGpsEnabled, v);

  // ── Auto-start camera ──────────────────────────────────────────────────────
  bool get autoCamera => _prefs.getBool(_kAutoCamera) ?? false;
  set autoCamera(bool v) => _prefs.setBool(_kAutoCamera, v);

  // ── Emergency contacts ─────────────────────────────────────────────────────
  String get familyPhone => _prefs.getString(_kFamilyPhone) ?? '';
  set familyPhone(String v) => _prefs.setString(_kFamilyPhone, v);

  String get familyWhatsapp => _prefs.getString(_kFamilyWhatsapp) ?? '';
  set familyWhatsapp(String v) => _prefs.setString(_kFamilyWhatsapp, v);

  // ── Multiple emergency contacts ────────────────────────────────────────────
  /// All emergency contacts. SOS texts every one and calls the first. If none
  /// are stored yet, a legacy single [familyPhone] is migrated transparently.
  List<EmergencyContact> get emergencyContacts {
    final raw = _prefs.getString(_kContacts);
    if (raw == null || raw.isEmpty) {
      final legacy = familyPhone.trim();
      return legacy.isEmpty
          ? const []
          : [EmergencyContact(name: '', phone: legacy)];
    }
    try {
      return (jsonDecode(raw) as List)
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .where((c) => c.phone.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  set emergencyContacts(List<EmergencyContact> v) {
    final clean = v.where((c) => c.phone.trim().isNotEmpty).toList();
    _prefs.setString(
        _kContacts, jsonEncode(clean.map((c) => c.toJson()).toList()));
    // Keep the legacy field in sync (used by the Test Call button / WhatsApp).
    familyPhone = clean.isEmpty ? '' : clean.first.phone;
  }

  // ── Auto-call after a successful SOS text ──────────────────────────────────
  bool get autoCallOnSos => _prefs.getBool(_kAutoCall) ?? true;
  set autoCallOnSos(bool v) => _prefs.setBool(_kAutoCall, v);

  // ── Recurring SOS check-in interval, in minutes (1–10) ─────────────────────
  int get sosCheckInMinutes => _prefs.getInt(_kCheckInMin) ?? 2;
  set sosCheckInMinutes(int v) => _prefs.setInt(_kCheckInMin, v.clamp(1, 10));

  // ── Require a tap to confirm an SOS (10s voiced countdown) ─────────────────
  bool get confirmSos => _prefs.getBool(_kConfirmSos) ?? true;
  set confirmSos(bool v) => _prefs.setBool(_kConfirmSos, v);

  // ── First-run onboarding completed (emergency contact set) ─────────────────
  bool get firstRunDone => _prefs.getBool(_kFirstRunDone) ?? false;
  set firstRunDone(bool v) => _prefs.setBool(_kFirstRunDone, v);

  // ── Generic raw access (for persisting the alert log JSON, etc.) ────────────
  String? getRaw(String key) => _prefs.getString(key);
  Future<void> setRaw(String key, String value) =>
      _prefs.setString(key, value);
}

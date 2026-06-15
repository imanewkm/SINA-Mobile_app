import 'package:flutter_tts/flutter_tts.dart';

import '../constants/labels.dart';

/// Wrapper around flutter_tts. Uses awaitSpeakCompletion so `speak()` returns
/// only when the utterance has finished — this drives the speak-then-listen loop.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  /// True while an utterance is playing (mic must stay muted).
  bool get isSpeaking => _speaking;
  bool _speaking = false;

  // Diagnostics (surfaced in the debug HUD).
  String engine = '-';
  bool langAvailable = true;

  // Last applied configuration. configure() is called before every utterance;
  // re-running the platform round-trips (getVoices/isLanguageAvailable/setVoice…)
  // each time adds latency to the speak→listen loop, so we skip them when nothing
  // changed. The voice is only re-resolved when the language changes.
  String? _appliedLang;
  double? _appliedRate;
  double? _appliedVolume;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    // Prefer Google TTS, which ships downloadable FR/EN/AR voices.
    try {
      final engines = await _tts.getEngines;
      if (engines is List &&
          engines.map((e) => e.toString()).contains('com.google.android.tts')) {
        await _tts.setEngine('com.google.android.tts');
        engine = 'com.google.android.tts';
      } else if (engines is List && engines.isNotEmpty) {
        engine = engines.first.toString();
      }
    } catch (_) {}
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// Map web speech rate (0.7–1.3) to flutter_tts scale (~0.2–0.8).
  static double mapRate(double webRate) {
    final r = (webRate - 0.7) / 0.6 * 0.6 + 0.2;
    return r.clamp(0.0, 1.0);
  }

  /// Whether the device TTS engine has voice data for [lang].
  Future<bool> isLanguageAvailable(String lang) async {
    try {
      final r = await _tts.isLanguageAvailable(langToLocale[lang] ?? 'en-US');
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }

  Future<void> configure({
    required String lang,
    required double webSpeechRate,
    required double volume,
  }) async {
    await init();
    // Nothing changed since the last utterance — skip the platform round-trips.
    if (lang == _appliedLang &&
        webSpeechRate == _appliedRate &&
        volume == _appliedVolume) {
      return;
    }
    final langChanged = lang != _appliedLang;
    final locale = langToLocale[lang] ?? 'fr-FR';
    if (langChanged) {
      langAvailable = await isLanguageAvailable(lang);
      await _tts.setLanguage(locale);
      // Pick a voice that matches the locale if one exists (better than the
      // engine's default fallback, which can mispronounce with another accent).
      try {
        final voices = await _tts.getVoices;
        if (voices is List) {
          final match = voices.cast<dynamic>().firstWhere(
            (v) {
              final loc = (v is Map ? v['locale']?.toString() : null) ?? '';
              return loc.toLowerCase().replaceAll('_', '-') ==
                  locale.toLowerCase();
            },
            orElse: () => null,
          );
          if (match is Map) {
            await _tts.setVoice(
                {'name': match['name'].toString(), 'locale': match['locale'].toString()});
          }
        }
      } catch (_) {}
      await _tts.setPitch(1.0);
    }
    if (webSpeechRate != _appliedRate) {
      await _tts.setSpeechRate(mapRate(webSpeechRate));
    }
    if (volume != _appliedVolume) {
      await _tts.setVolume(volume.clamp(0.0, 1.0));
    }
    _appliedLang = lang;
    _appliedRate = webSpeechRate;
    _appliedVolume = volume;
  }

  /// Speak [text] and resolve when finished (or on error).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await init();
    _speaking = true;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // ignore — treat as finished
    } finally {
      _speaking = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }
}

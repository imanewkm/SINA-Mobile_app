import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../constants/labels.dart';

/// On-device speech recognition via the OS-native engine (speech_to_text).
///
/// Uses partial results and finalizes the last partial when the engine pauses,
/// which is far more reliable across Android recognizers than waiting for a
/// "final" result that some engines never send.
class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool get isAvailable => _initialized && _speech.isAvailable;
  bool get isListening => _speech.isListening;

  // Diagnostics (surfaced in the debug HUD).
  String lastStatus = '-';
  String lastError = '-';
  String lastWords = '-';
  List<String> availableLocales = const [];

  void Function(String text)? _onResult;
  void Function(String error)? _onError;
  bool _delivered = false;
  String _partial = '';

  Future<bool> init() async {
    if (_initialized) return _speech.isAvailable;
    try {
      _initialized = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: false,
      );
      if (_initialized) {
        try {
          final locales = await _speech.locales();
          availableLocales = locales.map((l) => l.localeId).toList();
        } catch (_) {}
      }
    } catch (_) {
      _initialized = false;
    }
    return _initialized;
  }

  /// Whether a recognizer locale exists for [lang] (fr/en/ar).
  bool localeAvailable(String lang) {
    if (availableLocales.isEmpty) return true; // unknown → assume yes
    final want = (langToLocale[lang] ?? '').toLowerCase().replaceAll('-', '_');
    return availableLocales.any((l) {
      final ll = l.toLowerCase().replaceAll('-', '_');
      return ll == want || ll.startsWith('${lang.toLowerCase()}_');
    });
  }

  /// Resolve the best available recognizer locale id for [lang].
  String _resolveLocale(String lang) {
    final want = langToLocale[lang] ?? 'en-US';
    if (availableLocales.isEmpty) return want;
    final wantNorm = want.toLowerCase().replaceAll('-', '_');
    for (final l in availableLocales) {
      if (l.toLowerCase().replaceAll('-', '_') == wantNorm) return l;
    }
    for (final l in availableLocales) {
      if (l.toLowerCase().startsWith('${lang.toLowerCase()}_') ||
          l.toLowerCase().startsWith('${lang.toLowerCase()}-')) {
        return l;
      }
    }
    return want;
  }

  void _handleStatus(String status) {
    lastStatus = status;
    if ((status == 'done' || status == 'notListening') && !_delivered) {
      _finalize();
    }
  }

  void _handleError(SpeechRecognitionError e) {
    lastError = e.errorMsg;
    final err = e.errorMsg.toLowerCase();
    if (err.contains('permission') || err.contains('denied')) {
      _emit(null, 'not-allowed');
    } else if (_partial.trim().length >= 2) {
      _finalize();
    } else {
      // no_match / speech_timeout / network → let the loop retry
      _emit(null, 'empty');
    }
  }

  /// Listen for one utterance. [lang] is 'fr' | 'en' | 'ar'.
  Future<void> listen(
    String lang,
    void Function(String text) onResult,
    void Function(String error) onError,
  ) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) {
        onError('not-allowed');
        return;
      }
    }
    _onResult = onResult;
    _onError = onError;
    _delivered = false;
    _partial = '';

    try {
      await _speech.listen(
        onResult: _handleResult,
        localeId: _resolveLocale(lang),
        // Commands are short. A 1s end-of-speech pause finalizes the utterance
        // quickly (the loop re-listens immediately) instead of waiting 3s.
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 1),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {
      _emit(null, 'error');
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      _partial = words;
      lastWords = words;
    }
    if (result.finalResult) _finalize();
  }

  void _finalize() {
    if (_delivered) return;
    final text = _partial.trim().toLowerCase();
    if (text.length >= 2) {
      _emit(text, null);
    } else {
      _emit(null, 'empty');
    }
  }

  void _emit(String? text, String? error) {
    if (_delivered) return;
    _delivered = true;
    if (text != null) {
      _onResult?.call(text);
    } else {
      _onError?.call(error ?? 'error');
    }
  }

  Future<void> stop() async {
    _delivered = true;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    _delivered = true;
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}

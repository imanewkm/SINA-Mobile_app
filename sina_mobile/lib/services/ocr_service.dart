import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR for the "Read Text" capability (inspired by Seeing AI /
/// Envision). Runs fully offline via Google ML Kit's bundled Latin model.
///
/// NOTE: ML Kit's Flutter plugin ships Latin/Chinese/Devanagari/Japanese/Korean
/// scripts — there is no Arabic script model, so OCR reads Latin text only
/// (French/English). Arabic UI users can still read Latin signage.
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Recognize text in the image at [path]. Returns trimmed text ('' if none).
  Future<String> readFromFile(String path) async {
    try {
      final input = InputImage.fromFilePath(path);
      final result = await _recognizer.processImage(input);
      // Collapse newlines into spaces so TTS reads it as continuous speech.
      return result.text.replaceAll('\n', ' ').trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> dispose() async {
    try {
      await _recognizer.close();
    } catch (_) {}
  }
}

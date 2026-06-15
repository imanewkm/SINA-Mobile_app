import 'package:flutter/material.dart';

import '../constants/labels.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../widgets/contacts_editor.dart';

/// First-run setup: the user must add at least one emergency contact before the
/// assistant starts. Spoken on open for accessibility; contacts persist so this
/// screen is skipped on future launches.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final SettingsService s = SettingsService.instance;
  final TtsService _tts = TtsService();
  bool _hasContact = false;

  static const _purple = Color(0xFF8B5CF6);
  static const _pink = Color(0xFFE879F9);
  static const _text = Color(0xFFF0EAFF);

  String get _lang => s.lang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  Future<void> _greet() async {
    try {
      await _tts.init();
      await _tts.configure(
          lang: _lang, webSpeechRate: s.speechRate, volume: s.volume);
      await _tts.speak(pick(msgOnboardWelcome, _lang));
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _continue() async {
    if (s.emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pick(msgOnboardNeedContact, _lang))),
      );
      try {
        await _tts.speak(pick(msgOnboardNeedContact, _lang));
      } catch (_) {}
      return;
    }
    s.firstRunDone = true;
    await _tts.stop();
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final rtl = _lang == 'ar';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0612),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0612),
          foregroundColor: _text,
          automaticallyImplyLeading: false,
          title: Text(pick(lblOnboardTitle, _lang)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.contact_emergency, color: _pink, size: 56),
            const SizedBox(height: 16),
            const Text(
              'SINA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pick(lblOnboardIntro, _lang),
              style: const TextStyle(color: Color(0xCCF0EAFF), fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x148B5CF6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x338B5CF6)),
              ),
              child: ContactsEditor(
                onChanged: (has) => setState(() => _hasContact = has),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasContact ? _purple : const Color(0x33FFFFFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _continue,
                child: Text(
                  pick(lblContinue, _lang),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

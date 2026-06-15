import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/labels.dart';
import '../services/settings_service.dart';
import '../widgets/contacts_editor.dart';

/// Port of settings.html. All values persist to SharedPreferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService s = SettingsService.instance;
  late final TextEditingController _whatsapp =
      TextEditingController(text: s.familyWhatsapp);

  static const _purple = Color(0xFF8B5CF6);
  static const _pink = Color(0xFFE879F9);
  static const _text = Color(0xFFF0EAFF);

  @override
  void dispose() {
    _whatsapp.dispose();
    super.dispose();
  }

  String get _speedLabel {
    final r = s.speechRate;
    final lang = s.lang;
    if (r <= 0.75) return pick(lblSlow, lang);
    if (r >= 1.25) return pick(lblVeryFast, lang);
    if (r >= 1.05) return pick(lblFast, lang);
    if (r <= 0.85) return pick(lblSlow, lang);
    return pick(lblNormalSpeed, lang);
  }

  String get _sensLabel =>
      {
        1: pick(lblQuiet, s.lang),
        2: pick(lblMedium, s.lang),
        3: pick(lblNoisy, s.lang),
      }[s.sensitivity] ??
      pick(lblMedium, s.lang);

  @override
  Widget build(BuildContext context) {
    final lang = s.lang;
    final rtl = lang == 'ar';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0612),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0612),
          foregroundColor: _text,
          title: Text('⚙️ ${pick(lblSettings, lang)}'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _group('Language / Langue / اللغة', [
              Row(
                children: [
                  _langBtn('Français', 'fr'),
                  const SizedBox(width: 10),
                  _langBtn('English', 'en'),
                  const SizedBox(width: 10),
                  _langBtn('العربية', 'ar'),
                ],
              ),
            ]),
            _group('${pick(lblSpeechSpeed, lang)}  ($_speedLabel)', [
              Slider(
                min: 0.7,
                max: 1.3,
                divisions: 6,
                value: s.speechRate.clamp(0.7, 1.3),
                activeColor: _pink,
                label: _speedLabel,
                onChanged: (v) => setState(() => s.speechRate = v),
              ),
            ]),
            _group('${pick(lblVolume, lang)}  (${(s.volume * 100).round()}%)', [
              Slider(
                min: 0,
                max: 1,
                divisions: 10,
                value: s.volume,
                activeColor: _pink,
                label: '${(s.volume * 100).round()}%',
                onChanged: (v) => setState(() => s.volume = v),
              ),
            ]),
            _group(pick(lblSoundEffects, lang), [
              _toggle(pick(lblBeepsHaptics, lang), s.soundEffects,
                  (v) => setState(() => s.soundEffects = v)),
            ]),
            _group(pick(lblAccessibility, lang), [
              _toggle(pick(lblHighContrast, lang), s.highContrast,
                  (v) => setState(() => s.highContrast = v)),
              Text(
                pick(descAccessibility, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
            ]),
            _group('${pick(lblDetectionSensitivity, lang)}  ($_sensLabel)', [
              Slider(
                min: 1,
                max: 3,
                divisions: 2,
                value: s.sensitivity.toDouble(),
                activeColor: _pink,
                label: _sensLabel,
                onChanged: (v) => setState(() => s.sensitivity = v.round()),
              ),
              Text(
                pick(descSensitivity, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
              const SizedBox(height: 8),
              _toggle(pick(lblWarnUnknown, lang), s.announceUnknownObjects,
                  (v) => setState(() => s.announceUnknownObjects = v)),
              Text(
                pick(descWarnUnknown, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
              const SizedBox(height: 8),
              _toggle(pick(lblDepthDistance, lang), s.depthEnabled,
                  (v) => setState(() => s.depthEnabled = v)),
              Text(
                pick(descDepth, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
            ]),
            _group(pick(lblLocationServices, lang), [
              _toggle(pick(lblLocationSharing, lang), s.gpsEnabled,
                  (v) => setState(() => s.gpsEnabled = v)),
              Text(
                pick(descLocationSharing, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
            ]),
            _group(pick(lblCameraAutoStart, lang), [
              _toggle(pick(lblAutoActivateCamera, lang), s.autoCamera,
                  (v) => setState(() => s.autoCamera = v)),
            ]),
            _group(pick(lblEmergencyContacts, lang), [
              Text(
                pick(descEmergencyContacts, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
              const SizedBox(height: 12),
              const ContactsEditor(),
              const SizedBox(height: 6),
              _input(pick(lblWhatsappNumber, lang), _whatsapp,
                  (v) => s.familyWhatsapp = v),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0x264CAF50),
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(color: Color(0x664CAF50)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _testCall,
                  icon: const Icon(Icons.phone),
                  label: Text(pick(lblTestCall, lang)),
                ),
              ),
            ]),
            _group(pick(lblEmergencyBehaviour, lang), [
              _toggle(pick(lblConfirmSosToggle, lang), s.confirmSos,
                  (v) => setState(() => s.confirmSos = v)),
              Text(
                pick(descConfirmSos, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
              const SizedBox(height: 14),
              _toggle(pick(lblCallFirstContact, lang), s.autoCallOnSos,
                  (v) => setState(() => s.autoCallOnSos = v)),
              const SizedBox(height: 14),
              Text(
                '${pick(lblLocationCheckIn, lang)} ${s.sosCheckInMinutes} ${pick(lblMinutesUnit, lang)}',
                style: const TextStyle(color: _text, fontWeight: FontWeight.w500),
              ),
              Slider(
                min: 1,
                max: 10,
                divisions: 9,
                value: s.sosCheckInMinutes.toDouble(),
                activeColor: _pink,
                label: '${s.sosCheckInMinutes} ${pick(lblMinutesUnit, lang)}',
                onChanged: (v) =>
                    setState(() => s.sosCheckInMinutes = v.round()),
              ),
              Text(
                pick(descCheckIn, lang),
                style: const TextStyle(color: Color(0x99F0EAFF), fontSize: 12),
              ),
            ]),
            _group(pick(lblAbout, lang), [
              Text(
                pick(descAbout, lang),
                style: const TextStyle(
                    color: Color(0x99F0EAFF), fontSize: 13, height: 1.5),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _testCall() async {
    final cs = s.emergencyContacts;
    final phone = cs.isNotEmpty ? cs.first.phone.trim() : '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pick(msgAddPhoneFirst, s.lang))),
      );
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$phone'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _group(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x148B5CF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x338B5CF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: _text, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _langBtn(String label, String code) {
    final active = s.lang == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => s.lang = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0x59E879F9) : const Color(0x0DE879F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? _pink : const Color(0x4DE879F9), width: 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFF0ABFC) : _text,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: value ? const Color(0x334CAF50) : const Color(0x0DE879F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: value ? const Color(0x664CAF50) : const Color(0x4DE879F9),
              width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: value ? const Color(0xFF4CAF50) : _text,
                  fontWeight: FontWeight.w500),
            ),
            if (value)
              const Icon(Icons.check, color: Color(0xFF4CAF50), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _input(
      String label, TextEditingController ctrl, ValueChanged<String> onChanged,
      {TextInputType keyboard = TextInputType.phone,
      String hint = '+1 234 567 8900'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xBFF0EAFF), fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(color: _text),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0x66F0EAFF)),
            filled: true,
            fillColor: const Color(0x1A8B5CF6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0x4D8B5CF6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _purple),
            ),
          ),
        ),
      ],
    );
  }
}

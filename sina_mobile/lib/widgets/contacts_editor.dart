import 'package:flutter/material.dart';

import '../constants/labels.dart';
import '../models/emergency_contact.dart';
import '../services/settings_service.dart';

/// Reusable editor for the list of emergency contacts. Persists to
/// [SettingsService.emergencyContacts] on every change and reports — via
/// [onChanged] — whether at least one valid phone number is present (used by the
/// onboarding screen to enable its Continue button).
class ContactsEditor extends StatefulWidget {
  final ValueChanged<bool>? onChanged;
  const ContactsEditor({super.key, this.onChanged});

  @override
  State<ContactsEditor> createState() => _ContactsEditorState();
}

class _Ctrls {
  final TextEditingController name;
  final TextEditingController phone;
  _Ctrls(EmergencyContact c)
      : name = TextEditingController(text: c.name),
        phone = TextEditingController(text: c.phone);
  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

class _ContactsEditorState extends State<ContactsEditor> {
  final SettingsService s = SettingsService.instance;
  late List<_Ctrls> _items;

  static const _purple = Color(0xFF8B5CF6);
  static const _pink = Color(0xFFE879F9);
  static const _text = Color(0xFFF0EAFF);

  @override
  void initState() {
    super.initState();
    final saved = s.emergencyContacts;
    _items = saved.isEmpty
        ? [_Ctrls(const EmergencyContact(name: '', phone: ''))]
        : saved.map((c) => _Ctrls(c)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    for (final c in _items) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() =>
      widget.onChanged?.call(_items.any((c) => c.phone.text.trim().isNotEmpty));

  void _save() {
    s.emergencyContacts = _items
        .map((c) => EmergencyContact(
            name: c.name.text.trim(), phone: c.phone.text.trim()))
        .where((c) => c.phone.isNotEmpty)
        .toList();
    _notify();
  }

  void _add() {
    setState(() => _items.add(_Ctrls(const EmergencyContact(name: '', phone: ''))));
  }

  void _remove(int i) {
    setState(() {
      _items[i].dispose();
      _items.removeAt(i);
      if (_items.isEmpty) {
        _items.add(_Ctrls(const EmergencyContact(name: '', phone: '')));
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _items.length; i++) _row(i),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add, color: _pink),
            label: Text(pick(lblAddContact, s.lang),
                style: const TextStyle(color: _pink)),
          ),
        ),
      ],
    );
  }

  Widget _row(int i) {
    final c = _items[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0DE879F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33E879F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${pick(lblContact, s.lang)} ${i + 1}',
                  style: const TextStyle(
                      color: Color(0xBFF0EAFF), fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () => _remove(i),
                child: const Icon(Icons.delete_outline,
                    color: Color(0xFFEF4444), size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _field(pick(lblNameOptional, s.lang), c.name, TextInputType.text,
              pick(lblNameHint, s.lang)),
          const SizedBox(height: 10),
          _field(pick(lblPhoneNumber, s.lang), c.phone, TextInputType.phone,
              '+1 234 567 8900'),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType kb,
      String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xBFF0EAFF), fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: kb,
          style: const TextStyle(color: _text),
          onChanged: (_) => _save(),
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

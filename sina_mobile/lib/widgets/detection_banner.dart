import 'package:flutter/material.dart';

/// Slide-in banner at the bottom announcing the current detection text.
class DetectionBanner extends StatelessWidget {
  final String? text;
  const DetectionBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final visible = text != null && text!.isNotEmpty;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: visible ? Offset.zero : const Offset(0, 1.4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1 : 0,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1030).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x66E879F9)),
            boxShadow: const [
              BoxShadow(color: Color(0x668B5CF6), blurRadius: 24),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFE879F9), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text ?? '',
                  style: const TextStyle(
                    color: Color(0xFFF0EAFF),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/labels.dart';
import '../models/detection.dart';

/// Draws YOLO bounding boxes (normalized [0,1] coords) over the camera preview.
class BBoxPainter extends CustomPainter {
  final List<RawBox> boxes;
  final String lang;

  BBoxPainter({required this.boxes, required this.lang});

  Color _colorFor(double conf) {
    if (conf >= 0.7) return const Color(0xFFE879F9); // pink (high)
    return const Color(0xFF8B5CF6); // purple
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in boxes) {
      final rect = Rect.fromLTRB(
        b.x1 * size.width,
        b.y1 * size.height,
        b.x2 * size.width,
        b.y2 * size.height,
      );
      final color = _colorFor(b.confidence);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );

      // Label chip
      final name = labels[b.label]?[lang] ?? b.label;
      final text = '$name ${(b.confidence * 100).round()}%';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final chipRect = Rect.fromLTWH(
        rect.left,
        (rect.top - tp.height - 6).clamp(0, size.height),
        tp.width + 12,
        tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, const Radius.circular(4)),
        Paint()..color = color.withOpacity(0.85),
      );
      tp.paint(canvas, Offset(chipRect.left + 6, chipRect.top + 3));
    }
  }

  @override
  bool shouldRepaint(covariant BBoxPainter old) =>
      old.boxes != boxes || old.lang != lang;
}

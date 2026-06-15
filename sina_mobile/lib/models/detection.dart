import 'dart:ui';

/// A single detected object after NMS, with distance/position and spoken text.
class Detection {
  /// Canonical English label, or '+'-joined labels for a group, or 'many'.
  final String label;
  final String distance; // very_close | close | medium | far
  final String position; // left | center | right
  final double confidence;

  /// Bounding box in normalized [0,1] coordinates of the model input frame.
  final Rect box;

  /// Spoken sentence per language (fr/en/ar).
  final Map<String, String> spoken;

  const Detection({
    required this.label,
    required this.distance,
    required this.position,
    required this.confidence,
    required this.box,
    required this.spoken,
  });

  String spokenFor(String lang) => spoken[lang] ?? spoken['fr'] ?? label;
}

/// A raw box straight out of YOLO decoding (before grouping/announcement).
class RawBox {
  final int classId;
  final String label;
  final double confidence;
  final double x1, y1, x2, y2; // normalized [0,1]

  /// Traffic-light colour state ('red' | 'green' | 'yellow') for classId 9,
  /// else null. Filled in by the detector after decoding (see classifier).
  String? lightState;

  /// Real distance in metres at the box centre (e.g. from ARCore depth), or
  /// null when no depth provider is active — then the area heuristic is used.
  double? distanceMeters;

  /// True when confidence fell in the generic band (below the naming threshold
  /// but above [kUncertainObjectFloor]): announce as an unnamed "object".
  final bool uncertain;

  RawBox(this.classId, this.label, this.confidence, this.x1, this.y1, this.x2,
      this.y2, {this.lightState, this.distanceMeters, this.uncertain = false});

  Rect get rect => Rect.fromLTRB(x1, y1, x2, y2);
}

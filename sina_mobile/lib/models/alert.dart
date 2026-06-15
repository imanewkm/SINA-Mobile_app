/// An SOS alert entry shown on the family dashboard.
class SinaAlert {
  final int id;
  final String message;
  final double? lat;
  final double? lng;
  final DateTime timestamp;

  const SinaAlert({
    required this.id,
    required this.message,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'lat': lat,
        'lng': lng,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory SinaAlert.fromJson(Map<String, dynamic> j) => SinaAlert(
        id: (j['id'] as num?)?.toInt() ?? 0,
        message: j['message'] as String? ?? 'SOS',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (j['ts'] as num?)?.toInt() ?? 0),
      );
}

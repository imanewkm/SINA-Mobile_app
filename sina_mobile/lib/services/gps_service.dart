import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// GPS wrapper around geolocator. Streams position updates and tracks staleness.
class GpsService {
  StreamSubscription<Position>? _sub;

  double? lat;
  double? lng;
  DateTime? lastUpdate;

  bool get hasFix => lat != null && lng != null;

  /// Whether the GPS fix is older than [thresholdSec] seconds.
  bool isStale({int thresholdSec = 30}) {
    if (lastUpdate == null) return false;
    return DateTime.now().difference(lastUpdate!).inSeconds > thresholdSec;
  }

  Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Start streaming positions (distanceFilter 10m, same as web app intent).
  Future<void> start() async {
    if (_sub != null) return;
    if (!await ensurePermission()) return;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      lat = pos.latitude;
      lng = pos.longitude;
      lastUpdate = DateTime.now();
    }, onError: (_) {});
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// One-shot current position (used by SOS). Returns null on failure.
  Future<Position?> currentPosition() async {
    try {
      if (!await ensurePermission()) return null;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lat = pos.latitude;
      lng = pos.longitude;
      lastUpdate = DateTime.now();
      return pos;
    } catch (_) {
      return null;
    }
  }
}

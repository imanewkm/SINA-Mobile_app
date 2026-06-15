import 'package:audioplayers/audioplayers.dart';

/// Short non-speech earcons that encode **direction** (stereo pan) and
/// **distance** (pitch/tempo via playback rate), inspired by Microsoft
/// Soundscape. A fast, low-latency cue played alongside the spoken sentence so
/// the user perceives where/how close a hazard is before the words finish.
class SpatialAudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  // left → full left, right → full right, center → middle.
  static double _balanceFor(String position) {
    switch (position) {
      case 'left':
        return -1.0;
      case 'right':
        return 1.0;
      default:
        return 0.0;
    }
  }

  // Closer hazards → higher/faster beep.
  static double _rateFor(String distance) {
    switch (distance) {
      case 'very_close':
        return 1.6;
      case 'close':
        return 1.35;
      case 'medium':
        return 1.1;
      default:
        return 0.9;
    }
  }

  static double _volumeFor(String distance) {
    switch (distance) {
      case 'very_close':
        return 1.0;
      case 'close':
        return 0.9;
      case 'medium':
        return 0.7;
      default:
        return 0.55;
    }
  }

  /// Play a directional earcon. Best-effort; never throws.
  Future<void> cue(String position, String distance) async {
    try {
      if (!_ready) await init();
      await _player.setPlaybackRate(_rateFor(distance));
      await _player.play(
        AssetSource('audio/beep.wav'),
        volume: _volumeFor(distance),
        balance: _balanceFor(position),
      );
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

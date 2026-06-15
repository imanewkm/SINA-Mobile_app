/// The 3-state model mirrored from the web app.
enum AppState {
  /// Tap to activate (overlay shown).
  idle,

  /// Mic active, STT running.
  listening,

  /// TTS playing, mic silent.
  responding,
}

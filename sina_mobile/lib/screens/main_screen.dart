import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../constants/labels.dart';
import '../controller/app_controller.dart';
import '../models/app_state.dart';
import '../widgets/camera_view.dart';
import '../widgets/detection_banner.dart';
import '../widgets/orb_widget.dart';

/// On-screen diagnostics overlay — only in debug builds, never shipped.
const bool kShowDebug = kDebugMode;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final AppController c = AppController.instance;

  /// Low-vision mode: larger targets, bold labels, white-on-black colours.
  bool get _hc => c.settings.highContrast;

  /// Screen-reader hint describing what activating the orb does right now.
  String get _orbHint {
    switch (c.state) {
      case AppState.listening:
        return pick(hintOrbListening, c.curLang);
      case AppState.responding:
        return pick(hintOrbSpeaking, c.curLang);
      case AppState.idle:
        return pick(hintOrbIdle, c.curLang);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.updateAccessibility(WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.accessibleNavigation);
    // Auto-activate on launch (no tap-to-start screen): request permissions,
    // greet, and begin listening as soon as the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.state == AppState.idle) c.activate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    c.updateAccessibility(WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.accessibleNavigation);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      c.onAppPause();
    } else if (s == AppLifecycleState.resumed) {
      c.onAppResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Directionality(
          textDirection: c.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            // Long-press anywhere → SOS, so a blind user can trigger emergency
            // without locating the on-screen button.
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: c.triggerSOS,
              child: Container(
              decoration: BoxDecoration(
                gradient: _hc
                    ? const RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.2,
                        colors: [Colors.black, Colors.black],
                      )
                    : const RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.2,
                        colors: [Color(0xFF1E0A38), Color(0xFF0A0612)],
                        stops: [0.0, 0.6],
                      ),
              ),
              child: Stack(
                children: [
                  CameraView(controller: c),
                  if (c.cameraOn)
                    Positioned.fill(
                      child: Container(color: Colors.black.withOpacity(0.25)),
                    ),
                  _buildBody(context),
                  // SINA already speaks the detection banner via TTS — exclude it
                  // so TalkBack doesn't read it a second time.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ExcludeSemantics(
                      child: DetectionBanner(text: c.bannerText),
                    ),
                  ),
                  if (c.sosConfirming)
                    Positioned.fill(child: _sosConfirmOverlay()),
                  if (kShowDebug)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: SafeArea(
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(6),
                            color: const Color(0xAA000000),
                            child: Text(
                              c.debugHud,
                              style: const TextStyle(
                                color: Color(0xFF7CFC00),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: const Text(
              'SINA',
              style: TextStyle(
                color: Color(0xFFF0EAFF),
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
          ),
          const Spacer(),
          MergeSemantics(
            child: Semantics(
              button: true,
              label: pick(lblMicrophone, c.curLang),
              hint: _orbHint,
              child: OrbWidget(state: c.state, onTap: c.toggleListening),
            ),
          ),
          const SizedBox(height: 28),
          // Status text is voiced by SINA's own TTS / announced via the orb hint;
          // exclude it so a screen reader doesn't read it redundantly.
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                c.statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hc ? Colors.white : const Color(0xFFF0EAFF),
                  fontSize: _hc ? 24 : 18,
                  fontWeight: _hc ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
          const Spacer(),
          _buildActions(context),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(
          icon: Icons.family_restroom,
          label: pick(lblFamily, c.curLang),
          onTap: c.openFamily,
        ),
        _circleButton(
          icon: c.cameraOn ? Icons.videocam_off : Icons.videocam,
          label: pick(lblCamera, c.curLang),
          active: c.cameraOn,
          onTap: () => c.cameraOn ? c.stopCamera() : c.startCamera(),
        ),
        _sosButton(),
        _circleButton(
          icon: Icons.settings,
          label: pick(lblSettings, c.curLang),
          onTap: c.openSettings,
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final size = _hc ? 72.0 : 60.0;
    final Color fill;
    final Color borderColor;
    final Color iconColor;
    if (_hc) {
      // High contrast: white-on-black, or inverted when active.
      fill = active ? Colors.white : Colors.black;
      borderColor = Colors.white;
      iconColor = active ? Colors.black : Colors.white;
    } else {
      fill = active ? const Color(0x40E879F9) : const Color(0x1A8B5CF6);
      borderColor = active ? const Color(0x99E879F9) : const Color(0x408B5CF6);
      iconColor = const Color(0xFFF0EAFF);
    }
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(color: borderColor, width: _hc ? 3 : 1),
              ),
              child: Icon(icon, color: iconColor, size: _hc ? 34 : 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: _hc ? Colors.white : const Color(0xCCF0EAFF),
                fontSize: _hc ? 14 : 12,
                fontWeight: _hc ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-screen tap target shown while an SOS awaits confirmation. Tapping
  /// anywhere sends the alert; ignoring it lets the countdown cancel it.
  Widget _sosConfirmOverlay() {
    return Semantics(
      button: true,
      label: pick(lblConfirmEmergency, c.curLang)
          .replaceAll('{s}', '${c.sosCountdown}'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: c.confirmSosNow,
        onLongPress: c.confirmSosNow,
        child: Container(
          color: const Color(0xF2B91C1C),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 76),
              const SizedBox(height: 24),
              Text(
                pick(lblTapToConfirmSos, c.curLang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.2),
              ),
              const SizedBox(height: 20),
              Text(
                '${c.sosCountdown}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                pick(lblNoTapCancels, c.curLang),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sosButton() {
    final size = _hc ? 100.0 : 84.0;
    return Semantics(
      button: true,
      label: pick(lblSosButton, c.curLang),
      child: GestureDetector(
        onTap: c.triggerSOS,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
            ),
            border: _hc ? Border.all(color: Colors.white, width: 4) : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.5),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: _hc ? 26 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

}

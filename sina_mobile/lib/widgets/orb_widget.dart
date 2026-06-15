import 'package:flutter/material.dart';

import '../models/app_state.dart';

/// Pulsing gradient orb — purple in listening, pink (faster) in responding,
/// static in idle. Mirrors the web app's central orb.
class OrbWidget extends StatefulWidget {
  final AppState state;
  final double size;
  final VoidCallback onTap;

  const OrbWidget({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 200,
  });

  @override
  State<OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<OrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _applyDuration();
  }

  @override
  void didUpdateWidget(covariant OrbWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _applyDuration();
  }

  void _applyDuration() {
    switch (widget.state) {
      case AppState.responding:
        _c.duration = const Duration(milliseconds: 800);
        _c
          ..reset()
          ..repeat(reverse: true);
        break;
      case AppState.listening:
        _c.duration = const Duration(milliseconds: 1400);
        _c
          ..reset()
          ..repeat(reverse: true);
        break;
      case AppState.idle:
        _c.stop();
        break;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<Color> get _colors {
    switch (widget.state) {
      case AppState.responding:
        return const [Color(0xFFE879F9), Color(0xFFC026D3)];
      case AppState.listening:
        return const [Color(0xFF8B5CF6), Color(0xFFE879F9)];
      case AppState.idle:
        return const [Color(0xFF5B3B9E), Color(0xFF3A2470)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final scale = widget.state == AppState.idle
              ? 1.0
              : 1.0 + _c.value * 0.12;
          final glow = widget.state == AppState.idle ? 18.0 : 28.0 + _c.value * 22;
          return Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size * 0.8,
                height: widget.size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: _colors),
                  boxShadow: [
                    BoxShadow(
                      color: _colors.first.withOpacity(0.55),
                      blurRadius: glow,
                      spreadRadius: glow / 4,
                    ),
                  ],
                ),
                child: Icon(
                  widget.state == AppState.responding
                      ? Icons.graphic_eq
                      : Icons.mic,
                  size: widget.size * 0.28,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

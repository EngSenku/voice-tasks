import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// The one big button. Hold to talk (or tap to start / tap to stop in [toggle] mode).
class MicButton extends StatefulWidget {
  final bool active;
  final bool toggle;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const MicButton({
    super.key,
    required this.active,
    required this.onStart,
    required this.onStop,
    this.toggle = false,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didUpdateWidget(covariant MicButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hold = !widget.toggle;
    return SizedBox(
      width: 290,
      height: 290,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(290, 290), painter: _RingPainter()),
        RotationTransition(
            turns: _spin,
            child: CustomPaint(size: const Size(290, 290), painter: _OrbitPainter())),
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => widget.active
              ? Opacity(
                  opacity: (1 - _pulse.value) * .5,
                  child: Container(
                    width: 156 + 90 * _pulse.value,
                    height: 156 + 90 * _pulse.value,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: C.lime),
                  ))
              : const SizedBox.shrink(),
        ),
        Semantics(
          button: true,
          label: hold ? 'Hold to talk' : 'Tap to start or stop recording',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: hold ? (_) => widget.onStart() : null,
            onTapUp: hold ? (_) => widget.onStop() : null,
            onTapCancel: hold ? widget.onStop : null,
            onTap: hold ? null : () => widget.active ? widget.onStop() : widget.onStart(),
            child: AnimatedScale(
              scale: widget.active ? 1.07 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 156,
                height: 156,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-.4, -.5),
                    radius: 1.0,
                    colors: [Color(0xFFE3F58C), Color(0xFFB9CF5A), Color(0xFF8DA13A)],
                    stops: [0, .6, 1],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x59D3E87A), blurRadius: 50, offset: Offset(0, 20), spreadRadius: -10),
                  ],
                ),
                child: Icon(widget.active ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    size: 56, color: C.ink),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawCircle(s.center(Offset.zero), 138,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x0DFFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    const r = 118.0;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x47D3E87A);
    const n = 64;
    for (var i = 0; i < n; i++) {
      c.drawArc(Rect.fromCircle(center: center, radius: r), i * 2 * math.pi / n,
          math.pi / n, false, p);
    }
    final dot = center + const Offset(0, -r);
    c.drawCircle(dot, 9, Paint()..color = const Color(0x55D3E87A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.drawCircle(dot, 4, Paint()..color = C.lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

/// Small tap-to-talk mic used on each task card. Tap to start, tap again to stop.
class HoldMic extends StatelessWidget {
  final bool active;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const HoldMic({super.key, required this.active, required this.onStart, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tap to re-say this task',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => active ? onStop() : onStart(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? C.lime : const Color(0x0DFFFFFF),
            border: Border.all(color: active ? C.lime : const Color(0x17FFFFFF)),
          ),
          child: Icon(Icons.mic_rounded, size: 22, color: active ? C.ink : C.tx),
        ),
      ),
    );
  }
}

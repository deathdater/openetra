import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../models/dial_menu_node.dart';

/// Central Openetra brand identity disc featuring the approved open-circle,
/// calm waveform, and warm-orange accent dot. Animates gently ONLY during
/// active operations and stops completely in idle/paused/reduced-motion states.
class DialCenter extends StatefulWidget {
  const DialCenter({
    super.key,
    required this.phase,
    required this.icon,
    this.reducedMotion = false,
    this.size = 136,
  });

  final DialLifecyclePhase phase;
  final IconData icon;
  final bool reducedMotion;
  final double size;

  static Color ringColorForPhase(DialLifecyclePhase phase) {
    switch (phase) {
      case DialLifecyclePhase.confirmingAction:
      case DialLifecyclePhase.exitArmed:
        return OpenetraTheme.hazardWarning;
      case DialLifecyclePhase.executing:
      case DialLifecyclePhase.listening:
      case DialLifecyclePhase.processing:
      case DialLifecyclePhase.speaking:
        return OpenetraTheme.accent;
      case DialLifecyclePhase.completed:
        return OpenetraTheme.okGreen;
      case DialLifecyclePhase.failed:
        return OpenetraTheme.hazardCritical;
      case DialLifecyclePhase.initializing:
      case DialLifecyclePhase.ready:
      case DialLifecyclePhase.rootMenu:
      case DialLifecyclePhase.submenu:
      case DialLifecyclePhase.paused:
      case DialLifecyclePhase.cancelling:
      case DialLifecyclePhase.exiting:
        return OpenetraTheme.accentLavender;
    }
  }

  static bool shouldAnimatePhase(DialLifecyclePhase phase) {
    return phase == DialLifecyclePhase.executing ||
        phase == DialLifecyclePhase.listening ||
        phase == DialLifecyclePhase.processing ||
        phase == DialLifecyclePhase.speaking ||
        phase == DialLifecyclePhase.confirmingAction;
  }

  @override
  State<DialCenter> createState() => _DialCenterState();
}

class _DialCenterState extends State<DialCenter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reconcileAnimation();
  }

  @override
  void didUpdateWidget(covariant DialCenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _reconcileAnimation();
    }
  }

  void _reconcileAnimation() {
    final disableAnim =
        widget.reducedMotion || MediaQuery.disableAnimationsOf(context);
    final shouldRun = !disableAnim && DialCenter.shouldAnimatePhase(widget.phase);
    if (shouldRun) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = DialCenter.ringColorForPhase(widget.phase);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pulse = _controller.value;
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _OpenetraBrandDialPainter(
                ringColor: ringColor,
                pulse: pulse,
                isActiveWave: widget.phase == DialLifecyclePhase.listening ||
                    widget.phase == DialLifecyclePhase.speaking ||
                    widget.phase == DialLifecyclePhase.processing,
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.size * 0.28,
                  color: OpenetraTheme.primaryText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OpenetraBrandDialPainter extends CustomPainter {
  const _OpenetraBrandDialPainter({
    required this.ringColor,
    required this.pulse,
    required this.isActiveWave,
  });

  final Color ringColor;
  final double pulse;
  final bool isActiveWave;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Soft layered ambient halo
    final haloPaint = Paint()
      ..color = ringColor.withOpacity(0.14 + pulse * 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * (0.94 + pulse * 0.05), haloPaint);

    // Dark Plum layered core disc
    final corePaint = Paint()
      ..color = OpenetraTheme.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.78, corePaint);

    // Openetra open-circle arc (breaks cleanly near 2 o'clock for orange dot)
    final arcPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.78);
    canvas.drawArc(arcRect, -math.pi * 0.18, math.pi * 1.72, false, arcPaint);

    // Signature Warm Orange brand accent dot at the open-circle gap
    const dotAngle = -math.pi * 0.30;
    final dotPos = Offset(
      center.dx + math.cos(dotAngle) * radius * 0.78,
      center.dy + math.sin(dotAngle) * radius * 0.78,
    );
    final dotPaint = Paint()
      ..color = OpenetraTheme.accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotPos, 5.0 + pulse * 1.5, dotPaint);

    // Subtle waveform bar arcs inside lower disc when speaking/listening/processing
    if (isActiveWave) {
      final wavePaint = Paint()
        ..color = OpenetraTheme.accentLavender.withOpacity(0.75)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (var i = -2; i <= 2; i++) {
        final x = center.dx + i * 9.0;
        final amp = (4.0 + (2 - i.abs()) * 3.5) * (0.6 + 0.4 * pulse);
        final yBase = center.dy + radius * 0.38;
        canvas.drawLine(
          Offset(x, yBase - amp / 2),
          Offset(x, yBase + amp / 2),
          wavePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OpenetraBrandDialPainter oldDelegate) {
    return oldDelegate.ringColor != ringColor ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isActiveWave != isActiveWave;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../models/dial_menu_node.dart';
import 'dial_focus_glyph.dart';

/// Central Openetra sculpted focus disc featuring a unique custom-painted
/// vector emblem for the focused option, Openetra's open-circle arc, and
/// warm-orange focal accent. Animates gently ONLY during active operations.
class DialCenter extends StatefulWidget {
  const DialCenter({
    super.key,
    required this.phase,
    required this.glyph,
    this.reducedMotion = false,
    this.size = 148,
  });

  final DialLifecyclePhase phase;
  final DialGlyphKind glyph;
  final bool reducedMotion;
  final double size;

  static Color ringColorForPhase(
    DialLifecyclePhase phase, [
    OpenetraPalette palette = OpenetraPalette.dark,
  ]) {
    switch (phase) {
      case DialLifecyclePhase.confirmingAction:
      case DialLifecyclePhase.exitArmed:
        return palette.warning;
      case DialLifecyclePhase.executing:
      case DialLifecyclePhase.listening:
      case DialLifecyclePhase.processing:
      case DialLifecyclePhase.speaking:
        return palette.secondary;
      case DialLifecyclePhase.completed:
        return palette.success;
      case DialLifecyclePhase.failed:
        return palette.error;
      case DialLifecyclePhase.initializing:
      case DialLifecyclePhase.ready:
      case DialLifecyclePhase.rootMenu:
      case DialLifecyclePhase.submenu:
      case DialLifecyclePhase.paused:
      case DialLifecyclePhase.cancelling:
      case DialLifecyclePhase.exiting:
        return palette.primary;
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
    final palette = OpenetraTheme.paletteOf(context);
    final ringColor = DialCenter.ringColorForPhase(widget.phase, palette);
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
                palette: palette,
                ringColor: ringColor,
                pulse: pulse,
                isActiveWave: widget.phase == DialLifecyclePhase.listening ||
                    widget.phase == DialLifecyclePhase.speaking ||
                    widget.phase == DialLifecyclePhase.processing,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: OpenetraMotion.resolve(
                    context,
                    OpenetraMotion.normal,
                    reducedMotion: widget.reducedMotion,
                  ),
                  switchInCurve: OpenetraMotion.standardCurve,
                  child: DialFocusGlyph(
                    key: ValueKey(widget.glyph),
                    glyph: widget.glyph,
                    size: widget.size * 0.42,
                  ),
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
    required this.palette,
    required this.ringColor,
    required this.pulse,
    required this.isActiveWave,
  });

  final OpenetraPalette palette;
  final Color ringColor;
  final double pulse;
  final bool isActiveWave;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Sculpted layered ambient halo
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          ringColor.withOpacity(0.22 + pulse * 0.16),
          ringColor.withOpacity(0.03),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * (0.96 + pulse * 0.04), haloPaint);

    // Layered instrument disc adapting to Dark Aubergine & Warm White Light
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 1.0,
        colors: [
          palette.surfaceElevated,
          palette.surface,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.78));
    canvas.drawCircle(center, radius * 0.78, corePaint);

    // Inner hairline precision bevel
    final innerBevel = Paint()
      ..color = palette.border.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius * 0.67, innerBevel);

    // Openetra signature open-circle arc
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
      ..color = palette.secondary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotPos, 5.2 + pulse * 1.5, dotPaint);

    // Subtle waveform crest inside lower disc during active voice/processing
    if (isActiveWave) {
      final wavePaint = Paint()
        ..color = palette.primary.withOpacity(0.80)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (var i = -2; i <= 2; i++) {
        final x = center.dx + i * 8.5;
        final amp = (4.0 + (2 - i.abs()) * 3.2) * (0.6 + 0.4 * pulse);
        final yBase = center.dy + radius * 0.44;
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
    return oldDelegate.palette != palette ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isActiveWave != isActiveWave;
  }
}

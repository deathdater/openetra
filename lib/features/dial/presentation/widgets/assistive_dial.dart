import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../domain/dial_gesture_recognizer.dart';
import '../../models/dial_menu_node.dart';
import 'dial_center.dart';

/// Primary radial Assistive Dial interaction surface combining:
/// - Radial option markers around the central Openetra identity disc
/// - Single-pointer Slide-Up (select/enter), Slide-Down (back/cancel/exit),
///   and horizontal browse gestures via [DialGestureAnalyzer]
/// - Full TalkBack-accessible >=64dp button alternatives so non-visual users
///   never suffer gesture conflicts when TalkBack touch exploration is active.
class AssistiveDial extends StatefulWidget {
  const AssistiveDial({
    super.key,
    required this.menu,
    required this.focusedIndex,
    required this.phase,
    required this.onBrowsePrevious,
    required this.onBrowseNext,
    required this.onSlideUp,
    required this.onSlideDown,
    required this.onRepeat,
    this.activeOperationTitle,
    this.reducedMotion = false,
  });

  final DialMenuNode menu;
  final int focusedIndex;
  final DialLifecyclePhase phase;
  final VoidCallback onBrowsePrevious;
  final VoidCallback onBrowseNext;
  final VoidCallback onSlideUp;
  final VoidCallback onSlideDown;
  final VoidCallback onRepeat;
  final String? activeOperationTitle;
  final bool reducedMotion;

  @override
  State<AssistiveDial> createState() => _AssistiveDialState();
}

class _AssistiveDialState extends State<AssistiveDial> {
  final DialGestureAnalyzer _analyzer = DialGestureAnalyzer();
  int _activePointers = 0;
  Offset? _dragStart;
  DateTime? _dragStartTime;

  void _handleGestureEnd(Offset endPos, Size viewport) {
    final start = _dragStart;
    final startTime = _dragStartTime;
    _dragStart = null;
    _dragStartTime = null;
    if (start == null || startTime == null) return;

    final elapsedSec =
        math.max(DateTime.now().difference(startTime).inMilliseconds / 1000.0, 0.05);
    final distance = (endPos - start).distance;
    final velocity = distance / elapsedSec;

    final result = _analyzer.classify(
      startPosition: start,
      endPosition: endPos,
      viewportSize: viewport,
      velocityDpPerSec: velocity,
      pointerCount: _activePointers == 0 ? 1 : _activePointers,
    );

    switch (result) {
      case DialGestureType.slideUp:
        widget.onSlideUp();
      case DialGestureType.slideDown:
        widget.onSlideDown();
      case DialGestureType.browseNext:
        widget.onBrowseNext();
      case DialGestureType.browsePrevious:
        widget.onBrowsePrevious();
      case DialGestureType.none:
        break;
    }
  }

  String _upCueLabel(DialOption focused) {
    if (widget.phase == DialLifecyclePhase.confirmingAction) {
      return 'Slide up to confirm ${focused.title}';
    }
    if (focused.kind == DialOptionKind.submenu) {
      return 'Slide up to open ${focused.title}';
    }
    if (focused.kind == DialOptionKind.returnParent) {
      return 'Slide up to return';
    }
    return 'Slide up to select ${focused.title}';
  }

  String _downCueLabel() {
    if (widget.phase == DialLifecyclePhase.confirmingAction) {
      return 'Slide down to cancel confirmation';
    }
    if (widget.phase == DialLifecyclePhase.executing ||
        widget.phase == DialLifecyclePhase.listening ||
        widget.phase == DialLifecyclePhase.processing ||
        widget.phase == DialLifecyclePhase.speaking) {
      return 'Slide down to cancel operation';
    }
    if (widget.phase == DialLifecyclePhase.exitArmed) {
      return 'Slide down again to close dial';
    }
    return widget.menu.isRoot
        ? 'Slide down to exit'
        : 'Slide down for previous menu';
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.menu.options;
    final safeIdx = widget.focusedIndex.clamp(0, options.length - 1);
    final focused = options[safeIdx];
    final isBusy = widget.phase == DialLifecyclePhase.executing ||
        widget.phase == DialLifecyclePhase.listening ||
        widget.phase == DialLifecyclePhase.processing ||
        widget.phase == DialLifecyclePhase.speaking;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final dialExtent = math.min(constraints.maxWidth * 0.72, 260.0);

        return Listener(
          onPointerDown: (e) {
            _activePointers++;
            if (_activePointers == 1) {
              _dragStart = e.position;
              _dragStartTime = DateTime.now();
            } else {
              _dragStart = null;
            }
          },
          onPointerUp: (e) {
            final countBefore = _activePointers;
            _activePointers = math.max(0, _activePointers - 1);
            if (countBefore == 1) {
              _handleGestureEnd(e.position, viewport);
            }
          },
          onPointerCancel: (_) {
            _activePointers = 0;
            _dragStart = null;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Subtle upward interaction cue
                _DirectionalCue(
                  icon: Icons.keyboard_arrow_up_rounded,
                  label: _upCueLabel(focused),
                  highlight: widget.phase == DialLifecyclePhase.confirmingAction,
                ),
                const SizedBox(height: 12),

                // Radial Dial Surface
                Semantics(
                  container: true,
                  liveRegion: true,
                  label:
                      '${widget.menu.title}, option ${safeIdx + 1} of ${options.length}: ${focused.title}. ${focused.spokenDescription}',
                  child: SizedBox(
                    width: dialExtent,
                    height: dialExtent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            size: Size(dialExtent, dialExtent),
                            painter: _RadialMarkersPainter(
                              palette: OpenetraTheme.paletteOf(context),
                              optionCount: options.length,
                              activeIndex: safeIdx,
                              accentColor: DialCenter.ringColorForPhase(
                                widget.phase,
                                OpenetraTheme.paletteOf(context),
                              ),
                            ),
                          ),
                        ),
                        DialCenter(
                          phase: widget.phase,
                          glyph: focused.glyph,
                          reducedMotion: widget.reducedMotion,
                          size: dialExtent * 0.60,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Active Option Title & Purpose
                Text(
                  isBusy && widget.activeOperationTitle != null
                      ? widget.activeOperationTitle!
                      : focused.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  isBusy
                      ? 'Working offline on device...'
                      : focused.spokenDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Option ${safeIdx + 1} of ${options.length} • ${widget.menu.title}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OpenetraTheme.paletteOf(context).primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),

                const SizedBox(height: 14),

                // Subtle downward cue
                _DirectionalCue(
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: _downCueLabel(),
                  highlight: widget.phase == DialLifecyclePhase.exitArmed,
                ),

                const SizedBox(height: 18),

                // TalkBack-safe >=64dp accessible alternative controls for every gesture
                Row(
                  children: [
                    Expanded(
                      child: _DialAccessibleButton(
                        label: 'Previous',
                        semanticHint: 'Browse to previous dial option',
                        icon: Icons.chevron_left_rounded,
                        onPressed: widget.onBrowsePrevious,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _DialAccessibleButton(
                        label: widget.phase == DialLifecyclePhase.confirmingAction
                            ? 'Confirm'
                            : 'Select',
                        semanticHint: _upCueLabel(focused),
                        icon: Icons.arrow_upward_rounded,
                        filled: true,
                        onPressed: widget.onSlideUp,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DialAccessibleButton(
                        label: 'Next',
                        semanticHint: 'Browse to next dial option',
                        icon: Icons.chevron_right_rounded,
                        onPressed: widget.onBrowseNext,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DialAccessibleButton(
                        label: isBusy
                            ? 'Cancel'
                            : (widget.menu.isRoot ? 'Exit' : 'Back'),
                        semanticHint: _downCueLabel(),
                        icon: Icons.arrow_downward_rounded,
                        onPressed: widget.onSlideDown,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DialAccessibleButton(
                        label: 'Repeat',
                        semanticHint: 'Repeat current option announcement',
                        icon: Icons.volume_up_outlined,
                        onPressed: widget.onRepeat,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DirectionalCue extends StatelessWidget {
  const _DirectionalCue({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final color = highlight ? palette.secondary : palette.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: 14,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _DialAccessibleButton extends StatelessWidget {
  const _DialAccessibleButton({
    required this.label,
    required this.semanticHint,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final String semanticHint;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final bg = filled ? palette.secondary : palette.surfaceElevated;
    final fg = filled ? palette.onAccent : palette.textPrimary;

    return Semantics(
      button: true,
      label: label,
      hint: semanticHint,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
              border: Border.all(
                color: filled ? palette.secondary : palette.border,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(child: Icon(icon, size: 22, color: fg)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialMarkersPainter extends CustomPainter {
  const _RadialMarkersPainter({
    required this.palette,
    required this.optionCount,
    required this.activeIndex,
    required this.accentColor,
  });

  final OpenetraPalette palette;
  final int optionCount;
  final int activeIndex;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (optionCount <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = (math.min(size.width, size.height) / 2) - 14.0;

    // Precision watch-dial micro-ticks around outer perimeter
    final microTickPaint = Paint()
      ..color = palette.border.withOpacity(0.42)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const tickCount = 36;
    for (var t = 0; t < tickCount; t++) {
      final a = -math.pi / 2 + (2 * math.pi * t / tickCount);
      final rIn = ringRadius - 5.0;
      final rOut = ringRadius + 1.0;
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * rIn, center.dy + math.sin(a) * rIn),
        Offset(center.dx + math.cos(a) * rOut, center.dy + math.sin(a) * rOut),
        microTickPaint,
      );
    }

    // Subtle track ring
    final trackPaint = Paint()
      ..color = palette.border.withOpacity(0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, ringRadius, trackPaint);

    // Luminous sector arc highlighting the focused option
    final activeAngle = -math.pi / 2 + (2 * math.pi * activeIndex / optionCount);
    final sweep = (2 * math.pi / math.max(optionCount, 3)) * 0.55;
    final sectorPaint = Paint()
      ..color = palette.secondary.withOpacity(0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      activeAngle - sweep / 2,
      sweep,
      false,
      sectorPaint,
    );

    final inactivePaint = Paint()
      ..color = palette.textSecondary.withOpacity(0.48)
      ..style = PaintingStyle.fill;
    final activePaint = Paint()
      ..color = palette.secondary
      ..style = PaintingStyle.fill;
    final activeHalo = Paint()
      ..color = accentColor.withOpacity(0.32)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < optionCount; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / optionCount);
      final pos = Offset(
        center.dx + math.cos(angle) * ringRadius,
        center.dy + math.sin(angle) * ringRadius,
      );
      if (i == activeIndex) {
        canvas.drawCircle(pos, 13.0, activeHalo);
        canvas.drawCircle(pos, 7.0, activePaint);
      } else {
        canvas.drawCircle(pos, 4.2, inactivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadialMarkersPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.optionCount != optionCount ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.accentColor != accentColor;
  }
}

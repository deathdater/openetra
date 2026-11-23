import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../models/dial_menu_node.dart';

/// Bespoke custom-painted minimalist focal emblems in Openetra's open-arc,
/// soft-white, refined-lavender, and warm-orange design language.
class DialFocusGlyph extends StatelessWidget {
  const DialFocusGlyph({
    super.key,
    required this.glyph,
    this.size = 54,
    this.primaryColor = OpenetraTheme.primaryText,
    this.accentColor = OpenetraTheme.accent,
    this.secondaryColor = OpenetraTheme.accentLavender,
  });

  final DialGlyphKind glyph;
  final double size;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialGlyphPainter(
          glyph: glyph,
          primary: primaryColor,
          accent: accentColor,
          secondary: secondaryColor,
        ),
      ),
    );
  }
}

class _DialGlyphPainter extends CustomPainter {
  const _DialGlyphPainter({
    required this.glyph,
    required this.primary,
    required this.accent,
    required this.secondary,
  });

  final DialGlyphKind glyph;
  final Color primary;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.44;

    final strokePrimary = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokeSecondary = Paint()
      ..color = secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final fillAccent = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    final strokeAccent = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    switch (glyph) {
      case DialGlyphKind.eyeIris:
        // Sculpted open-iris almond + concentric open pupil + orange light glint
        final upper = Path()
          ..moveTo(c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy - r * 0.85, c.dx + r, c.dy);
        final lower = Path()
          ..moveTo(c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy + r * 0.85, c.dx + r, c.dy);
        canvas.drawPath(upper, strokePrimary);
        canvas.drawPath(lower, strokeSecondary);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.44),
          -math.pi * 0.25,
          math.pi * 1.65,
          false,
          strokePrimary,
        );
        canvas.drawCircle(Offset(c.dx + r * 0.16, c.dy - r * 0.14), 4.0, fillAccent);

      case DialGlyphKind.continuousScene:
        // Dual orbital perception arcs + central glowing beacon
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.92),
          -math.pi * 0.75,
          math.pi * 0.85,
          false,
          strokePrimary,
        );
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.92),
          math.pi * 0.25,
          math.pi * 0.85,
          false,
          strokeSecondary,
        );
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.50),
          0,
          math.pi * 1.4,
          false,
          strokeAccent,
        );
        canvas.drawCircle(c, 4.2, fillAccent);

      case DialGlyphKind.scriptLines:
        // Floating editorial reading frame + rhythmic text lines + warm bookmark dot
        final frame = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: r * 1.55, height: r * 1.75),
          const Radius.circular(8),
        );
        canvas.drawRRect(frame, strokeSecondary);
        for (var i = -1; i <= 1; i++) {
          final y = c.dy + i * r * 0.38;
          final w = i == 1 ? r * 0.42 : r * 0.54;
          canvas.drawLine(
            Offset(c.dx - r * 0.50, y),
            Offset(c.dx + w, y),
            strokePrimary,
          );
        }
        canvas.drawCircle(Offset(c.dx + r * 0.45, c.dy + r * 0.38), 3.6, fillAccent);

      case DialGlyphKind.objectReticle:
        // Corner viewfinder brackets + floating warm target core
        final b = r * 0.85;
        final t = r * 0.36;
        for (final sx in [-1.0, 1.0]) {
          for (final sy in [-1.0, 1.0]) {
            final corner = Offset(c.dx + sx * b, c.dy + sy * b);
            canvas.drawLine(corner, Offset(corner.dx - sx * t, corner.dy), strokePrimary);
            canvas.drawLine(corner, Offset(corner.dx, corner.dy - sy * t), strokePrimary);
          }
        }
        canvas.drawCircle(c, r * 0.34, strokeSecondary);
        canvas.drawCircle(c, 4.5, fillAccent);

      case DialGlyphKind.hazardWave:
        // Clean rounded caution chevron + acoustic radar waves
        final tri = Path()
          ..moveTo(c.dx, c.dy - r * 0.85)
          ..lineTo(c.dx + r * 0.85, c.dy + r * 0.68)
          ..lineTo(c.dx - r * 0.85, c.dy + r * 0.68)
          ..close();
        canvas.drawPath(tri, strokePrimary);
        canvas.drawLine(
          Offset(c.dx, c.dy - r * 0.32),
          Offset(c.dx, c.dy + r * 0.16),
          strokeAccent,
        );
        canvas.drawCircle(Offset(c.dx, c.dy + r * 0.40), 3.4, fillAccent);

      case DialGlyphKind.voiceHarmonic:
        // Five balanced soundwave bars with warm orange center crest
        const heights = [0.32, 0.62, 0.94, 0.62, 0.32];
        for (var i = 0; i < 5; i++) {
          final x = c.dx + (i - 2) * r * 0.38;
          final h = r * heights[i];
          final p = i == 2 ? strokeAccent : (i == 1 || i == 3 ? strokePrimary : strokeSecondary);
          canvas.drawLine(Offset(x, c.dy - h * 0.5), Offset(x, c.dy + h * 0.5), p);
        }

      case DialGlyphKind.emergencyBeacon:
        // Protective outer beacon ring + bold luminous cross
        canvas.drawCircle(c, r * 0.92, strokeAccent);
        canvas.drawLine(Offset(c.dx, c.dy - r * 0.48), Offset(c.dx, c.dy + r * 0.48), strokePrimary);
        canvas.drawLine(Offset(c.dx - r * 0.48, c.dy), Offset(c.dx + r * 0.48, c.dy), strokePrimary);
        canvas.drawCircle(c, 4.0, fillAccent);

      case DialGlyphKind.flashlightBeam:
        // Sculpted torch handle + radiating light cone
        final beam = Path()
          ..moveTo(c.dx - r * 0.55, c.dy - r * 0.78)
          ..lineTo(c.dx + r * 0.55, c.dy - r * 0.78)
          ..lineTo(c.dx + r * 0.24, c.dy - r * 0.08)
          ..lineTo(c.dx - r * 0.24, c.dy - r * 0.08)
          ..close();
        canvas.drawPath(beam, strokeAccent);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(c.dx - r * 0.24, c.dy - r * 0.08, c.dx + r * 0.24, c.dy + r * 0.82),
            const Radius.circular(6),
          ),
          strokePrimary,
        );
        canvas.drawCircle(Offset(c.dx, c.dy + r * 0.25), 3.2, fillAccent);

      case DialGlyphKind.flashlightOff:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(c.dx - r * 0.24, c.dy - r * 0.35, c.dx + r * 0.24, c.dy + r * 0.75),
            const Radius.circular(6),
          ),
          strokeSecondary,
        );
        canvas.drawLine(
          Offset(c.dx - r * 0.75, c.dy - r * 0.70),
          Offset(c.dx + r * 0.75, c.dy + r * 0.70),
          strokeAccent,
        );

      case DialGlyphKind.toolsConstellation:
        // Orbital 4-node constellation with warm orange anchor
        final offsets = [
          Offset(c.dx, c.dy - r * 0.68),
          Offset(c.dx + r * 0.68, c.dy),
          Offset(c.dx, c.dy + r * 0.68),
          Offset(c.dx - r * 0.68, c.dy),
        ];
        for (var i = 0; i < offsets.length; i++) {
          canvas.drawLine(offsets[i], offsets[(i + 1) % offsets.length], strokeSecondary);
        }
        for (var i = 0; i < offsets.length; i++) {
          canvas.drawCircle(offsets[i], i == 0 ? 5.2 : 4.0, i == 0 ? fillAccent : strokePrimary);
        }

      case DialGlyphKind.repeatArc:
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.72),
          -math.pi * 0.3,
          math.pi * 1.55,
          false,
          strokePrimary,
        );
        canvas.drawCircle(Offset(c.dx + r * 0.56, c.dy - r * 0.46), 4.0, fillAccent);

      case DialGlyphKind.stopSilence:
        canvas.drawCircle(c, r * 0.82, strokeSecondary);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 0.72, height: r * 0.72),
            const Radius.circular(6),
          ),
          strokeAccent,
        );

      case DialGlyphKind.currencyRupee:
        canvas.drawLine(Offset(c.dx - r * 0.45, c.dy - r * 0.65), Offset(c.dx + r * 0.52, c.dy - r * 0.65), strokePrimary);
        canvas.drawLine(Offset(c.dx - r * 0.45, c.dy - r * 0.25), Offset(c.dx + r * 0.52, c.dy - r * 0.25), strokeSecondary);
        canvas.drawArc(
          Rect.fromLTWH(c.dx - r * 0.45, c.dy - r * 0.65, r * 0.75, r * 0.82),
          -math.pi / 2,
          math.pi,
          false,
          strokePrimary,
        );
        canvas.drawLine(Offset(c.dx - r * 0.35, c.dy + r * 0.15), Offset(c.dx + r * 0.42, c.dy + r * 0.72), strokeAccent);

      case DialGlyphKind.barcodeScan:
        const bars = [-0.55, -0.25, 0.05, 0.32, 0.58];
        for (final bx in bars) {
          canvas.drawLine(
            Offset(c.dx + bx * r, c.dy - r * 0.55),
            Offset(c.dx + bx * r, c.dy + r * 0.55),
            strokePrimary,
          );
        }
        canvas.drawLine(Offset(c.dx - r * 0.82, c.dy), Offset(c.dx + r * 0.82, c.dy), strokeAccent);

      case DialGlyphKind.handGesture:
        // Stylized open-palm gesture fan
        for (var i = -2; i <= 2; i++) {
          final angle = -math.pi / 2 + i * 0.28;
          canvas.drawLine(
            Offset(c.dx, c.dy + r * 0.35),
            Offset(c.dx + math.cos(angle) * r * 0.85, c.dy + r * 0.2 + math.sin(angle) * r * 0.85),
            i == 0 ? strokeAccent : strokePrimary,
          );
        }
        canvas.drawCircle(Offset(c.dx, c.dy + r * 0.42), r * 0.26, strokeSecondary);

      case DialGlyphKind.floatingOrb:
        canvas.drawCircle(c, r * 0.85, strokeSecondary);
        canvas.drawCircle(c, r * 0.46, strokePrimary);
        canvas.drawCircle(c, 5.0, fillAccent);

      case DialGlyphKind.aiChip:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 1.15, height: r * 1.15),
            const Radius.circular(6),
          ),
          strokePrimary,
        );
        canvas.drawCircle(c, 4.5, fillAccent);
        for (final d in [-0.28, 0.28]) {
          canvas.drawLine(Offset(c.dx + d * r, c.dy - r * 0.9), Offset(c.dx + d * r, c.dy - r * 0.58), strokeSecondary);
          canvas.drawLine(Offset(c.dx + d * r, c.dy + r * 0.58), Offset(c.dx + d * r, c.dy + r * 0.9), strokeSecondary);
        }

      case DialGlyphKind.listView:
        for (var i = -1; i <= 1; i++) {
          final y = c.dy + i * r * 0.45;
          canvas.drawCircle(Offset(c.dx - r * 0.58, y), 3.4, i == 0 ? fillAccent : strokeSecondary);
          canvas.drawLine(Offset(c.dx - r * 0.30, y), Offset(c.dx + r * 0.62, y), strokePrimary);
        }

      case DialGlyphKind.settingsGear:
        canvas.drawCircle(c, r * 0.40, strokePrimary);
        canvas.drawCircle(c, 3.8, fillAccent);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * r * 0.56, c.dy + math.sin(a) * r * 0.56),
            Offset(c.dx + math.cos(a) * r * 0.84, c.dy + math.sin(a) * r * 0.84),
            strokeSecondary,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _DialGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary;
  }
}

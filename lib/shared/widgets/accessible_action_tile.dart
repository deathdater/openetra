import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Minimum 64dp+ touch target button with explicit TalkBack Semantics and
/// full Dark / Warm-White Light semantic theme adaptation.
class AccessibleActionTile extends StatelessWidget {
  const AccessibleActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.semanticHint,
    required this.icon,
    required this.onPressed,
    this.accentBorderColor,
    this.minHeight = 76,
    this.filledAccent = false,
  });

  final String title;
  final String subtitle;
  final String semanticHint;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? accentBorderColor;
  final double minHeight;
  final bool filledAccent;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final textTheme = Theme.of(context).textTheme;
    final enabled = onPressed != null;

    final bg = filledAccent
        ? (enabled ? palette.secondary : palette.disabled)
        : palette.surfaceElevated;
    final fg = filledAccent
        ? palette.onAccent
        : (enabled ? palette.textPrimary : palette.disabled);
    final subFg = filledAccent
        ? palette.onAccent.withOpacity(0.88)
        : (enabled ? palette.textSecondary : palette.disabled);
    final borderColor = accentBorderColor ??
        (filledAccent ? palette.secondary : palette.border);

    return Semantics(
      button: true,
      enabled: enabled,
      label: title,
      hint: semanticHint,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeight,
          minWidth: double.infinity,
        ),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
            side: BorderSide(color: borderColor, width: 2),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: 30, color: fg),
                  ),
                  const SizedBox(width: OpenetraSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: (textTheme.titleMedium ??
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ))
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: OpenetraSpacing.xs),
                        Text(
                          subtitle,
                          style: (textTheme.bodyMedium ??
                                  const TextStyle(fontSize: 14))
                              .copyWith(color: subFg),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live-region spoken status banner so TalkBack announces updates immediately
/// and low-vision users see clear, calm semantic state borders.
class SpokenStatusBanner extends StatelessWidget {
  const SpokenStatusBanner({
    super.key,
    required this.statusText,
    required this.isDegraded,
    required this.isBusy,
  });

  final String statusText;
  final bool isDegraded;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final textTheme = Theme.of(context).textTheme;
    final borderColor = isDegraded
        ? palette.warning
        : (isBusy ? palette.secondary : palette.success);

    return Semantics(
      liveRegion: true,
      label: isDegraded
          ? 'Degraded notice: $statusText'
          : 'Assistant update: $statusText',
      child: AnimatedContainer(
        duration: OpenetraMotion.resolve(context, OpenetraMotion.fast),
        curve: OpenetraMotion.standardCurve,
        width: double.infinity,
        padding: const EdgeInsets.all(OpenetraSpacing.lg),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    isDegraded
                        ? Icons.warning_amber_rounded
                        : (isBusy
                            ? Icons.hourglass_top
                            : Icons.record_voice_over),
                    color: borderColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: OpenetraSpacing.sm),
                Expanded(
                  child: Text(
                    isDegraded
                        ? 'DEGRADED CAPABILITY NOTICE'
                        : (isBusy ? 'PROCESSING LOCALLY' : 'SPOKEN OUTPUT'),
                    style: (textTheme.labelMedium ??
                            const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ))
                        .copyWith(color: borderColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: OpenetraSpacing.sm),
            Text(
              statusText,
              style: textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

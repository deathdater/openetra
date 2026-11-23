import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Minimum 64dp+ touch target button with explicit TalkBack Semantics.
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
    final bg = filledAccent
        ? OpenetraTheme.accent
        : OpenetraTheme.surfaceElevated;
    final fg = filledAccent
        ? OpenetraTheme.accentText
        : OpenetraTheme.primaryText;
    final subFg = filledAccent
        ? OpenetraTheme.accentText.withOpacity(0.85)
        : OpenetraTheme.secondaryText;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: title,
      hint: semanticHint,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight, minWidth: double.infinity),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: accentBorderColor ??
                  (filledAccent ? OpenetraTheme.accent : OpenetraTheme.border),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: 32, color: fg),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: subFg,
                          ),
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

/// Live-region spoken status banner so TalkBack announces updates immediately.
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
    final borderColor = isDegraded
        ? OpenetraTheme.hazardWarning
        : (isBusy ? OpenetraTheme.accent : OpenetraTheme.okGreen);

    return Semantics(
      liveRegion: true,
      label: isDegraded ? 'Degraded notice: $statusText' : 'Assistant update: $statusText',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OpenetraTheme.surface,
          borderRadius: BorderRadius.circular(14),
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
                        : (isBusy ? Icons.hourglass_top : Icons.record_voice_over),
                    color: borderColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isDegraded
                      ? 'DEGRADED CAPABILITY NOTICE'
                      : (isBusy ? 'PROCESSING LOCALLY' : 'SPOKEN OUTPUT'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

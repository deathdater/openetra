import 'package:flutter/material.dart';
import '../../app/theme.dart';

enum OpenetraBadgeTone { neutral, success, warning, error, info, accent }

/// Official Openetra brand logo mark rendered cleanly from local offline asset.
class OpenetraBrandLogo extends StatelessWidget {
  const OpenetraBrandLogo({
    super.key,
    this.size = 40,
    this.borderRadius = 10,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: palette.border, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/branding/openetra_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Accessible semantic section header for predictable TalkBack landmark jumps.
class OpenetraSectionHeader extends StatelessWidget {
  const OpenetraSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.only(
      top: OpenetraSpacing.sm,
      bottom: OpenetraSpacing.md,
    ),
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: OpenetraSpacing.xs),
              Text(subtitle!, style: textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Consistent bordered surface container adapting to Dark & Light themes.
class OpenetraCard extends StatelessWidget {
  const OpenetraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OpenetraSpacing.lg),
    this.margin = const EdgeInsets.only(bottom: OpenetraSpacing.md),
    this.borderColor,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: elevated ? palette.surfaceElevated : palette.surface,
        borderRadius: BorderRadius.circular(OpenetraSpacing.radiusMd),
        border: Border.all(
          color: borderColor ?? palette.border,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// Restrained, accessible status badge (Offline Ready, Active, Degraded, etc.).
class OpenetraStatusBadge extends StatelessWidget {
  const OpenetraStatusBadge({
    super.key,
    required this.label,
    required this.icon,
    this.tone = OpenetraBadgeTone.neutral,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final OpenetraBadgeTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final textTheme = Theme.of(context).textTheme;

    final toneColor = switch (tone) {
      OpenetraBadgeTone.success => palette.success,
      OpenetraBadgeTone.warning => palette.warning,
      OpenetraBadgeTone.error => palette.error,
      OpenetraBadgeTone.info => palette.info,
      OpenetraBadgeTone.accent => palette.secondary,
      OpenetraBadgeTone.neutral => palette.textSecondary,
    };

    return Semantics(
      label: semanticLabel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OpenetraSpacing.md,
          vertical: OpenetraSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(OpenetraSpacing.radiusPill),
          border: Border.all(color: toneColor, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 16, color: toneColor),
            ),
            const SizedBox(width: OpenetraSpacing.sm - 2),
            Flexible(
              child: Text(
                label,
                style: (textTheme.bodySmall ?? const TextStyle(fontSize: 13))
                    .copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calm, accessible empty state with icon, title, and clear next-step guidance.
class OpenetraEmptyState extends StatelessWidget {
  const OpenetraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: OpenetraCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 28, color: palette.primary),
            ),
            const SizedBox(width: OpenetraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: OpenetraSpacing.xs),
                  Text(message, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// High-contrast theme-aware text field inheriting Openetra's InputDecorationTheme.
class OpenetraTextField extends StatelessWidget {
  const OpenetraTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
      ),
    );
  }
}

/// Reusable accessible confirmation dialog with clear Cancel and Confirm actions.
Future<bool> showOpenetraConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final palette = OpenetraTheme.paletteOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDestructive ? palette.error : palette.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

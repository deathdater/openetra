import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../core/assistive/assistive_action.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
import '../bloc/floating_companion_bloc.dart';

class FloatingWidgetSettingsScreen extends StatelessWidget {
  const FloatingWidgetSettingsScreen({super.key});

  static const List<({AssistiveActionId id, String label})> _tapActions = [
    (id: AssistiveActionId.describeScene, label: 'Describe Scene (Opens App)'),
    (id: AssistiveActionId.readText, label: 'Read Text (Opens App)'),
    (id: AssistiveActionId.assessHazardCues, label: 'Check Hazards (Opens App)'),
    (id: AssistiveActionId.toggleFlashlight, label: 'Toggle Flashlight (Background Safe)'),
    (id: AssistiveActionId.cancelActiveTask, label: 'Stop / Cancel Speaking (Background Safe)'),
    (id: AssistiveActionId.repeatLast, label: 'Repeat Last Response (Background Safe)'),
    (id: AssistiveActionId.startEmergencyAssistance, label: 'Emergency Confirmation (Opens App)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Floating Assistive Companion')),
      body: BlocBuilder<FloatingCompanionBloc, FloatingCompanionState>(
        builder: (context, state) {
          final palette = OpenetraTheme.paletteOf(context);
          final textTheme = Theme.of(context).textTheme;
          final cfg = state.config;
          return ListView(
            padding: const EdgeInsets.all(OpenetraSpacing.lg),
            children: [
              SpokenStatusBanner(
                statusText: state.statusMessage ??
                    (state.serviceRunning
                        ? 'Floating companion active above other apps.'
                        : 'Floating companion is currently off.'),
                isDegraded: !state.overlayPermissionGranted,
                isBusy: state.serviceRunning,
              ),
              const SizedBox(height: OpenetraSpacing.lg),
              const OpenetraSectionHeader(title: 'Overlay Control'),
              if (!state.overlayPermissionGranted) ...[
                AccessibleActionTile(
                  title: 'Grant Overlay Permission (Android Settings)',
                  subtitle:
                      'Required so Openetra can show an optional floating orb above other apps',
                  semanticHint: 'Double tap to open Android Display Over Other Apps settings',
                  icon: Icons.layers_outlined,
                  accentBorderColor: palette.warning,
                  filledAccent: true,
                  onPressed: () => context
                      .read<FloatingCompanionBloc>()
                      .add(const RequestOpenOverlaySettings()),
                ),
                const SizedBox(height: OpenetraSpacing.md),
              ],
              AccessibleActionTile(
                title: cfg.enabled && state.serviceRunning
                    ? 'Floating Assistive Orb: Active (Tap to Stop)'
                    : 'Enable Floating Assistive Orb',
                subtitle:
                    'Shows persistent non-sensitive notification. Camera/mic actions always open Openetra transparently in foreground.',
                semanticHint: 'Double tap to start or stop floating assistive orb',
                icon: Icons.assistant_outlined,
                filledAccent: cfg.enabled && state.serviceRunning,
                onPressed: () => context
                    .read<FloatingCompanionBloc>()
                    .add(ToggleFloatingCompanion(!(cfg.enabled && state.serviceRunning))),
              ),
              const SizedBox(height: OpenetraSpacing.md),
              AccessibleActionTile(
                title: cfg.reducedMotionOverride
                    ? 'Reduced Motion Glow: Enabled'
                    : 'Reduced Motion Glow: Follow System Setting',
                subtitle:
                    'Disables glow pulse animation even during active tasks (idle and paused states never animate)',
                semanticHint: 'Double tap to toggle reduced motion override',
                icon: Icons.motion_photos_off_outlined,
                filledAccent: cfg.reducedMotionOverride,
                onPressed: () => context.read<FloatingCompanionBloc>().add(
                      UpdateFloatingCompanionConfig(
                        cfg.copyWith(
                          reducedMotionOverride: !cfg.reducedMotionOverride,
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: OpenetraSpacing.lg),
              const OpenetraSectionHeader(title: 'Orb Actions & Size'),
              DropdownButtonFormField<AssistiveActionId>(
                value: cfg.primaryAction,
                dropdownColor: palette.surfaceElevated,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Single Tap Action',
                ),
                items: [
                  for (final item in _tapActions)
                    DropdownMenuItem(value: item.id, child: Text(item.label)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    context.read<FloatingCompanionBloc>().add(
                          UpdateFloatingCompanionConfig(
                            cfg.copyWith(primaryAction: v),
                          ),
                        );
                  }
                },
              ),
              const SizedBox(height: OpenetraSpacing.md),
              DropdownButtonFormField<AssistiveActionId>(
                value: cfg.longPressAction,
                dropdownColor: palette.surfaceElevated,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Long Press Action',
                ),
                items: [
                  for (final item in _tapActions)
                    DropdownMenuItem(value: item.id, child: Text(item.label)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    context.read<FloatingCompanionBloc>().add(
                          UpdateFloatingCompanionConfig(
                            cfg.copyWith(longPressAction: v),
                          ),
                        );
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Orb Size (${cfg.orbSizeDp} dp)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: cfg.orbSizeDp.toDouble(),
                min: 48,
                max: 96,
                divisions: 6,
                label: '${cfg.orbSizeDp} dp',
                onChanged: (v) => context.read<FloatingCompanionBloc>().add(
                      UpdateFloatingCompanionConfig(
                        cfg.copyWith(orbSizeDp: v.round()),
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
import '../bloc/local_intelligence_bloc.dart';
import '../domain/local_intelligence_config.dart';
import '../domain/local_model_catalogue.dart';
import 'activity_history_screen.dart';

/// Independent configuration & model management screen for Openetra Local
/// Intelligence (Beta). Disabled by default; never alters core Openetra features.
class LocalIntelligenceSettingsScreen extends StatelessWidget {
  const LocalIntelligenceSettingsScreen({
    super.key,
    this.onSpeakText,
  });

  final ValueChanged<String>? onSpeakText;

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Local Intelligence (Beta)')),
      body: BlocBuilder<LocalIntelligenceBloc, LocalIntelligenceState>(
        builder: (context, state) {
          final cfg = state.config;
          final dev = state.deviceProfile;

          return ListView(
            padding: const EdgeInsets.all(OpenetraSpacing.lg),
            children: [
              SpokenStatusBanner(
                statusText: state.statusMessage ??
                    (cfg.enabled
                        ? 'Local Intelligence Beta is enabled. All processing remains strictly on-device.'
                        : 'Local Intelligence Beta is disabled. Core Openetra features operate independently.'),
                isDegraded: false,
                isBusy: state.isBusy,
              ),
              const SizedBox(height: OpenetraSpacing.lg),
              const OpenetraSectionHeader(
                title: 'Feature Controls',
                subtitle:
                    'Optional passive history & local summaries. Never replaces Mirage, OCR, speech, or emergency flows.',
              ),
              AccessibleActionTile(
                title: cfg.enabled
                    ? 'Local Intelligence Beta: Enabled'
                    : 'Local Intelligence Beta: Disabled',
                subtitle:
                    'Master switch. Turning off immediately unloads any active LLM without deleting retained history.',
                semanticHint: 'Double tap to enable or disable Local Intelligence Beta',
                icon: Icons.psychology_outlined,
                filledAccent: cfg.enabled,
                onPressed: () => context
                    .read<LocalIntelligenceBloc>()
                    .add(SetLocalIntelligenceEnabled(!cfg.enabled)),
              ),
              const SizedBox(height: OpenetraSpacing.md),
              AccessibleActionTile(
                title: cfg.historyEnabled
                    ? 'Operation History Recording: On'
                    : 'Operation History Recording: Off',
                subtitle:
                    'Stores short sanitized metadata locally (no raw images, audio, full OCR docs, or passwords)',
                semanticHint: 'Double tap to toggle local operation history recording',
                icon: Icons.history_toggle_off_outlined,
                filledAccent: cfg.enabled && cfg.historyEnabled,
                onPressed: cfg.enabled
                    ? () => context
                        .read<LocalIntelligenceBloc>()
                        .add(SetOperationHistoryEnabled(!cfg.historyEnabled))
                    : null,
              ),
              const SizedBox(height: OpenetraSpacing.md),
              AccessibleActionTile(
                title: cfg.summariesEnabled
                    ? 'On-Device AI Summaries: On'
                    : 'On-Device AI Summaries: Off',
                subtitle:
                    'Uses verified local LLM when installed; otherwise uses deterministic structured summaries',
                semanticHint: 'Double tap to toggle on-device AI summaries',
                icon: Icons.auto_awesome_outlined,
                filledAccent: cfg.enabled && cfg.summariesEnabled,
                onPressed: cfg.enabled
                    ? () => context
                        .read<LocalIntelligenceBloc>()
                        .add(SetAiSummariesEnabled(!cfg.summariesEnabled))
                    : null,
              ),
              const SizedBox(height: OpenetraSpacing.md),
              AccessibleActionTile(
                title: 'Open Local Activity History & Summaries',
                subtitle:
                    '${state.history.length} recorded entries • Works with or without a downloaded LLM',
                semanticHint: 'Double tap to view chronological local activity history',
                icon: Icons.list_alt_outlined,
                onPressed: () {
                  final bloc = context.read<LocalIntelligenceBloc>();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: bloc,
                        child: ActivityHistoryScreen(onSpeakText: onSpeakText),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: OpenetraSpacing.xl),
              const OpenetraSectionHeader(
                title: 'History Retention',
                subtitle: 'Expired records are pruned automatically on-device',
              ),
              Wrap(
                spacing: OpenetraSpacing.sm,
                runSpacing: OpenetraSpacing.sm,
                children: [
                  for (final days in HistoryRetentionOptions.all)
                    ChoiceChip(
                      label: Text(HistoryRetentionOptions.labelFor(days)),
                      selected: cfg.retentionDays == days,
                      onSelected: (_) => context
                          .read<LocalIntelligenceBloc>()
                          .add(SetHistoryRetentionDays(days)),
                    ),
                ],
              ),
              const SizedBox(height: OpenetraSpacing.xl),
              const OpenetraSectionHeader(
                title: 'Verified On-Device Model Catalogue',
                subtitle: 'Optional LiteRT-LM (.litertlm) packages — never bundled in APK',
              ),
              OpenetraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Compatibility Profile', style: textTheme.titleMedium),
                    const SizedBox(height: OpenetraSpacing.xs),
                    Text(
                      dev.totalRamMb > 0
                          ? 'Android API ${dev.androidApiLevel} · RAM ${(dev.totalRamMb / 1024).toStringAsFixed(1)} GB · Free storage ${dev.availableStorageMb} MB · ABIs: ${dev.supportedAbis.join(", ")}'
                          : 'Hardware probe active on Android devices; deterministic summaries work on all devices.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: OpenetraSpacing.xs),
                    OpenetraStatusBadge(
                      label: dev.liteRtLmRuntimeAvailable
                          ? 'LiteRT-LM Runtime Ready'
                          : 'Deterministic Fallback Active (LiteRT-LM optional)',
                      icon: Icons.memory_outlined,
                      tone: dev.liteRtLmRuntimeAvailable
                          ? OpenetraBadgeTone.success
                          : OpenetraBadgeTone.info,
                    ),
                  ],
                ),
              ),
              for (final spec in LocalModelCatalogue.verifiedModels) ...[
                Builder(
                  builder: (context) {
                    final compat = spec.evaluateDevice(dev);
                    final installed = state.installedModelIds.contains(spec.modelId);
                    final isActive = cfg.activeModelId == spec.modelId;
                    return OpenetraCard(
                      borderColor: isActive
                          ? palette.secondary
                          : (compat.isCompatible ? palette.border : palette.warning),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spec.displayName, style: textTheme.titleMedium),
                          const SizedBox(height: OpenetraSpacing.xs),
                          Text(
                            '${spec.quantization} · ~${spec.packageSizeMb} MB · Min RAM ${(spec.minRamMb / 1024).toStringAsFixed(1)} GB · ${spec.licence}',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: OpenetraSpacing.sm),
                          OpenetraStatusBadge(
                            label: isActive
                                ? 'Active & Verified'
                                : (installed
                                    ? 'Installed & Verified'
                                    : (compat.isCompatible
                                        ? 'Compatible — Not Installed'
                                        : 'Incompatible on this device')),
                            icon: isActive
                                ? Icons.check_circle_outline
                                : Icons.download_for_offline_outlined,
                            tone: isActive
                                ? OpenetraBadgeTone.success
                                : (compat.isCompatible
                                    ? OpenetraBadgeTone.neutral
                                    : OpenetraBadgeTone.warning),
                          ),
                          if (!compat.isCompatible) ...[
                            const SizedBox(height: OpenetraSpacing.xs),
                            Text(
                              compat.reasons.join(' '),
                              style: textTheme.bodySmall?.copyWith(color: palette.warning),
                            ),
                          ],
                          if (installed) ...[
                            const SizedBox(height: OpenetraSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => context
                                    .read<LocalIntelligenceBloc>()
                                    .add(DeleteDownloadedModel(spec.modelId)),
                                icon: Icon(Icons.delete_outline, color: palette.error),
                                label: Text(
                                  'Delete Model Only',
                                  style: TextStyle(color: palette.error),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: OpenetraSpacing.lg),
              const OpenetraSectionHeader(title: 'Data & Reset Controls'),
              AccessibleActionTile(
                title: 'Clear Operation History',
                subtitle: 'Deletes local activity logs only; keeps any downloaded models',
                semanticHint: 'Double tap to clear operation history',
                icon: Icons.delete_sweep_outlined,
                accentBorderColor: palette.warning,
                onPressed: () async {
                  final bloc = context.read<LocalIntelligenceBloc>();
                  final ok = await showOpenetraConfirmDialog(
                    context,
                    title: 'Clear Operation History?',
                    message:
                        'Deletes all stored operation history events. Downloaded models remain untouched.',
                    confirmLabel: 'Clear History',
                    isDestructive: true,
                  );
                  if (ok) {
                    bloc.add(const ClearOperationHistoryRequested());
                  }
                },
              ),
              const SizedBox(height: OpenetraSpacing.md),
              AccessibleActionTile(
                title: 'Reset Local Intelligence',
                subtitle: 'Disables beta, deletes downloaded models, and clears all history',
                semanticHint: 'Double tap to confirm full Local Intelligence reset',
                icon: Icons.restart_alt_outlined,
                accentBorderColor: palette.error,
                onPressed: () async {
                  final bloc = context.read<LocalIntelligenceBloc>();
                  final ok = await showOpenetraConfirmDialog(
                    context,
                    title: 'Reset Local Intelligence?',
                    message:
                        'This disables Local Intelligence Beta, removes any downloaded LLM packages, and deletes local operation history. Core Openetra features remain unaffected.',
                    confirmLabel: 'Reset All',
                    isDestructive: true,
                  );
                  if (ok) {
                    bloc.add(const ResetLocalIntelligenceRequested());
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

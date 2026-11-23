import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_action_tile.dart';
import '../../../shared/widgets/openetra_components.dart';
import '../bloc/local_intelligence_bloc.dart';
import '../domain/deterministic_summary_engine.dart';
import '../domain/operation_history_event.dart';

/// Accessible chronological Local Activity History & Scoped Summary screen.
/// Works 100% offline without any downloaded LLM.
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({
    super.key,
    this.onSpeakText,
  });

  final ValueChanged<String>? onSpeakText;

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<LocalIntelligenceBloc>().add(const RefreshOperationHistory());
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  String _dateGroupLabel(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = OpenetraTheme.paletteOf(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Local Activity History')),
      body: BlocBuilder<LocalIntelligenceBloc, LocalIntelligenceState>(
        builder: (context, state) {
          final now = DateTime.now();
          final grouped = <String, List<OperationHistoryEvent>>{};
          for (final item in state.history) {
            final key = _dateGroupLabel(item.completedAt, now);
            grouped.putIfAbsent(key, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(OpenetraSpacing.lg),
            children: [
              if (state.statusMessage != null) ...[
                SpokenStatusBanner(
                  statusText: state.statusMessage!,
                  isDegraded: false,
                  isBusy: state.isBusy,
                ),
                const SizedBox(height: OpenetraSpacing.md),
              ],
              const OpenetraSectionHeader(
                title: 'Activity Summaries',
                subtitle:
                    'Summarises earlier recorded operations locally. Never a live camera view.',
              ),
              Wrap(
                spacing: OpenetraSpacing.sm,
                runSpacing: OpenetraSpacing.sm,
                children: [
                  ActionChip(
                    label: const Text('Today (Brief)'),
                    onPressed: () => context.read<LocalIntelligenceBloc>().add(
                          const RequestActivitySummary(
                            range: HistoryTimeRange.today,
                            style: SummaryStyle.brief,
                          ),
                        ),
                  ),
                  ActionChip(
                    label: const Text('Today (Detailed)'),
                    onPressed: () => context.read<LocalIntelligenceBloc>().add(
                          const RequestActivitySummary(
                            range: HistoryTimeRange.today,
                            style: SummaryStyle.detailed,
                          ),
                        ),
                  ),
                  ActionChip(
                    label: const Text('This Week'),
                    onPressed: () => context.read<LocalIntelligenceBloc>().add(
                          const RequestActivitySummary(
                            range: HistoryTimeRange.thisWeek,
                            style: SummaryStyle.activityFocused,
                          ),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: OpenetraSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OpenetraTextField(
                      controller: _questionController,
                      labelText: 'Ask about recorded history (e.g., How many text reads?)',
                      onSubmitted: (val) {
                        if (val.trim().isEmpty) return;
                        context
                            .read<LocalIntelligenceBloc>()
                            .add(AskHistoricalQuestion(val));
                        _questionController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: OpenetraSpacing.sm),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(76, 56),
                      backgroundColor: palette.secondary,
                      foregroundColor: palette.onAccent,
                    ),
                    onPressed: () {
                      final txt = _questionController.text.trim();
                      if (txt.isEmpty) return;
                      context
                          .read<LocalIntelligenceBloc>()
                          .add(AskHistoricalQuestion(txt));
                      _questionController.clear();
                    },
                    child: const Text('Ask'),
                  ),
                ],
              ),
              if (state.latestSummary != null) ...[
                const SizedBox(height: OpenetraSpacing.md),
                OpenetraCard(
                  elevated: true,
                  borderColor: palette.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.latestSummary!.title,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: OpenetraSpacing.xs),
                      OpenetraStatusBadge(
                        label: state.latestSummary!.isDeterministicFallback
                            ? 'Structured Local Summary'
                            : 'On-Device LLM (${state.latestSummary!.generatedByModelId})',
                        icon: Icons.summarize_outlined,
                        tone: OpenetraBadgeTone.info,
                      ),
                      const SizedBox(height: OpenetraSpacing.sm),
                      Text(
                        state.latestSummary!.spokenSummary,
                        style: textTheme.bodyLarge,
                      ),
                      if (widget.onSpeakText != null) ...[
                        const SizedBox(height: OpenetraSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => widget.onSpeakText!(
                              state.latestSummary!.spokenSummary,
                            ),
                            icon: const Icon(Icons.volume_up_outlined),
                            label: const Text('Read Summary Aloud'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: OpenetraSpacing.lg),
              const OpenetraSectionHeader(title: 'Filter Recorded Activities'),
              Wrap(
                spacing: OpenetraSpacing.sm,
                runSpacing: OpenetraSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: state.activeFilterType == null &&
                        state.activeFilterStatus == null,
                    onSelected: (_) => context
                        .read<LocalIntelligenceBloc>()
                        .add(const RefreshOperationHistory(clearFilters: true)),
                  ),
                  ChoiceChip(
                    label: const Text('Scenes'),
                    selected:
                        state.activeFilterType == OperationType.sceneDescription,
                    onSelected: (_) => context.read<LocalIntelligenceBloc>().add(
                          const RefreshOperationHistory(
                            filterType: OperationType.sceneDescription,
                          ),
                        ),
                  ),
                  ChoiceChip(
                    label: const Text('Text Reading'),
                    selected:
                        state.activeFilterType == OperationType.textReading,
                    onSelected: (_) => context.read<LocalIntelligenceBloc>().add(
                          const RefreshOperationHistory(
                            filterType: OperationType.textReading,
                          ),
                        ),
                  ),
                  ChoiceChip(
                    label: const Text('Objects'),
                    selected:
                        state.activeFilterType == OperationType.objectSearch,
                    onSelected: (_) => context.read<LocalIntelligenceBloc>().add(
                          const RefreshOperationHistory(
                            filterType: OperationType.objectSearch,
                          ),
                        ),
                  ),
                  ChoiceChip(
                    label: const Text('Failed'),
                    selected: state.activeFilterStatus == OperationStatus.failed,
                    onSelected: (_) => context.read<LocalIntelligenceBloc>().add(
                          const RefreshOperationHistory(
                            filterStatus: OperationStatus.failed,
                          ),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: OpenetraSpacing.lg),
              if (state.history.isEmpty)
                const OpenetraEmptyState(
                  icon: Icons.history_outlined,
                  title: 'No recorded activities yet',
                  message:
                      'Enable Operation History in Local Intelligence settings to log completed Openetra actions locally.',
                )
              else
                for (final entry in grouped.entries) ...[
                  OpenetraSectionHeader(title: entry.key),
                  for (final ev in entry.value)
                    OpenetraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  ev.operationLabel,
                                  style: textTheme.titleMedium,
                                ),
                              ),
                              OpenetraStatusBadge(
                                label: ev.statusLabel,
                                icon: ev.status == OperationStatus.completed
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                tone: ev.status == OperationStatus.completed
                                    ? OpenetraBadgeTone.success
                                    : (ev.status == OperationStatus.failed
                                        ? OpenetraBadgeTone.error
                                        : OpenetraBadgeTone.warning),
                              ),
                            ],
                          ),
                          const SizedBox(height: OpenetraSpacing.xs),
                          Text(
                            '${ev.completedAt.hour.toString().padLeft(2, '0')}:${ev.completedAt.minute.toString().padLeft(2, '0')} · ${(ev.durationMs / 1000.0).toStringAsFixed(1)}s · Earlier record',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: OpenetraSpacing.sm),
                          Text(ev.sanitizedSummary, style: textTheme.bodyLarge),
                          if (widget.onSpeakText != null) ...[
                            const SizedBox(height: OpenetraSpacing.xs),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => widget.onSpeakText!(
                                  ev.buildHistoricalSpokenDetail(),
                                ),
                                icon: const Icon(Icons.volume_up_outlined),
                                label: const Text('Hear Historical Record'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              const SizedBox(height: OpenetraSpacing.md),
              AccessibleActionTile(
                title: 'Clear Operation History',
                subtitle: 'Deletes all local activity logs (keeps downloaded models)',
                semanticHint: 'Double tap to confirm clearing local activity history',
                icon: Icons.delete_sweep_outlined,
                accentBorderColor: palette.error,
                onPressed: () async {
                  final bloc = context.read<LocalIntelligenceBloc>();
                  final ok = await showOpenetraConfirmDialog(
                    context,
                    title: 'Clear Operation History?',
                    message:
                        'This permanently removes your recorded activity log. Downloaded Local Intelligence models will not be deleted.',
                    confirmLabel: 'Clear History',
                    isDestructive: true,
                  );
                  if (ok) {
                    bloc.add(const ClearOperationHistoryRequested());
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

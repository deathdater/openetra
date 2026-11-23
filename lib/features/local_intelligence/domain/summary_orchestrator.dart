import '../../../core/storage/openetra_database.dart';
import 'deterministic_summary_engine.dart';
import 'local_intelligence_config.dart';
import 'local_llm_engine.dart';
import 'operation_history_event.dart';

/// Orchestrates bounded, privacy-safe historical summaries and follow-up Q&A.
///
/// Guarantees:
/// - Never runs LLM inference when Local Intelligence or summaries are disabled.
/// - Never runs LLM inference during emergency or active camera operations.
/// - Never executes tool calls or arbitrary commands from model output.
/// - Always falls back cleanly to [DeterministicSummaryEngine] if no verified
///   model is loaded or if inference fails/times out/produces invalid output.
class SummaryOrchestrator {
  SummaryOrchestrator({
    required this.database,
    required this.llmEngine,
    this.deterministicEngine = const DeterministicSummaryEngine(),
    this.isPrimaryOperationBusy,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final OpenetraDatabase database;
  final LocalLlmEngine llmEngine;
  final DeterministicSummaryEngine deterministicEngine;
  final bool Function()? isPrimaryOperationBusy;
  final DateTime Function() _clock;

  final HistoryConversationContext context = HistoryConversationContext();

  static const String _strictSystemPrompt =
      'You summarize ONLY the provided past Openetra activity records. '
      'Never fabricate missing records, never claim to see the current camera view, '
      'and never output commands or tool calls. Keep your response concise and factual.';

  Future<ActivitySummaryResult> summarizeRange({
    required LocalIntelligenceConfig config,
    required HistoryTimeRange range,
    SummaryStyle style = SummaryStyle.brief,
  }) async {
    final now = _clock();
    final resolved = DeterministicSummaryEngine.resolveRange(range, now);
    final events = await database.queryOperationHistory(
      since: resolved.since,
      until: resolved.until,
      limit: 200,
    );

    final det = deterministicEngine.summarize(
      events,
      dateRangeLabel: resolved.label,
      style: style,
    );

    final enhanced = await _tryEnhanceWithLocalLlm(
      config: config,
      events: events,
      deterministic: det,
      question: 'Provide a ${style.name} summary of ${resolved.label}.',
    );

    context.recordTurn(
      HistoryConversationTurn(
        question: 'Summarize ${resolved.label} (${style.name})',
        answer: enhanced.spokenSummary,
        timeRange: range,
        timestamp: now,
      ),
    );
    return enhanced;
  }

  Future<ActivitySummaryResult> askHistoricalQuestion({
    required LocalIntelligenceConfig config,
    required String question,
  }) async {
    final now = _clock();
    final range = DeterministicSummaryEngine.inferRangeFromQuery(
      question,
      fallback: context.lastRange,
    );
    final resolved = DeterministicSummaryEngine.resolveRange(range, now);
    final events = await database.queryOperationHistory(
      since: resolved.since,
      until: resolved.until,
      limit: 200,
    );

    final det = deterministicEngine.answerScopedQuery(
      question,
      events,
      dateRangeLabel: resolved.label,
    );

    final enhanced = await _tryEnhanceWithLocalLlm(
      config: config,
      events: events,
      deterministic: det,
      question: question,
    );

    context.recordTurn(
      HistoryConversationTurn(
        question: question,
        answer: enhanced.spokenSummary,
        timeRange: range,
        timestamp: now,
      ),
    );
    return enhanced;
  }

  Future<ActivitySummaryResult> _tryEnhanceWithLocalLlm({
    required LocalIntelligenceConfig config,
    required List<OperationHistoryEvent> events,
    required ActivitySummaryResult deterministic,
    required String question,
  }) async {
    if (!config.canRunAiSummaries) return deterministic;
    if (events.isEmpty) return deterministic;
    if (isPrimaryOperationBusy?.call() == true) return deterministic;
    if (llmEngine.loadedModelId == null ||
        llmEngine.loadedModelId != config.activeModelId) {
      return deterministic;
    }

    // Strict bounded context: at most 20 sanitized recent records, no raw frames/OCR
    final boundedLines = events.take(20).map((e) {
      final hh = e.completedAt.hour.toString().padLeft(2, '0');
      final mm = e.completedAt.minute.toString().padLeft(2, '0');
      return '[$hh:$mm] ${e.operationLabel} (${e.statusLabel}): ${e.sanitizedSummary}';
    }).join('\n');

    try {
      final raw = await llmEngine
          .generateBoundedSummary(
            systemInstruction: _strictSystemPrompt,
            boundedHistoryContext: boundedLines,
            userQuestion: question,
          )
          .timeout(const Duration(seconds: 8), onTimeout: () => null);

      if (raw == null || !_isValidLlmOutput(raw)) {
        return deterministic;
      }

      final safeSpoken = raw.contains('earlier') || raw.contains('recorded')
          ? raw
          : '$raw (Based on earlier recorded history, not a current view.)';

      return ActivitySummaryResult(
        title: deterministic.title,
        dateRangeLabel: deterministic.dateRangeLabel,
        totalCount: deterministic.totalCount,
        completedCount: deterministic.completedCount,
        failedCount: deterministic.failedCount,
        categoryCounts: deterministic.categoryCounts,
        keyObservations: deterministic.keyObservations,
        spokenSummary: safeSpoken,
        limitations: deterministic.limitations,
        isDeterministicFallback: false,
        generatedByModelId: llmEngine.loadedModelId,
      );
    } catch (_) {
      return deterministic;
    }
  }

  static bool _isValidLlmOutput(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 12 || trimmed.length > 700) return false;
    final lower = trimmed.toLowerCase();
    // Reject tool-call injections or unsafe live-navigation claims
    if (lower.contains('call_tool') ||
        lower.contains('execute_action') ||
        lower.contains('safe to cross') ||
        lower.contains('dial emergency')) {
      return false;
    }
    return true;
  }

  void resetSessionContext() => context.reset();
}

import 'package:equatable/equatable.dart';
import 'operation_history_event.dart';

enum SummaryStyle {
  brief,
  detailed,
  activityFocused,
}

enum HistoryTimeRange {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  allTime,
}

/// Validated, structured historical summary output produced either by the
/// deterministic aggregator or by a verified on-device LLM.
class ActivitySummaryResult extends Equatable {
  const ActivitySummaryResult({
    required this.title,
    required this.dateRangeLabel,
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
    required this.categoryCounts,
    required this.keyObservations,
    required this.spokenSummary,
    this.limitations,
    this.isDeterministicFallback = true,
    this.generatedByModelId,
  });

  final String title;
  final String dateRangeLabel;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final Map<OperationType, int> categoryCounts;
  final List<String> keyObservations;
  final String spokenSummary;
  final String? limitations;
  final bool isDeterministicFallback;
  final String? generatedByModelId;

  @override
  List<Object?> get props => [
        title,
        dateRangeLabel,
        totalCount,
        completedCount,
        failedCount,
        categoryCounts,
        keyObservations,
        spokenSummary,
        limitations,
        isDeterministicFallback,
        generatedByModelId,
      ];
}

class HistoryConversationTurn extends Equatable {
  const HistoryConversationTurn({
    required this.question,
    required this.answer,
    required this.timeRange,
    required this.timestamp,
  });

  final String question;
  final String answer;
  final HistoryTimeRange timeRange;
  final DateTime timestamp;

  @override
  List<Object?> get props => [question, answer, timeRange, timestamp];
}

/// Session-scoped, bounded conversation memory (max 6 turns) exclusively for
/// historical activity queries — never mixes live camera views with history.
class HistoryConversationContext {
  HistoryConversationContext({this.maxTurns = 6});

  final int maxTurns;
  final List<HistoryConversationTurn> _turns = [];
  HistoryTimeRange _lastRange = HistoryTimeRange.today;

  List<HistoryConversationTurn> get turns => List.unmodifiable(_turns);
  HistoryTimeRange get lastRange => _lastRange;

  void recordTurn(HistoryConversationTurn turn) {
    _lastRange = turn.timeRange;
    _turns.add(turn);
    if (_turns.length > maxTurns) {
      _turns.removeAt(0);
    }
  }

  void reset() {
    _turns.clear();
    _lastRange = HistoryTimeRange.today;
  }
}

/// Pure, offline deterministic summary & scoped historical Q&A engine backed
/// strictly by actual stored [OperationHistoryEvent] rows. Works 100% without
/// any downloaded LLM and serves as the guaranteed fallback.
class DeterministicSummaryEngine {
  const DeterministicSummaryEngine();

  static ({DateTime? since, DateTime? until, String label}) resolveRange(
    HistoryTimeRange range,
    DateTime now,
  ) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (range) {
      case HistoryTimeRange.today:
        return (since: startOfToday, until: now, label: 'Today');
      case HistoryTimeRange.yesterday:
        final yStart = startOfToday.subtract(const Duration(days: 1));
        final yEnd = startOfToday.subtract(const Duration(milliseconds: 1));
        return (since: yStart, until: yEnd, label: 'Yesterday');
      case HistoryTimeRange.thisWeek:
        final wStart = startOfToday.subtract(const Duration(days: 6));
        return (since: wStart, until: now, label: 'Past 7 days');
      case HistoryTimeRange.thisMonth:
        final mStart = startOfToday.subtract(const Duration(days: 29));
        return (since: mStart, until: now, label: 'Past 30 days');
      case HistoryTimeRange.allTime:
        return (since: null, until: null, label: 'All recorded history');
    }
  }

  static HistoryTimeRange inferRangeFromQuery(
    String query, {
    HistoryTimeRange fallback = HistoryTimeRange.today,
  }) {
    final q = query.toLowerCase();
    if (q.contains('yesterday')) return HistoryTimeRange.yesterday;
    if (q.contains('week')) return HistoryTimeRange.thisWeek;
    if (q.contains('month')) return HistoryTimeRange.thisMonth;
    if (q.contains('today')) return HistoryTimeRange.today;
    if (q.contains('all') || q.contains('ever')) return HistoryTimeRange.allTime;
    return fallback;
  }

  ActivitySummaryResult summarize(
    List<OperationHistoryEvent> events, {
    required String dateRangeLabel,
    SummaryStyle style = SummaryStyle.brief,
  }) {
    if (events.isEmpty) {
      return ActivitySummaryResult(
        title: '$dateRangeLabel Activity Summary',
        dateRangeLabel: dateRangeLabel,
        totalCount: 0,
        completedCount: 0,
        failedCount: 0,
        categoryCounts: const {},
        keyObservations: const [],
        spokenSummary:
            '$dateRangeLabel: No Openetra operations are recorded in this period.',
        limitations: 'No recorded events exist for $dateRangeLabel.',
      );
    }

    final counts = <OperationType, int>{};
    var completed = 0;
    var failed = 0;
    var cancelled = 0;
    var notFound = 0;

    for (final e in events) {
      counts[e.operationType] = (counts[e.operationType] ?? 0) + 1;
      switch (e.status) {
        case OperationStatus.completed:
          completed++;
        case OperationStatus.failed:
          failed++;
        case OperationStatus.cancelled:
          cancelled++;
        case OperationStatus.notFound:
          notFound++;
      }
    }

    final sortedCats = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final breakdown = sortedCats
        .map((e) => '${e.value} ${_pluralLabel(e.key, e.value)}')
        .join(', ');

    final observations = events
        .take(3)
        .map((e) => '${e.operationLabel} (${e.statusLabel}): ${e.sanitizedSummary}')
        .toList();

    final String spoken;
    switch (style) {
      case SummaryStyle.brief:
        spoken =
            '$dateRangeLabel you used Openetra ${events.length} ${_times(events.length)}: $breakdown. '
            'These are recorded past activities, not a current camera view.';
      case SummaryStyle.detailed:
        final issues = <String>[];
        if (failed > 0) issues.add('$failed failed');
        if (cancelled > 0) issues.add('$cancelled cancelled');
        if (notFound > 0) issues.add('$notFound returned no match');
        final issueText = issues.isEmpty
            ? 'All recorded operations completed.'
            : '${issues.join(', ')}.';
        final recent = observations.isNotEmpty
            ? ' Most recent: ${observations.first}'
            : '';
        spoken =
            '$dateRangeLabel you recorded ${events.length} operations ($completed completed): $breakdown. '
            '$issueText$recent '
            'This is a summary of earlier recorded activities, not a current view.';
      case SummaryStyle.activityFocused:
        final top = sortedCats.first;
        final topCompleted = events
            .where((e) =>
                e.operationType == top.key &&
                e.status == OperationStatus.completed)
            .length;
        spoken =
            'Your most frequent activity for $dateRangeLabel was ${_pluralLabel(top.key, 1)} '
            '(${top.value} of ${events.length} operations, $topCompleted completed). '
            'This reflects earlier recorded history, not a live view.';
    }

    return ActivitySummaryResult(
      title: '$dateRangeLabel Activity Summary',
      dateRangeLabel: dateRangeLabel,
      totalCount: events.length,
      completedCount: completed,
      failedCount: failed,
      categoryCounts: counts,
      keyObservations: observations,
      spokenSummary: spoken,
      limitations: events.length >= 200
          ? 'Summary is bounded to the most recent 200 recorded entries.'
          : null,
    );
  }

  /// Answers narrowly scoped historical questions & follow-ups from actual rows.
  ActivitySummaryResult answerScopedQuery(
    String query,
    List<OperationHistoryEvent> events, {
    required String dateRangeLabel,
  }) {
    final q = query.toLowerCase();

    // Filter by specific operation type if asked
    OperationType? filterType;
    if (q.contains('text') || q.contains('read') || q.contains('document') || q.contains('ocr')) {
      filterType = OperationType.textReading;
    } else if (q.contains('scene') || q.contains('surround')) {
      filterType = OperationType.sceneDescription;
    } else if (q.contains('object') || q.contains('find') || q.contains('search')) {
      filterType = OperationType.objectSearch;
    } else if (q.contains('hazard')) {
      filterType = OperationType.hazardScan;
    } else if (q.contains('currency') || q.contains('note') || q.contains('rupee')) {
      filterType = OperationType.currencyCheck;
    }

    if (q.contains('fail') || q.contains('error')) {
      final failedEvents =
          events.where((e) => e.status == OperationStatus.failed).toList();
      if (failedEvents.isEmpty) {
        return ActivitySummaryResult(
          title: '$dateRangeLabel Failed Operations',
          dateRangeLabel: dateRangeLabel,
          totalCount: 0,
          completedCount: 0,
          failedCount: 0,
          categoryCounts: const {},
          keyObservations: const [],
          spokenSummary:
              'No failed operations were recorded for $dateRangeLabel.',
        );
      }
      final obs = failedEvents
          .take(3)
          .map((e) => '${e.operationLabel}: ${e.sanitizedSummary}')
          .toList();
      return ActivitySummaryResult(
        title: '$dateRangeLabel Failed Operations',
        dateRangeLabel: dateRangeLabel,
        totalCount: failedEvents.length,
        completedCount: 0,
        failedCount: failedEvents.length,
        categoryCounts: const {},
        keyObservations: obs,
        spokenSummary:
            '$dateRangeLabel had ${failedEvents.length} failed ${_plural('operation', failedEvents.length)}: ${obs.join('; ')}. '
            'This is earlier recorded history.',
      );
    }

    if (filterType != null) {
      final matched =
          events.where((e) => e.operationType == filterType).toList();
      final label = _pluralLabel(filterType, matched.length);
      if (matched.isEmpty) {
        return ActivitySummaryResult(
          title: '$dateRangeLabel ${_pluralLabel(filterType, 2)}',
          dateRangeLabel: dateRangeLabel,
          totalCount: 0,
          completedCount: 0,
          failedCount: 0,
          categoryCounts: const {},
          keyObservations: const [],
          spokenSummary:
              'No $label were recorded for $dateRangeLabel.',
        );
      }
      final obs = matched
          .take(3)
          .map((e) => '${e.statusLabel}: ${e.sanitizedSummary}')
          .toList();
      final isCountQuestion = q.contains('how many') || q.contains('count');
      final spoken = isCountQuestion
          ? '${matched.length} of ${events.length} recorded operations for $dateRangeLabel were $label.'
          : 'For $dateRangeLabel, you had ${matched.length} $label. Recent records: ${obs.join(' | ')}. '
              'These are earlier recorded observations, not a current view.';
      return ActivitySummaryResult(
        title: '$dateRangeLabel ${_pluralLabel(filterType, 2)}',
        dateRangeLabel: dateRangeLabel,
        totalCount: matched.length,
        completedCount: matched
            .where((e) => e.status == OperationStatus.completed)
            .length,
        failedCount:
            matched.where((e) => e.status == OperationStatus.failed).length,
        categoryCounts: {filterType: matched.length},
        keyObservations: obs,
        spokenSummary: spoken,
      );
    }

    final style = q.contains('detail')
        ? SummaryStyle.detailed
        : (q.contains('frequent') || q.contains('most')
            ? SummaryStyle.activityFocused
            : SummaryStyle.brief);
    return summarize(events, dateRangeLabel: dateRangeLabel, style: style);
  }

  static String _times(int n) => n == 1 ? 'time' : 'times';
  static String _plural(String word, int n) => n == 1 ? word : '${word}s';

  static String _pluralLabel(OperationType t, int count) {
    final s = count == 1 ? '' : 's';
    switch (t) {
      case OperationType.sceneDescription:
        return 'scene description$s';
      case OperationType.textReading:
        return 'text-reading operation$s';
      case OperationType.objectSearch:
        return 'object search${count == 1 ? '' : 'es'}';
      case OperationType.hazardScan:
        return 'hazard scan$s';
      case OperationType.currencyCheck:
        return 'currency check$s';
      case OperationType.sceneRecording:
        return 'recorded scene$s';
      case OperationType.historicalSummary:
        return 'activity summar${count == 1 ? 'y' : 'ies'}';
    }
  }
}

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../core/storage/openetra_database.dart';
import 'local_intelligence_config.dart';
import 'operation_history_event.dart';

/// Passive, non-blocking observer that records sanitized Openetra operation
/// events ONLY when Local Intelligence & Operation History are explicitly
/// enabled. Any database failure is caught and isolated so primary workflows
/// are never delayed or broken.
class OperationHistoryCollector {
  OperationHistoryCollector({
    required this.database,
    required this.configProvider,
    DateTime Function()? clock,
    this.dedupWindow = const Duration(milliseconds: 1500),
  }) : _clock = clock ?? DateTime.now;

  final OpenetraDatabase database;
  final LocalIntelligenceConfig Function() configProvider;
  final DateTime Function() _clock;
  final Duration dedupWindow;

  static const _uuid = Uuid();
  String? _lastSignature;
  DateTime? _lastRecordedAt;

  /// Fire-and-forget entry point for OpenetraCoordinator. Never throws.
  void recordNonBlocking({
    required OperationType type,
    required OperationStatus status,
    required String rawSummary,
    required DateTime startedAt,
    String language = 'en-IN',
    String? modelId,
    Map<String, String> metadata = const {},
    OperationInitiator initiator = OperationInitiator.user,
    String? errorCategory,
  }) {
    unawaited(
      record(
        type: type,
        status: status,
        rawSummary: rawSummary,
        startedAt: startedAt,
        language: language,
        modelId: modelId,
        metadata: metadata,
        initiator: initiator,
        errorCategory: errorCategory,
      ),
    );
  }

  /// Persists a sanitized event if enabled & not a rapid duplicate. Never throws.
  Future<bool> record({
    required OperationType type,
    required OperationStatus status,
    required String rawSummary,
    required DateTime startedAt,
    String language = 'en-IN',
    String? modelId,
    Map<String, String> metadata = const {},
    OperationInitiator initiator = OperationInitiator.user,
    String? errorCategory,
  }) async {
    try {
      final cfg = configProvider();
      if (!cfg.canCollectHistory) return false;

      final now = _clock();
      final sanitized = OperationHistorySanitizer.sanitizeSummary(rawSummary);
      final sig = '${type.name}|${status.name}|$sanitized';
      if (_lastSignature == sig &&
          _lastRecordedAt != null &&
          now.difference(_lastRecordedAt!) <= dedupWindow) {
        return false;
      }
      _lastSignature = sig;
      _lastRecordedAt = now;

      final durMs = now.difference(startedAt).inMilliseconds.clamp(0, 3600000);
      final expiresAt = cfg.retentionDays > 0
          ? now.add(Duration(days: cfg.retentionDays))
          : null;

      final event = OperationHistoryEvent(
        eventId: _uuid.v4(),
        operationType: type,
        status: status,
        startedAt: startedAt,
        completedAt: now,
        durationMs: durMs,
        sanitizedSummary: sanitized,
        metadata: OperationHistorySanitizer.sanitizeMetadata(metadata),
        modelId: modelId,
        language: language,
        initiator: initiator,
        errorCategory: errorCategory,
        expiresAt: expiresAt,
      );

      await database.insertOperationHistoryEvent(event);
      await database.pruneExpiredOperationHistory(now: now);
      return true;
    } catch (_) {
      // Strictly passive: never allow history persistence errors to surface
      // into core visual assistance workflows.
      return false;
    }
  }
}

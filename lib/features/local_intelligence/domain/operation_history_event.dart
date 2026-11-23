import 'dart:convert';
import 'package:equatable/equatable.dart';

enum OperationType {
  sceneDescription,
  textReading,
  objectSearch,
  hazardScan,
  currencyCheck,
  sceneRecording,
  historicalSummary,
}

enum OperationStatus {
  completed,
  notFound,
  cancelled,
  failed,
}

enum OperationInitiator {
  user,
  system,
}

/// Sanitizes operation summaries so sensitive personal data (phone numbers,
/// card/account digit sequences, emails, passwords, raw OCR dumps) are never
/// stored in local history.
class OperationHistorySanitizer {
  const OperationHistorySanitizer._();

  static const int maxSummaryLength = 220;

  static String sanitizeSummary(String raw) {
    var clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Operation recorded.';
    // Redact email addresses
    clean = clean.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      '[redacted email]',
    );
    // Redact long digit sequences (phone numbers, OTPs, card/account numbers >= 6 digits)
    clean = clean.replaceAll(
      RegExp(r'(\+?\d[\d\s\-]{5,}\d)'),
      '[redacted number]',
    );
    // Redact password/pin labels
    clean = clean.replaceAll(
      RegExp(r'(password|passcode|pin|otp)\s*[:=]?\s*\S+', caseSensitive: false),
      r'$1 [redacted]',
    );
    if (clean.length > maxSummaryLength) {
      clean = '${clean.substring(0, maxSummaryLength - 1).trimRight()}…';
    }
    return clean;
  }

  static Map<String, String> sanitizeMetadata(Map<String, String> raw) {
    const allowedKeys = {
      'environment',
      'itemCount',
      'script',
      'targetItem',
      'severity',
      'denomination',
      'frameCount',
      'style',
    };
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (allowedKeys.contains(k) && v.trim().isNotEmpty) {
        out[k] = sanitizeSummary(v);
      }
    });
    return out;
  }
}

/// Versioned, privacy-sanitized record of a completed/failed/cancelled Openetra
/// operation stored locally in SQLite.
class OperationHistoryEvent extends Equatable {
  const OperationHistoryEvent({
    required this.eventId,
    this.schemaVersion = 1,
    required this.operationType,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.durationMs,
    required this.sanitizedSummary,
    this.metadata = const {},
    this.modelId,
    this.language = 'en-IN',
    this.initiator = OperationInitiator.user,
    this.errorCategory,
    this.expiresAt,
  });

  final String eventId;
  final int schemaVersion;
  final OperationType operationType;
  final OperationStatus status;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationMs;
  final String sanitizedSummary;
  final Map<String, String> metadata;
  final String? modelId;
  final String language;
  final OperationInitiator initiator;
  final String? errorCategory;
  final DateTime? expiresAt;

  String get operationLabel {
    switch (operationType) {
      case OperationType.sceneDescription:
        return 'Scene description';
      case OperationType.textReading:
        return 'Text reading';
      case OperationType.objectSearch:
        return 'Object search';
      case OperationType.hazardScan:
        return 'Hazard scan';
      case OperationType.currencyCheck:
        return 'Currency check';
      case OperationType.sceneRecording:
        return 'Scene recording';
      case OperationType.historicalSummary:
        return 'Activity summary';
    }
  }

  String get statusLabel {
    switch (status) {
      case OperationStatus.completed:
        return 'Completed';
      case OperationStatus.notFound:
        return 'Not found';
      case OperationStatus.cancelled:
        return 'Cancelled';
      case OperationStatus.failed:
        return 'Failed';
    }
  }

  /// Explicitly frames the entry as a past recorded event, never a live view.
  String buildHistoricalSpokenDetail() {
    final hh = completedAt.hour.toString().padLeft(2, '0');
    final mm = completedAt.minute.toString().padLeft(2, '0');
    final dateStr =
        '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
    final durSec = (durationMs / 1000.0).toStringAsFixed(1);
    return 'Earlier record from $dateStr at $hh:$mm: '
        '$operationLabel, status $statusLabel, duration $durSec seconds. '
        '$sanitizedSummary '
        'This is an earlier recorded activity, not a current camera view.';
  }

  Map<String, Object?> toDbRow() => {
        'event_id': eventId,
        'schema_version': schemaVersion,
        'operation_type': operationType.name,
        'status': status.name,
        'started_at_ms': startedAt.millisecondsSinceEpoch,
        'completed_at_ms': completedAt.millisecondsSinceEpoch,
        'duration_ms': durationMs,
        'sanitized_summary': sanitizedSummary,
        'metadata_json': jsonEncode(metadata),
        'model_id': modelId,
        'language': language,
        'initiator': initiator.name,
        'error_category': errorCategory,
        'expires_at_ms': expiresAt?.millisecondsSinceEpoch,
      };

  static OperationHistoryEvent fromDbRow(Map<String, Object?> row) {
    final typeName = (row['operation_type'] ?? '').toString();
    final statusName = (row['status'] ?? '').toString();
    final initName = (row['initiator'] ?? 'user').toString();

    Map<String, String> meta = const {};
    try {
      final decoded = jsonDecode((row['metadata_json'] ?? '{}').toString());
      if (decoded is Map) {
        meta = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}

    final expiresMs = row['expires_at_ms'] as int?;
    return OperationHistoryEvent(
      eventId: row['event_id'] as String,
      schemaVersion: (row['schema_version'] as int?) ?? 1,
      operationType: OperationType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => OperationType.sceneDescription,
      ),
      status: OperationStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => OperationStatus.completed,
      ),
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(row['started_at_ms'] as int),
      completedAt:
          DateTime.fromMillisecondsSinceEpoch(row['completed_at_ms'] as int),
      durationMs: (row['duration_ms'] as int?) ?? 0,
      sanitizedSummary: (row['sanitized_summary'] ?? '').toString(),
      metadata: meta,
      modelId: row['model_id'] as String?,
      language: (row['language'] ?? 'en-IN').toString(),
      initiator: OperationInitiator.values.firstWhere(
        (i) => i.name == initName,
        orElse: () => OperationInitiator.user,
      ),
      errorCategory: row['error_category'] as String?,
      expiresAt: expiresMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        eventId,
        schemaVersion,
        operationType,
        status,
        startedAt,
        completedAt,
        durationMs,
        sanitizedSummary,
        metadata,
        modelId,
        language,
        initiator,
        errorCategory,
        expiresAt,
      ];
}

import 'package:equatable/equatable.dart';

enum SpeechPriority {
  low,
  normal,
  warning,
  critical,
}

enum HapticPattern {
  none,
  confirm,
  caution,
  warning,
  critical,
  degraded,
  dialFocusTick,
  dialSelect,
  dialSubmenuEnter,
  dialNavigateBack,
  dialExitWarn,
  dialOpStart,
  dialOpComplete,
  dialOpError,
}

/// Accessibility-ready response produced after OpenetraSafetyPolicy filtering.
class AssistantResponse extends Equatable {
  const AssistantResponse({
    required this.responseId,
    required this.spokenText,
    required this.displaySummary,
    required this.locale,
    required this.priority,
    required this.hapticPattern,
    required this.timestamp,
    this.wasSafetySanitized = false,
    this.isDegraded = false,
    this.sourceObservationId,
  });

  final String responseId;
  final String spokenText;
  final String displaySummary;
  final String locale;
  final SpeechPriority priority;
  final HapticPattern hapticPattern;
  final DateTime timestamp;
  final bool wasSafetySanitized;
  final bool isDegraded;
  final String? sourceObservationId;

  @override
  List<Object?> get props => [
        responseId,
        spokenText,
        displaySummary,
        locale,
        priority,
        hapticPattern,
        timestamp,
        wasSafetySanitized,
        isDegraded,
        sourceObservationId,
      ];
}

import 'package:equatable/equatable.dart';

/// Canonical actions executable across in-app UI, offline voice, custom hand
/// gestures, and the floating companion overlay via [AssistiveActionRouter].
enum AssistiveActionId {
  describeScene,
  readText,
  findRegisteredObject,
  assessHazardCues,
  identifyCurrency,
  scanProduct,
  startEmergencyAssistance,
  toggleFlashlight,
  startOrResumeSupportedTask,
  cancelActiveTask,
  repeatLast,
}

/// Android execution eligibility category per Specification Section 9.2.
enum BackgroundExecutionCategory {
  /// Safe without live camera/microphone capture (e.g. repeat TTS, cached state, toggle torch via CameraManager, ACTION_DIAL intent).
  backgroundSafe,

  /// Permitted via an explicit user-started foreground service (e.g. overlay companion service).
  foregroundServicePermitted,

  /// Requires foreground Activity / visual privacy indicator compliance on Android 14/15 (camera/mic capture).
  foregroundUiRequired,
}

/// Unified state machine driving both in-app status banners and FloatingOrbView glow.
enum AssistiveTaskPhase {
  idle,
  activated,
  listening,
  processing,
  aiInference,
  speaking,
  completed,
  failed,
  paused,
  emergencyFlow,
}

/// Metadata contract registered for each assistive action.
class AssistiveActionSpec extends Equatable {
  const AssistiveActionSpec({
    required this.id,
    required this.displayName,
    required this.accessibleDescription,
    required this.backgroundCategory,
    this.requiresCamera = false,
    this.requiresMicrophone = false,
    this.requiresTorch = false,
    this.requiresConfirmation = false,
    this.preemptsActiveTask = false,
    this.timeout = const Duration(seconds: 25),
    this.supportsParameter = false,
    this.redactAuditArguments = false,
  });

  final AssistiveActionId id;
  final String displayName;
  final String accessibleDescription;
  final BackgroundExecutionCategory backgroundCategory;
  final bool requiresCamera;
  final bool requiresMicrophone;
  final bool requiresTorch;
  final bool requiresConfirmation;
  final bool preemptsActiveTask;
  final Duration timeout;
  final bool supportsParameter;
  final bool redactAuditArguments;

  @override
  List<Object?> get props => [
        id,
        displayName,
        accessibleDescription,
        backgroundCategory,
        requiresCamera,
        requiresMicrophone,
        requiresTorch,
        requiresConfirmation,
        preemptsActiveTask,
        timeout,
        supportsParameter,
        redactAuditArguments,
      ];
}

/// Non-sensitive live execution snapshot published by [TaskOrchestrator].
class AssistiveTaskSnapshot extends Equatable {
  const AssistiveTaskSnapshot({
    required this.taskId,
    required this.actionId,
    required this.phase,
    required this.statusLabel,
    required this.sourceTrigger,
    required this.updatedAt,
    this.isEmergency = false,
    this.errorMessage,
  });

  factory AssistiveTaskSnapshot.idle() => AssistiveTaskSnapshot(
        taskId: 'idle',
        actionId: null,
        phase: AssistiveTaskPhase.idle,
        statusLabel: 'Openetra ready',
        sourceTrigger: 'system',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String taskId;
  final AssistiveActionId? actionId;
  final AssistiveTaskPhase phase;
  /// Short non-sensitive status label safe for TalkBack and persistent notifications.
  final String statusLabel;
  final String sourceTrigger;
  final DateTime updatedAt;
  final bool isEmergency;
  final String? errorMessage;

  bool get isBusy =>
      phase == AssistiveTaskPhase.activated ||
      phase == AssistiveTaskPhase.listening ||
      phase == AssistiveTaskPhase.processing ||
      phase == AssistiveTaskPhase.aiInference ||
      phase == AssistiveTaskPhase.speaking ||
      phase == AssistiveTaskPhase.emergencyFlow;

  AssistiveTaskSnapshot copyWith({
    AssistiveTaskPhase? phase,
    String? statusLabel,
    DateTime? updatedAt,
    bool? isEmergency,
    String? errorMessage,
  }) {
    return AssistiveTaskSnapshot(
      taskId: taskId,
      actionId: actionId,
      phase: phase ?? this.phase,
      statusLabel: statusLabel ?? this.statusLabel,
      sourceTrigger: sourceTrigger,
      updatedAt: updatedAt ?? this.updatedAt,
      isEmergency: isEmergency ?? this.isEmergency,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        taskId,
        actionId,
        phase,
        statusLabel,
        sourceTrigger,
        updatedAt,
        isEmergency,
        errorMessage,
      ];
}

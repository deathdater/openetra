import 'package:equatable/equatable.dart';
import 'assistive_action.dart';
import 'permission_coordinator.dart';

enum AvailabilityState {
  available,
  requiresForegroundUi,
  missingPermission,
  unavailable,
}

class ActionAvailability extends Equatable {
  const ActionAvailability({
    required this.actionId,
    required this.state,
    required this.reason,
    this.missingPermission,
  });

  final AssistiveActionId actionId;
  final AvailabilityState state;
  final String reason;
  final OpenetraPermission? missingPermission;

  bool get canExecuteNow => state == AvailabilityState.available;

  @override
  List<Object?> get props => [actionId, state, reason, missingPermission];
}

typedef AssistiveActionHandler = Future<void> Function(
  AssistiveActionContext context,
);

class AssistiveActionContext {
  AssistiveActionContext({
    required this.taskId,
    required this.sourceTrigger,
    required this.isCancelled,
    this.argument,
    this.fromBackground = false,
  });

  final String taskId;
  final String sourceTrigger;
  final bool Function() isCancelled;
  final String? argument;
  final bool fromBackground;
}

/// Evaluates whether a registered action can execute in the current foreground/
/// background/permission context without violating Android restrictions.
class CapabilityAvailabilityService {
  CapabilityAvailabilityService({
    required this.permissions,
    bool Function()? isAppInForeground,
    bool Function()? isCameraHardwareAvailable,
  })  : _isAppInForeground = isAppInForeground ?? (() => true),
        _isCameraHardwareAvailable = isCameraHardwareAvailable ?? (() => true);

  final PermissionCoordinator permissions;
  bool Function() _isAppInForeground;
  bool Function() _isCameraHardwareAvailable;

  void updateEnvironmentProbes({
    bool Function()? isAppInForeground,
    bool Function()? isCameraHardwareAvailable,
  }) {
    if (isAppInForeground != null) _isAppInForeground = isAppInForeground;
    if (isCameraHardwareAvailable != null) {
      _isCameraHardwareAvailable = isCameraHardwareAvailable;
    }
  }

  Future<ActionAvailability> evaluate(
    AssistiveActionSpec spec, {
    bool fromBackground = false,
  }) async {
    final inFg = _isAppInForeground() && !fromBackground;

    if (!inFg &&
        spec.backgroundCategory ==
            BackgroundExecutionCategory.foregroundUiRequired) {
      return ActionAvailability(
        actionId: spec.id,
        state: AvailabilityState.requiresForegroundUi,
        reason:
            '${spec.displayName} uses camera or microphone access, so Openetra must open in the foreground first.',
      );
    }

    if (spec.requiresCamera) {
      if (!_isCameraHardwareAvailable()) {
        return ActionAvailability(
          actionId: spec.id,
          state: AvailabilityState.unavailable,
          reason: '${spec.displayName} is unavailable because no camera is accessible.',
        );
      }
      final camStatus = await permissions.refresh(OpenetraPermission.camera);
      if (camStatus.state == PermissionGrantState.denied ||
          camStatus.state == PermissionGrantState.permanentlyDenied ||
          camStatus.state == PermissionGrantState.revoked) {
        return ActionAvailability(
          actionId: spec.id,
          state: AvailabilityState.missingPermission,
          missingPermission: OpenetraPermission.camera,
          reason: PermissionCoordinator.explanationFor(OpenetraPermission.camera),
        );
      }
    }

    if (spec.requiresMicrophone) {
      final micStatus = await permissions.refresh(OpenetraPermission.microphone);
      if (micStatus.state == PermissionGrantState.denied ||
          micStatus.state == PermissionGrantState.permanentlyDenied ||
          micStatus.state == PermissionGrantState.revoked) {
        return ActionAvailability(
          actionId: spec.id,
          state: AvailabilityState.missingPermission,
          missingPermission: OpenetraPermission.microphone,
          reason: PermissionCoordinator.explanationFor(OpenetraPermission.microphone),
        );
      }
    }

    return ActionAvailability(
      actionId: spec.id,
      state: AvailabilityState.available,
      reason: 'Ready',
    );
  }
}

/// Central registry mapping [AssistiveActionId] across UI, voice, gestures,
/// and the floating companion overlay to a single domain implementation.
class AssistiveActionRouter {
  AssistiveActionRouter();

  final Map<AssistiveActionId, AssistiveActionSpec> _specs = {};
  final Map<AssistiveActionId, AssistiveActionHandler> _handlers = {};

  void register({
    required AssistiveActionSpec spec,
    required AssistiveActionHandler handler,
  }) {
    _specs[spec.id] = spec;
    _handlers[spec.id] = handler;
  }

  AssistiveActionSpec? specFor(AssistiveActionId id) => _specs[id];

  AssistiveActionHandler? handlerFor(AssistiveActionId id) => _handlers[id];

  List<AssistiveActionSpec> get registeredSpecs =>
      _specs.values.toList(growable: false);

  static AssistiveActionId? parseId(String raw) {
    final norm = raw.trim().toLowerCase();
    return switch (norm) {
      'describe_scene' || 'describescene' => AssistiveActionId.describeScene,
      'read_text' || 'readtext' => AssistiveActionId.readText,
      'find_registered_object' || 'findregisteredobject' =>
        AssistiveActionId.findRegisteredObject,
      'assess_hazard_cues' || 'assesshazardcues' =>
        AssistiveActionId.assessHazardCues,
      'identify_currency' || 'identifycurrency' =>
        AssistiveActionId.identifyCurrency,
      'scan_product' || 'scanproduct' => AssistiveActionId.scanProduct,
      'start_emergency_assistance' || 'startemergencyassistance' =>
        AssistiveActionId.startEmergencyAssistance,
      'toggle_flashlight' || 'toggleflashlight' =>
        AssistiveActionId.toggleFlashlight,
      'start_or_resume_supported_task' || 'startorresumesupportedtask' =>
        AssistiveActionId.startOrResumeSupportedTask,
      'cancel_active_task' || 'cancelactivetask' =>
        AssistiveActionId.cancelActiveTask,
      'repeat_last' || 'repeatlast' => AssistiveActionId.repeatLast,
      _ => null,
    };
  }
}

import 'dart:async';
import 'package:uuid/uuid.dart';
import 'assistive_action.dart';
import 'assistive_action_router.dart';

class TaskDispatchResult {
  const TaskDispatchResult({
    required this.accepted,
    required this.taskId,
    required this.finalSnapshot,
    this.availability,
  });

  final bool accepted;
  final String taskId;
  final AssistiveTaskSnapshot finalSnapshot;
  final ActionAvailability? availability;
}

/// Centralized assistive task lifecycle manager handling unique task IDs,
/// duplicate-tap debouncing, timeouts, explicit cancellation, priority emergency
/// preemption, and live [AssistiveTaskSnapshot] state publishing.
class TaskOrchestrator {
  TaskOrchestrator({
    required this.router,
    required this.availabilityService,
    Duration duplicateTapWindow = const Duration(milliseconds: 450),
    DateTime Function()? clock,
  })  : _duplicateTapWindow = duplicateTapWindow,
        _clock = clock ?? DateTime.now;

  final AssistiveActionRouter router;
  final CapabilityAvailabilityService availabilityService;
  final Duration _duplicateTapWindow;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  final StreamController<AssistiveTaskSnapshot> _snapshotController =
      StreamController<AssistiveTaskSnapshot>.broadcast();

  AssistiveTaskSnapshot _current = AssistiveTaskSnapshot.idle();
  final Set<String> _cancelledTaskIds = {};
  DateTime? _lastTriggerTime;
  AssistiveActionId? _lastTriggerAction;
  AssistiveActionId? _lastResumableAction;

  AssistiveTaskSnapshot get currentSnapshot => _current;
  Stream<AssistiveTaskSnapshot> get snapshots => _snapshotController.stream;
  AssistiveActionId? get lastResumableAction => _lastResumableAction;

  void _publish(AssistiveTaskSnapshot next) {
    _current = next;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(next);
    }
  }

  /// Updates an in-flight task's honest processing phase (e.g. listening ->
  /// processing -> aiInference -> speaking). Ignored if [taskId] is stale or cancelled.
  void updatePhase(
    String taskId,
    AssistiveTaskPhase phase, {
    String? statusLabel,
  }) {
    if (_cancelledTaskIds.contains(taskId) || _current.taskId != taskId) return;
    _publish(
      _current.copyWith(
        phase: phase,
        statusLabel: statusLabel,
        updatedAt: _clock(),
      ),
    );
  }

  bool isTaskCancelled(String taskId) => _cancelledTaskIds.contains(taskId);

  Future<void> cancelCurrentTask({String reason = 'Cancelled'}) async {
    if (_current.taskId == 'idle' || !_current.isBusy) return;
    final cancelledId = _current.taskId;
    _cancelledTaskIds.add(cancelledId);
    _publish(
      _current.copyWith(
        phase: AssistiveTaskPhase.paused,
        statusLabel: reason,
        updatedAt: _clock(),
      ),
    );
  }

  Future<TaskDispatchResult> dispatch(
    AssistiveActionId actionId, {
    String sourceTrigger = 'ui',
    String? argument,
    bool fromBackground = false,
  }) async {
    final resolvedAction = actionId == AssistiveActionId.startOrResumeSupportedTask
        ? (_lastResumableAction ?? AssistiveActionId.describeScene)
        : actionId;

    final spec = router.specFor(resolvedAction);
    final handler = router.handlerFor(resolvedAction);
    if (spec == null || handler == null) {
      final failSnap = AssistiveTaskSnapshot(
        taskId: _uuid.v4(),
        actionId: resolvedAction,
        phase: AssistiveTaskPhase.failed,
        statusLabel: 'Action unavailable',
        sourceTrigger: sourceTrigger,
        updatedAt: _clock(),
        errorMessage: 'Action $resolvedAction is not registered.',
      );
      _publish(failSnap);
      return TaskDispatchResult(
        accepted: false,
        taskId: failSnap.taskId,
        finalSnapshot: failSnap,
      );
    }

    final now = _clock();
    if (_lastTriggerAction == resolvedAction &&
        _lastTriggerTime != null &&
        now.difference(_lastTriggerTime!) < _duplicateTapWindow) {
      return TaskDispatchResult(
        accepted: false,
        taskId: _current.taskId,
        finalSnapshot: _current,
      );
    }
    _lastTriggerAction = resolvedAction;
    _lastTriggerTime = now;

    if (_current.isBusy) {
      if (spec.preemptsActiveTask ||
          resolvedAction == AssistiveActionId.cancelActiveTask ||
          resolvedAction == AssistiveActionId.startEmergencyAssistance) {
        await cancelCurrentTask(reason: 'Preempted by ${spec.displayName}');
      } else {
        // Reject duplicate overlapping busy execution cleanly.
        return TaskDispatchResult(
          accepted: false,
          taskId: _current.taskId,
          finalSnapshot: _current,
        );
      }
    }

    final availability = await availabilityService.evaluate(
      spec,
      fromBackground: fromBackground,
    );
    if (!availability.canExecuteNow) {
      final unavailableSnap = AssistiveTaskSnapshot(
        taskId: _uuid.v4(),
        actionId: resolvedAction,
        phase: availability.state == AvailabilityState.requiresForegroundUi
            ? AssistiveTaskPhase.paused
            : AssistiveTaskPhase.failed,
        statusLabel: availability.reason,
        sourceTrigger: sourceTrigger,
        updatedAt: _clock(),
        isEmergency: resolvedAction == AssistiveActionId.startEmergencyAssistance,
        errorMessage: availability.reason,
      );
      _publish(unavailableSnap);
      return TaskDispatchResult(
        accepted: false,
        taskId: unavailableSnap.taskId,
        finalSnapshot: unavailableSnap,
        availability: availability,
      );
    }

    if (resolvedAction != AssistiveActionId.cancelActiveTask &&
        resolvedAction != AssistiveActionId.startEmergencyAssistance &&
        resolvedAction != AssistiveActionId.toggleFlashlight) {
      _lastResumableAction = resolvedAction;
    }

    final taskId = _uuid.v4();
    final isEmergency =
        resolvedAction == AssistiveActionId.startEmergencyAssistance;
    _publish(
      AssistiveTaskSnapshot(
        taskId: taskId,
        actionId: resolvedAction,
        phase: isEmergency
            ? AssistiveTaskPhase.emergencyFlow
            : AssistiveTaskPhase.activated,
        statusLabel: spec.displayName,
        sourceTrigger: sourceTrigger,
        updatedAt: _clock(),
        isEmergency: isEmergency,
      ),
    );

    final ctx = AssistiveActionContext(
      taskId: taskId,
      sourceTrigger: sourceTrigger,
      isCancelled: () => _cancelledTaskIds.contains(taskId),
      argument: argument,
      fromBackground: fromBackground,
    );

    try {
      await handler(ctx).timeout(spec.timeout);
      if (!_cancelledTaskIds.contains(taskId) && _current.taskId == taskId) {
        _publish(
          _current.copyWith(
            phase: AssistiveTaskPhase.completed,
            statusLabel: '${spec.displayName} complete',
            updatedAt: _clock(),
          ),
        );
      }
      return TaskDispatchResult(
        accepted: true,
        taskId: taskId,
        finalSnapshot: _current,
        availability: availability,
      );
    } on TimeoutException {
      _cancelledTaskIds.add(taskId);
      _publish(
        _current.copyWith(
          phase: AssistiveTaskPhase.failed,
          statusLabel: '${spec.displayName} timed out',
          updatedAt: _clock(),
          errorMessage: 'Operation timed out.',
        ),
      );
      return TaskDispatchResult(
        accepted: false,
        taskId: taskId,
        finalSnapshot: _current,
        availability: availability,
      );
    } catch (e) {
      if (_current.taskId == taskId) {
        _publish(
          _current.copyWith(
            phase: AssistiveTaskPhase.failed,
            statusLabel: '${spec.displayName} failed',
            updatedAt: _clock(),
            errorMessage: e.toString(),
          ),
        );
      }
      return TaskDispatchResult(
        accepted: false,
        taskId: taskId,
        finalSnapshot: _current,
        availability: availability,
      );
    }
  }

  Future<void> dispose() => _snapshotController.close();
}

import 'dart:async';
import '../audio/bloc/audio_bloc.dart';
import 'assistive_action.dart';
import 'task_orchestrator.dart';

/// Non-sensitive state sink implemented by the native Floating Companion bridge
/// (Milestone 4) or test harnesses.
abstract class FloatingOverlayStateSink {
  Future<void> publishWidgetState(AssistiveTaskSnapshot snapshot);
}

/// Synchronizes [TaskOrchestrator] execution state and [AudioBloc] speaking
/// state to all listeners (in-app status UI and optional floating companion)
/// without exposing sensitive scene descriptions or phone numbers.
class FeedbackDispatcher {
  FeedbackDispatcher({
    required this.orchestrator,
    required this.audioBloc,
  });

  final TaskOrchestrator orchestrator;
  final AudioBloc audioBloc;

  StreamSubscription<AssistiveTaskSnapshot>? _taskSub;
  StreamSubscription<AudioBlocState>? _audioSub;
  FloatingOverlayStateSink? _overlaySink;

  void attachOverlaySink(FloatingOverlayStateSink? sink) {
    _overlaySink = sink;
  }

  void start() {
    _taskSub ??= orchestrator.snapshots.listen((snap) {
      _overlaySink?.publishWidgetState(_sanitizeForExternalSurface(snap));
    });
    _audioSub ??= audioBloc.stream.listen((audioState) {
      final active = orchestrator.currentSnapshot;
      if (audioState.isSpeaking &&
          active.phase != AssistiveTaskPhase.emergencyFlow &&
          active.isBusy) {
        orchestrator.updatePhase(
          active.taskId,
          AssistiveTaskPhase.speaking,
          statusLabel: 'Speaking response',
        );
      }
    });
  }

  static AssistiveTaskSnapshot _sanitizeForExternalSurface(
    AssistiveTaskSnapshot raw,
  ) {
    final safeLabel = switch (raw.phase) {
      AssistiveTaskPhase.idle => 'Openetra ready',
      AssistiveTaskPhase.activated => 'Starting action',
      AssistiveTaskPhase.listening => 'Listening offline',
      AssistiveTaskPhase.processing => 'Processing',
      AssistiveTaskPhase.aiInference => 'Analyzing locally',
      AssistiveTaskPhase.speaking => 'Speaking',
      AssistiveTaskPhase.completed => 'Completed',
      AssistiveTaskPhase.failed => 'Action unavailable',
      AssistiveTaskPhase.paused => 'Paused',
      AssistiveTaskPhase.emergencyFlow => 'Emergency confirmation',
    };
    return AssistiveTaskSnapshot(
      taskId: raw.taskId,
      actionId: raw.actionId,
      phase: raw.phase,
      statusLabel: safeLabel,
      sourceTrigger: raw.sourceTrigger,
      updatedAt: raw.updatedAt,
      isEmergency: raw.isEmergency,
    );
  }

  Future<void> dispose() async {
    await _taskSub?.cancel();
    await _audioSub?.cancel();
  }
}

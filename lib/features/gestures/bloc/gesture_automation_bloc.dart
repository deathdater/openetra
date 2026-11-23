import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/assistive/assistive_action.dart';
import '../../../core/assistive/camera_resource_manager.dart';
import '../../../core/assistive/custom_gesture_record.dart';
import '../../../core/assistive/task_orchestrator.dart';
import '../../../core/storage/openetra_database.dart';
import '../data/native_gesture_gateway.dart';
import '../domain/gesture_enrollment_engine.dart';
import '../domain/gesture_recognition_engine.dart';
import '../domain/hand_landmark_features.dart';

abstract class GestureAutomationEvent extends Equatable {
  const GestureAutomationEvent();

  @override
  List<Object?> get props => [];
}

class LoadGestureConfig extends GestureAutomationEvent {
  const LoadGestureConfig();
}

class SetGestureAutomationEnabled extends GestureAutomationEvent {
  const SetGestureAutomationEnabled(this.enabled);
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class SetEmergencyGestureOptIn extends GestureAutomationEvent {
  const SetEmergencyGestureOptIn(this.optIn);
  final bool optIn;

  @override
  List<Object?> get props => [optIn];
}

class StartGestureEnrollment extends GestureAutomationEvent {
  const StartGestureEnrollment({
    required this.name,
    required this.actionId,
  });

  final String name;
  final AssistiveActionId actionId;

  @override
  List<Object?> get props => [name, actionId];
}

class CaptureEnrollmentSample extends GestureAutomationEvent {
  const CaptureEnrollmentSample({this.syntheticFrame});
  final HandLandmarkFrame? syntheticFrame;

  @override
  List<Object?> get props => [syntheticFrame];
}

class CancelGestureEnrollment extends GestureAutomationEvent {
  const CancelGestureEnrollment();
}

class UpdateGestureMapping extends GestureAutomationEvent {
  const UpdateGestureMapping({
    required this.gestureId,
    required this.actionId,
    this.newName,
  });

  final String gestureId;
  final AssistiveActionId actionId;
  final String? newName;

  @override
  List<Object?> get props => [gestureId, actionId, newName];
}

class ToggleGestureEnabled extends GestureAutomationEvent {
  const ToggleGestureEnabled({required this.gestureId, required this.enabled});
  final String gestureId;
  final bool enabled;

  @override
  List<Object?> get props => [gestureId, enabled];
}

class DeleteCustomGesture extends GestureAutomationEvent {
  const DeleteCustomGesture(this.gestureId);
  final String gestureId;

  @override
  List<Object?> get props => [gestureId];
}

class StartForegroundGestureListening extends GestureAutomationEvent {
  const StartForegroundGestureListening({this.testModeOnly = false});
  final bool testModeOnly;

  @override
  List<Object?> get props => [testModeOnly];
}

class StopForegroundGestureListening extends GestureAutomationEvent {
  const StopForegroundGestureListening();
}

class ProcessGestureLandmarkFrame extends GestureAutomationEvent {
  const ProcessGestureLandmarkFrame(this.frame);
  final HandLandmarkFrame frame;

  @override
  List<Object?> get props => [frame];
}

class GestureAutomationState extends Equatable {
  const GestureAutomationState({
    this.gestures = const [],
    this.isEnabled = false,
    this.emergencyGestureOptIn = false,
    this.isListening = false,
    this.testModeOnly = false,
    this.enrollingName,
    this.enrollingActionId,
    this.capturedSampleCount = 0,
    this.requiredSampleCount = 5,
    this.lastRecognizedGestureName,
    this.statusMessage,
  });

  final List<CustomGestureRecord> gestures;
  final bool isEnabled;
  final bool emergencyGestureOptIn;
  final bool isListening;
  final bool testModeOnly;
  final String? enrollingName;
  final AssistiveActionId? enrollingActionId;
  final int capturedSampleCount;
  final int requiredSampleCount;
  final String? lastRecognizedGestureName;
  final String? statusMessage;

  bool get isEnrolling => enrollingName != null && enrollingActionId != null;

  GestureAutomationState copyWith({
    List<CustomGestureRecord>? gestures,
    bool? isEnabled,
    bool? emergencyGestureOptIn,
    bool? isListening,
    bool? testModeOnly,
    String? enrollingName,
    bool clearEnrollment = false,
    AssistiveActionId? enrollingActionId,
    int? capturedSampleCount,
    int? requiredSampleCount,
    String? lastRecognizedGestureName,
    String? statusMessage,
  }) {
    return GestureAutomationState(
      gestures: gestures ?? this.gestures,
      isEnabled: isEnabled ?? this.isEnabled,
      emergencyGestureOptIn:
          emergencyGestureOptIn ?? this.emergencyGestureOptIn,
      isListening: isListening ?? this.isListening,
      testModeOnly: testModeOnly ?? this.testModeOnly,
      enrollingName:
          clearEnrollment ? null : (enrollingName ?? this.enrollingName),
      enrollingActionId: clearEnrollment
          ? null
          : (enrollingActionId ?? this.enrollingActionId),
      capturedSampleCount:
          clearEnrollment ? 0 : (capturedSampleCount ?? this.capturedSampleCount),
      requiredSampleCount: requiredSampleCount ?? this.requiredSampleCount,
      lastRecognizedGestureName:
          lastRecognizedGestureName ?? this.lastRecognizedGestureName,
      statusMessage: statusMessage,
    );
  }

  @override
  List<Object?> get props => [
        gestures,
        isEnabled,
        emergencyGestureOptIn,
        isListening,
        testModeOnly,
        enrollingName,
        enrollingActionId,
        capturedSampleCount,
        requiredSampleCount,
        lastRecognizedGestureName,
        statusMessage,
      ];
}

/// Manages local hand-gesture enrolment, validation, and foreground recognition.
/// Dispatches validated matches exclusively via [TaskOrchestrator] /
/// [AssistiveActionRouter] so zero domain logic is duplicated.
class GestureAutomationBloc
    extends Bloc<GestureAutomationEvent, GestureAutomationState> {
  GestureAutomationBloc({
    required this.gateway,
    required this.taskOrchestrator,
    this.cameraResourceManager,
    this.database,
    GestureEnrollmentEngine? enrollmentEngine,
    GestureRecognitionEngine? recognitionEngine,
  })  : _enrollment = enrollmentEngine ?? const GestureEnrollmentEngine(),
        _recognition = recognitionEngine ?? GestureRecognitionEngine(),
        super(const GestureAutomationState()) {
    on<LoadGestureConfig>(_onLoad);
    on<SetGestureAutomationEnabled>(_onSetEnabled);
    on<SetEmergencyGestureOptIn>(_onSetEmergencyOptIn);
    on<StartGestureEnrollment>(_onStartEnrollment);
    on<CaptureEnrollmentSample>(_onCaptureSample);
    on<CancelGestureEnrollment>(_onCancelEnrollment);
    on<UpdateGestureMapping>(_onUpdateMapping);
    on<ToggleGestureEnabled>(_onToggleGestureEnabled);
    on<DeleteCustomGesture>(_onDeleteGesture);
    on<StartForegroundGestureListening>(_onStartListening);
    on<StopForegroundGestureListening>(_onStopListening);
    on<ProcessGestureLandmarkFrame>(_onProcessFrame);
  }

  static const String prefEnabledKey = 'gesture_automation_enabled';
  static const String prefEmergencyOptInKey = 'gesture_emergency_opt_in';
  static const _uuid = Uuid();

  final GestureInferenceGateway gateway;
  final TaskOrchestrator taskOrchestrator;
  final CameraResourceManager? cameraResourceManager;
  final OpenetraDatabase? database;
  final GestureEnrollmentEngine _enrollment;
  final GestureRecognitionEngine _recognition;

  final List<List<double>> _pendingSamples = [];
  CameraLease? _activeLease;
  Timer? _pollTimer;
  bool _pollBusy = false;

  Future<void> _onLoad(
    LoadGestureConfig event,
    Emitter<GestureAutomationState> emit,
  ) async {
    final gestures = await database?.listCustomGestures() ?? const [];
    final enabledRaw = await database?.getAssistivePreference(prefEnabledKey);
    final emergRaw =
        await database?.getAssistivePreference(prefEmergencyOptInKey);
    emit(state.copyWith(
      gestures: gestures,
      isEnabled: enabledRaw == 'true',
      emergencyGestureOptIn: emergRaw == 'true',
      requiredSampleCount: _enrollment.minRequiredSamples,
    ));
  }

  Future<void> _onSetEnabled(
    SetGestureAutomationEnabled event,
    Emitter<GestureAutomationState> emit,
  ) async {
    await database?.setAssistivePreference(
      prefEnabledKey,
      event.enabled.toString(),
    );
    if (!event.enabled) {
      await _releaseListeningResources();
    }
    emit(state.copyWith(
      isEnabled: event.enabled,
      isListening: event.enabled ? state.isListening : false,
      statusMessage: event.enabled
          ? 'Custom hand gestures enabled (foreground opt-in only).'
          : 'Custom hand gestures disabled.',
    ));
  }

  Future<void> _onSetEmergencyOptIn(
    SetEmergencyGestureOptIn event,
    Emitter<GestureAutomationState> emit,
  ) async {
    await database?.setAssistivePreference(
      prefEmergencyOptInKey,
      event.optIn.toString(),
    );
    emit(state.copyWith(
      emergencyGestureOptIn: event.optIn,
      statusMessage: event.optIn
          ? 'Emergency gesture opt-in enabled. Matching gestures will still require explicit confirmation before dialing.'
          : 'Emergency gesture mapping disabled.',
    ));
  }

  Future<void> _onStartEnrollment(
    StartGestureEnrollment event,
    Emitter<GestureAutomationState> emit,
  ) async {
    final clean = event.name.trim();
    if (clean.isEmpty) {
      emit(state.copyWith(statusMessage: 'Enter a gesture name before enrolling.'));
      return;
    }
    if (event.actionId == AssistiveActionId.startEmergencyAssistance &&
        !state.emergencyGestureOptIn) {
      emit(state.copyWith(
        statusMessage:
            'Enable the explicit Emergency Gesture Opt-In safeguard first before mapping a gesture to Emergency Assistance.',
      ));
      return;
    }
    _pendingSamples.clear();
    await gateway.loadModel();
    emit(state.copyWith(
      enrollingName: clean,
      enrollingActionId: event.actionId,
      capturedSampleCount: 0,
      requiredSampleCount: _enrollment.minRequiredSamples,
      statusMessage:
          'Enrolling "$clean". Capture ${_enrollment.minRequiredSamples} steady samples of your hand pose.',
    ));
  }

  Future<void> _onCaptureSample(
    CaptureEnrollmentSample event,
    Emitter<GestureAutomationState> emit,
  ) async {
    if (!state.isEnrolling) return;

    HandLandmarkFrame frame;
    if (event.syntheticFrame != null) {
      frame = event.syntheticFrame!;
    } else if (cameraResourceManager != null) {
      try {
        _activeLease ??= await cameraResourceManager!.acquireLease(
          CameraLeasePurpose.gestureSession,
          preemptExisting: true,
        );
        final captured = await cameraResourceManager!.captureFrame(_activeLease!);
        frame = await gateway.extractLandmarks(captured);
      } catch (e) {
        emit(state.copyWith(
          statusMessage: 'Camera unavailable for gesture sample ($e).',
        ));
        return;
      }
    } else {
      emit(state.copyWith(
        statusMessage: 'No camera source available to capture gesture sample.',
      ));
      return;
    }

    final sampleRes = _enrollment.validateSample(frame);
    if (!sampleRes.accepted || sampleRes.featureVector == null) {
      emit(state.copyWith(statusMessage: sampleRes.spokenFeedback));
      return;
    }

    _pendingSamples.add(sampleRes.featureVector!);
    final count = _pendingSamples.length;
    if (count < _enrollment.minRequiredSamples) {
      emit(state.copyWith(
        capturedSampleCount: count,
        statusMessage:
            'Sample $count of ${_enrollment.minRequiredSamples} captured. Hold pose steady and capture next sample.',
      ));
      return;
    }

    final outcome = _enrollment.finalizeEnrollment(
      id: _uuid.v4(),
      name: state.enrollingName!,
      actionId: state.enrollingActionId!,
      sampleVectors: List<List<double>>.from(_pendingSamples),
      existingGestures: state.gestures,
    );
    _pendingSamples.clear();
    await _releaseLeaseOnly();

    if (!outcome.accepted || outcome.record == null) {
      emit(state.copyWith(
        clearEnrollment: true,
        statusMessage: outcome.spokenFeedback,
      ));
      return;
    }

    await database?.upsertCustomGesture(outcome.record!);
    final updated = [...state.gestures, outcome.record!];
    emit(state.copyWith(
      gestures: updated,
      clearEnrollment: true,
      statusMessage: outcome.spokenFeedback,
    ));
  }

  Future<void> _onCancelEnrollment(
    CancelGestureEnrollment event,
    Emitter<GestureAutomationState> emit,
  ) async {
    _pendingSamples.clear();
    await _releaseLeaseOnly();
    emit(state.copyWith(
      clearEnrollment: true,
      statusMessage: 'Gesture enrolment cancelled.',
    ));
  }

  Future<void> _onUpdateMapping(
    UpdateGestureMapping event,
    Emitter<GestureAutomationState> emit,
  ) async {
    if (event.actionId == AssistiveActionId.startEmergencyAssistance &&
        !state.emergencyGestureOptIn) {
      emit(state.copyWith(
        statusMessage:
            'Enable the Emergency Gesture Opt-In safeguard before assigning Emergency Assistance.',
      ));
      return;
    }
    final updated = <CustomGestureRecord>[];
    for (final g in state.gestures) {
      if (g.id == event.gestureId) {
        final next = g.copyWith(
          name: event.newName?.trim().isNotEmpty == true
              ? event.newName!.trim()
              : g.name,
          actionId: event.actionId,
          isEmergencyOptIn:
              event.actionId == AssistiveActionId.startEmergencyAssistance,
          updatedAt: DateTime.now(),
        );
        await database?.upsertCustomGesture(next);
        updated.add(next);
      } else {
        updated.add(g);
      }
    }
    emit(state.copyWith(
      gestures: updated,
      statusMessage: 'Gesture action updated to ${event.actionId.name}.',
    ));
  }

  Future<void> _onToggleGestureEnabled(
    ToggleGestureEnabled event,
    Emitter<GestureAutomationState> emit,
  ) async {
    final updated = <CustomGestureRecord>[];
    for (final g in state.gestures) {
      if (g.id == event.gestureId) {
        final next = g.copyWith(
          isValidated: event.enabled,
          updatedAt: DateTime.now(),
        );
        await database?.upsertCustomGesture(next);
        updated.add(next);
      } else {
        updated.add(g);
      }
    }
    emit(state.copyWith(
      gestures: updated,
      statusMessage: event.enabled ? 'Gesture enabled.' : 'Gesture paused.',
    ));
  }

  Future<void> _onDeleteGesture(
    DeleteCustomGesture event,
    Emitter<GestureAutomationState> emit,
  ) async {
    await database?.deleteCustomGesture(event.gestureId);
    final updated = state.gestures.where((g) => g.id != event.gestureId).toList();
    emit(state.copyWith(
      gestures: updated,
      statusMessage: 'Custom gesture deleted locally.',
    ));
  }

  Future<void> _onStartListening(
    StartForegroundGestureListening event,
    Emitter<GestureAutomationState> emit,
  ) async {
    if (!state.isEnabled && !event.testModeOnly) {
      emit(state.copyWith(
        statusMessage: 'Enable Custom Hand Gestures first before listening.',
      ));
      return;
    }
    if (state.gestures.isEmpty) {
      emit(state.copyWith(
        statusMessage: 'Enrol at least one custom gesture first.',
      ));
      return;
    }
    _recognition.reset();
    await gateway.loadModel();
    if (cameraResourceManager != null) {
      try {
        _activeLease ??= await cameraResourceManager!.acquireLease(
          CameraLeasePurpose.gestureSession,
          minIntervalMs: 250,
          preemptExisting: true,
        );
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
          if (_pollBusy || _activeLease == null || isClosed) return;
          _pollBusy = true;
          try {
            final captured =
                await cameraResourceManager!.captureFrame(_activeLease!);
            final lm = await gateway.extractLandmarks(captured);
            if (!isClosed) add(ProcessGestureLandmarkFrame(lm));
          } catch (_) {
          } finally {
            _pollBusy = false;
          }
        });
      } catch (e) {
        emit(state.copyWith(
          isListening: false,
          statusMessage: 'Could not start gesture camera session ($e).',
        ));
        return;
      }
    }
    emit(state.copyWith(
      isListening: true,
      testModeOnly: event.testModeOnly,
      statusMessage: event.testModeOnly
          ? 'Gesture test mode active (foreground only; actions will not fire).'
          : 'Gesture listening active in foreground.',
    ));
  }

  Future<void> _onStopListening(
    StopForegroundGestureListening event,
    Emitter<GestureAutomationState> emit,
  ) async {
    await _releaseListeningResources();
    emit(state.copyWith(
      isListening: false,
      testModeOnly: false,
      statusMessage: 'Gesture listening stopped.',
    ));
  }

  Future<void> _onProcessFrame(
    ProcessGestureLandmarkFrame event,
    Emitter<GestureAutomationState> emit,
  ) async {
    if (!state.isListening && !state.testModeOnly) return;

    final outcome = _recognition.evaluateFrame(event.frame, state.gestures);
    if (outcome.status != GestureMatchStatus.matched ||
        outcome.matchedGesture == null) {
      return;
    }

    final matched = outcome.matchedGesture!;
    if (state.testModeOnly) {
      emit(state.copyWith(
        lastRecognizedGestureName: matched.name,
        statusMessage:
            'Test mode matched "${matched.name}" (similarity ${(outcome.bestSimilarity * 100).toStringAsFixed(0)}%). Action not executed.',
      ));
      return;
    }

    if (matched.actionId == AssistiveActionId.startEmergencyAssistance &&
        !state.emergencyGestureOptIn) {
      emit(state.copyWith(
        lastRecognizedGestureName: matched.name,
        statusMessage:
            'Emergency gesture blocked because Emergency Gesture Opt-In is disabled.',
      ));
      return;
    }

    await taskOrchestrator.dispatch(
      matched.actionId,
      sourceTrigger: 'custom_gesture',
      fromBackground: false,
    );
    emit(state.copyWith(
      lastRecognizedGestureName: matched.name,
      statusMessage:
          'Recognized "${matched.name}" -> triggered ${matched.actionId.name}.',
    ));
  }

  Future<void> _releaseLeaseOnly() async {
    final lease = _activeLease;
    _activeLease = null;
    if (lease != null) {
      await cameraResourceManager?.releaseLease(lease);
    }
  }

  Future<void> _releaseListeningResources() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollBusy = false;
    await _releaseLeaseOnly();
    await gateway.unloadModel();
  }

  @override
  Future<void> close() async {
    await _releaseListeningResources();
    return super.close();
  }
}

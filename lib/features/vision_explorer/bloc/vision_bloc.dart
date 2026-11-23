import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/camera/camera_controller_bridge.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/ai_model_orchestrator.dart';
import '../../../core/inference/model_provider.dart';

abstract class VisionEvent extends Equatable {
  const VisionEvent();

  @override
  List<Object?> get props => [];
}

class CaptureAndAnalyzeFrame extends VisionEvent {
  const CaptureAndAnalyzeFrame({
    this.task = ModelTask.scenePerception,
    this.overrideProfile,
    this.explicitFrame,
    this.keywords,
  });

  final ModelTask task;
  final MirageQueryProfile? overrideProfile;
  final CapturedFrame? explicitFrame;
  final List<String>? keywords;

  @override
  List<Object?> get props => [task, overrideProfile, explicitFrame, keywords];
}

abstract class VisionState extends Equatable {
  const VisionState();

  @override
  List<Object?> get props => [];
}

class VisionInitial extends VisionState {
  const VisionInitial();
}

class VisionProcessing extends VisionState {
  const VisionProcessing();
}

class VisionObservationReady extends VisionState {
  const VisionObservationReady(this.observation);
  final VisionObservation observation;

  @override
  List<Object?> get props => [observation];
}

class VisionError extends VisionState {
  const VisionError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class VisionBloc extends Bloc<VisionEvent, VisionState> {
  VisionBloc({
    required this.orchestrator,
    required this.cameraSource,
  }) : super(const VisionInitial()) {
    on<CaptureAndAnalyzeFrame>(_onCaptureAndAnalyze);
  }

  final AIModelOrchestrator orchestrator;
  final CameraSource cameraSource;

  Future<void> _onCaptureAndAnalyze(
    CaptureAndAnalyzeFrame event,
    Emitter<VisionState> emit,
  ) async {
    emit(const VisionProcessing());
    try {
      final frame = event.explicitFrame ?? await cameraSource.captureFrame();
      final obs = await orchestrator.runVisualPerception(
        frame,
        task: event.task,
        overrideProfile: event.overrideProfile,
        keywords: event.keywords,
      );
      emit(VisionObservationReady(obs));
    } catch (e) {
      emit(VisionError(e.toString()));
    }
  }
}

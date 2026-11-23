import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/entities/entities.dart';

abstract class HazardDetectionEvent extends Equatable {
  const HazardDetectionEvent();

  @override
  List<Object?> get props => [];
}

class EvaluateHazardFrame extends HazardDetectionEvent {
  const EvaluateHazardFrame(this.observation, {this.depthMetersHint});
  final VisionObservation observation;
  final double? depthMetersHint;

  @override
  List<Object?> get props => [observation, depthMetersHint];
}

class ResetHazardTracker extends HazardDetectionEvent {
  const ResetHazardTracker();
}

class HazardDetectionState extends Equatable {
  const HazardDetectionState({
    this.latestAssessment,
    this.isActive = false,
  });

  final HazardAssessment? latestAssessment;
  final bool isActive;

  @override
  List<Object?> get props => [latestAssessment, isActive];
}

/// Phase 1 baseline BLoC; full HazardIntelligenceEngine attaches in Phase 4 (v0.5.0).
class HazardDetectionBloc
    extends Bloc<HazardDetectionEvent, HazardDetectionState> {
  HazardDetectionBloc({
    HazardAssessment Function(VisionObservation)? evaluator,
    void Function()? onReset,
  })  : _evaluator = evaluator,
        _onReset = onReset,
        super(const HazardDetectionState()) {
    on<EvaluateHazardFrame>(_onEvaluate);
    on<ResetHazardTracker>(_onResetTracker);
  }

  HazardAssessment Function(VisionObservation)? _evaluator;
  void Function()? _onReset;

  void attachEngine({
    required HazardAssessment Function(VisionObservation) evaluator,
    required void Function() onReset,
  }) {
    _evaluator = evaluator;
    _onReset = onReset;
  }

  void _onEvaluate(
    EvaluateHazardFrame event,
    Emitter<HazardDetectionState> emit,
  ) {
    final assessment = _evaluator != null
        ? _evaluator!(event.observation)
        : HazardAssessment(
            assessmentId: event.observation.provenance.observationId,
            timestamp: DateTime.now(),
            overallSeverity: HazardSeverity.info,
            observations: const [],
            degradedModeActive: event.observation.imageQuality.isDegraded,
            spokenAdvisory: event.observation.imageQuality.isDegraded
                ? 'Camera visibility is degraded; proceed carefully using your white cane.'
                : 'Hazard intelligence engine initializing; continue using your white cane.',
            policyNotes: const ['Always verify path physically with white cane.'],
          );
    emit(HazardDetectionState(latestAssessment: assessment, isActive: true));
  }

  void _onResetTracker(
    ResetHazardTracker event,
    Emitter<HazardDetectionState> emit,
  ) {
    _onReset?.call();
    emit(const HazardDetectionState(isActive: false));
  }
}

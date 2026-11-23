import 'package:equatable/equatable.dart';
import 'object_detection.dart';
import 'scene_graph.dart';

enum HazardCategory {
  groundLevel,
  verticalOverhead,
  elevationChange,
  traffic,
  indoorObstruction,
  fireSmokeGlassWarning,
}

enum HazardSeverity {
  info,
  caution,
  warning,
  critical,
}

/// Explicitly separated confidence components; never collapsed into a single safety claim.
class HazardConfidenceBreakdown extends Equatable {
  const HazardConfidenceBreakdown({
    required this.detectionConfidence,
    required this.hazardClassificationConfidence,
    required this.spatialConfidence,
    required this.temporalPersistenceScore,
    this.distanceConfidence,
  });

  final double detectionConfidence;
  final double hazardClassificationConfidence;
  final double spatialConfidence;
  final double? distanceConfidence;
  final double temporalPersistenceScore;

  @override
  List<Object?> get props => [
        detectionConfidence,
        hazardClassificationConfidence,
        spatialConfidence,
        distanceConfidence,
        temporalPersistenceScore,
      ];
}

/// Raw hazard candidate extracted from visual observations and optional specialist models.
class HazardObservation extends Equatable {
  const HazardObservation({
    required this.observationId,
    required this.label,
    required this.category,
    required this.boundingBox,
    required this.relativePosition,
    required this.confidenceBreakdown,
    required this.trackId,
    required this.consecutiveFrames,
    required this.isInWalkingPath,
    required this.isApproaching,
    required this.sourceModelId,
    required this.observedAt,
    this.evidenceSummary,
  });

  final String observationId;
  final String label;
  final HazardCategory category;
  final BoundingBox boundingBox;
  final RelativePosition relativePosition;
  final HazardConfidenceBreakdown confidenceBreakdown;
  final int trackId;
  final int consecutiveFrames;
  final bool isInWalkingPath;
  final bool isApproaching;
  final String sourceModelId;
  final DateTime observedAt;
  final String? evidenceSummary;

  @override
  List<Object?> get props => [
        observationId,
        label,
        category,
        boundingBox,
        relativePosition,
        confidenceBreakdown,
        trackId,
        consecutiveFrames,
        isInWalkingPath,
        isApproaching,
        sourceModelId,
        observedAt,
        evidenceSummary,
      ];
}

/// Independent Openetra safety evaluation distinct from raw model prediction.
class HazardAssessment extends Equatable {
  const HazardAssessment({
    required this.assessmentId,
    required this.timestamp,
    required this.overallSeverity,
    required this.observations,
    required this.degradedModeActive,
    required this.spokenAdvisory,
    required this.policyNotes,
    this.degradationReasons = const [],
  });

  final String assessmentId;
  final DateTime timestamp;
  final HazardSeverity overallSeverity;
  final List<HazardObservation> observations;
  final bool degradedModeActive;
  final String spokenAdvisory;
  final List<String> policyNotes;
  final List<String> degradationReasons;

  bool get hasHazards => observations.isNotEmpty;

  @override
  List<Object?> get props => [
        assessmentId,
        timestamp,
        overallSeverity,
        observations,
        degradedModeActive,
        spokenAdvisory,
        policyNotes,
        degradationReasons,
      ];
}

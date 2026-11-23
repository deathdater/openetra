import '../../../core/assistive/assistive_action.dart';
import '../../../core/assistive/custom_gesture_record.dart';
import 'hand_landmark_features.dart';

class SampleValidationOutcome {
  const SampleValidationOutcome({
    required this.accepted,
    required this.spokenFeedback,
    this.featureVector,
  });

  final bool accepted;
  final String spokenFeedback;
  final List<double>? featureVector;
}

class GestureEnrollmentOutcome {
  const GestureEnrollmentOutcome({
    required this.accepted,
    required this.spokenFeedback,
    this.record,
    this.intraConsistency,
    this.maxCollisionSimilarity,
  });

  final bool accepted;
  final String spokenFeedback;
  final CustomGestureRecord? record;
  final double? intraConsistency;
  final double? maxCollisionSimilarity;
}

/// Validates multi-sample local hand gesture enrolment, checking hand presence,
/// intra-gesture consistency, and collision against existing saved gestures.
class GestureEnrollmentEngine {
  const GestureEnrollmentEngine({
    this.minRequiredSamples = 5,
    this.minHandPresence = 0.65,
    this.minIntraConsistency = 0.84,
    this.maxAllowedCollision = 0.90,
  });

  final int minRequiredSamples;
  final double minHandPresence;
  final double minIntraConsistency;
  final double maxAllowedCollision;

  SampleValidationOutcome validateSample(HandLandmarkFrame frame) {
    if (!frame.isValidShape || frame.handPresenceScore < minHandPresence) {
      return const SampleValidationOutcome(
        accepted: false,
        spokenFeedback:
            'Hand not clearly detected. Hold your hand steady in front of the camera and try again.',
      );
    }
    final vec = HandLandmarkFeatureExtractor.extract(frame.rawLandmarks63);
    return SampleValidationOutcome(
      accepted: true,
      spokenFeedback: 'Sample captured.',
      featureVector: vec,
    );
  }

  GestureEnrollmentOutcome finalizeEnrollment({
    required String id,
    required String name,
    required AssistiveActionId actionId,
    required List<List<double>> sampleVectors,
    required List<CustomGestureRecord> existingGestures,
    double threshold = 0.84,
    bool requiresExtraConfirmation = false,
    DateTime? now,
  }) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return const GestureEnrollmentOutcome(
        accepted: false,
        spokenFeedback: 'Gesture name cannot be empty.',
      );
    }
    if (sampleVectors.length < minRequiredSamples) {
      return GestureEnrollmentOutcome(
        accepted: false,
        spokenFeedback:
            'Need at least $minRequiredSamples consistent samples (captured ${sampleVectors.length}).',
      );
    }

    final centroid = HandLandmarkFeatureExtractor.computeCentroid(sampleVectors);
    var minConsistency = 1.0;
    for (final s in sampleVectors) {
      final sim = HandLandmarkFeatureExtractor.cosineSimilarity(s, centroid);
      if (sim < minConsistency) minConsistency = sim;
    }
    if (minConsistency < minIntraConsistency) {
      return GestureEnrollmentOutcome(
        accepted: false,
        intraConsistency: minConsistency,
        spokenFeedback:
            'Recorded samples varied too much. Please repeat the same hand pose steadily $minRequiredSamples times.',
      );
    }

    var maxCollision = -1.0;
    String? collidingName;
    for (final existing in existingGestures) {
      if (existing.id == id || existing.templates.isEmpty) continue;
      final existingCentroid = existing.templates.first;
      final sim = HandLandmarkFeatureExtractor.cosineSimilarity(
        centroid,
        existingCentroid,
      );
      if (sim > maxCollision) {
        maxCollision = sim;
        collidingName = existing.name;
      }
    }
    if (maxCollision >= maxAllowedCollision) {
      return GestureEnrollmentOutcome(
        accepted: false,
        intraConsistency: minConsistency,
        maxCollisionSimilarity: maxCollision,
        spokenFeedback:
            'This gesture is too similar to "$collidingName". Choose a more distinct hand pose so actions do not misfire.',
      );
    }

    final timestamp = now ?? DateTime.now();
    // Store centroid at index 0 followed by individual normalized sample vectors.
    final record = CustomGestureRecord(
      id: id,
      name: cleanName,
      actionId: actionId,
      sampleCount: sampleVectors.length,
      templates: [centroid, ...sampleVectors],
      threshold: threshold.clamp(0.75, 0.96),
      isValidated: true,
      isEmergencyOptIn: requiresExtraConfirmation ||
          actionId == AssistiveActionId.startEmergencyAssistance,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    return GestureEnrollmentOutcome(
      accepted: true,
      record: record,
      intraConsistency: minConsistency,
      maxCollisionSimilarity: maxCollision,
      spokenFeedback:
          'Gesture "$cleanName" enrolled and validated locally for ${actionId.name}.',
    );
  }
}

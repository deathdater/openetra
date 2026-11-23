import '../../../core/assistive/assistive_action.dart';
import '../../../core/assistive/custom_gesture_record.dart';
import 'hand_landmark_features.dart';

enum GestureMatchStatus {
  noHand,
  unknownRejected,
  ambiguousRejected,
  stabilizing,
  cooldownSuppressed,
  matched,
}

class GestureMatchOutcome {
  const GestureMatchOutcome({
    required this.status,
    required this.reason,
    this.matchedGesture,
    this.bestSimilarity = -1.0,
    this.secondBestSimilarity = -1.0,
  });

  final GestureMatchStatus status;
  final String reason;
  final CustomGestureRecord? matchedGesture;
  final double bestSimilarity;
  final double secondBestSimilarity;
}

/// Offline personalized gesture matcher with strict unknown rejection, top-2
/// ambiguity margin, sliding-window temporal voting, and per-action cooldowns.
class GestureRecognitionEngine {
  GestureRecognitionEngine({
    DateTime Function()? clock,
    this.minHandPresence = 0.65,
    this.defaultMinSimilarity = 0.84,
    this.minTop2Margin = 0.06,
    this.windowSize = 4,
    this.requiredVotes = 3,
    this.normalCooldown = const Duration(milliseconds: 2000),
    this.emergencyCooldown = const Duration(milliseconds: 4000),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final double minHandPresence;
  final double defaultMinSimilarity;
  final double minTop2Margin;
  final int windowSize;
  final int requiredVotes;
  final Duration normalCooldown;
  final Duration emergencyCooldown;

  final List<String?> _voteWindow = [];
  DateTime? _lastTriggerAt;
  AssistiveActionId? _lastTriggeredAction;

  void reset() {
    _voteWindow.clear();
    _lastTriggerAt = null;
    _lastTriggeredAction = null;
  }

  /// Scores a single feature vector against [enrolledGestures] without temporal state.
  ({CustomGestureRecord? best, double bestSim, double secondBestSim}) scoreVector(
    List<double> featureVector,
    List<CustomGestureRecord> enrolledGestures,
  ) {
    CustomGestureRecord? bestRecord;
    var bestSim = -1.0;
    var secondBestSim = -1.0;

    for (final g in enrolledGestures) {
      if (!g.isValidated || g.templates.isEmpty) continue;
      final centroidSim = HandLandmarkFeatureExtractor.cosineSimilarity(
        featureVector,
        g.templates.first,
      );
      var maxSampleSim = centroidSim;
      for (var i = 1; i < g.templates.length; i++) {
        final s = HandLandmarkFeatureExtractor.cosineSimilarity(
          featureVector,
          g.templates[i],
        );
        if (s > maxSampleSim) maxSampleSim = s;
      }
      final combined = 0.6 * centroidSim + 0.4 * maxSampleSim;
      if (combined > bestSim) {
        secondBestSim = bestSim;
        bestSim = combined;
        bestRecord = g;
      } else if (combined > secondBestSim) {
        secondBestSim = combined;
      }
    }
    return (best: bestRecord, bestSim: bestSim, secondBestSim: secondBestSim);
  }

  GestureMatchOutcome evaluateFrame(
    HandLandmarkFrame frame,
    List<CustomGestureRecord> enrolledGestures,
  ) {
    if (!frame.isValidShape || frame.handPresenceScore < minHandPresence) {
      _pushVote(null);
      return const GestureMatchOutcome(
        status: GestureMatchStatus.noHand,
        reason: 'No hand clearly present in frame.',
      );
    }

    final vec = HandLandmarkFeatureExtractor.extract(frame.rawLandmarks63);
    final scored = scoreVector(vec, enrolledGestures);
    final best = scored.best;
    if (best == null) {
      _pushVote(null);
      return const GestureMatchOutcome(
        status: GestureMatchStatus.unknownRejected,
        reason: 'No enabled gestures configured.',
      );
    }

    final requiredThreshold = best.threshold > defaultMinSimilarity
        ? best.threshold
        : defaultMinSimilarity;

    if (scored.bestSim < requiredThreshold) {
      _pushVote(null);
      return GestureMatchOutcome(
        status: GestureMatchStatus.unknownRejected,
        reason: 'Pose did not meet similarity threshold.',
        bestSimilarity: scored.bestSim,
        secondBestSimilarity: scored.secondBestSim,
      );
    }

    if (scored.secondBestSim > 0 &&
        (scored.bestSim - scored.secondBestSim) < minTop2Margin) {
      _pushVote(null);
      return GestureMatchOutcome(
        status: GestureMatchStatus.ambiguousRejected,
        reason: 'Pose ambiguous between multiple enrolled gestures.',
        bestSimilarity: scored.bestSim,
        secondBestSimilarity: scored.secondBestSim,
      );
    }

    _pushVote(best.id);
    final votes = _voteWindow.where((id) => id == best.id).length;
    if (votes < requiredVotes) {
      return GestureMatchOutcome(
        status: GestureMatchStatus.stabilizing,
        reason: 'Waiting for consistent gesture ($votes/$requiredVotes frames).',
        matchedGesture: best,
        bestSimilarity: scored.bestSim,
        secondBestSimilarity: scored.secondBestSim,
      );
    }

    final now = _clock();
    final requiredCooldown =
        best.actionId == AssistiveActionId.startEmergencyAssistance
            ? emergencyCooldown
            : normalCooldown;
    if (_lastTriggerAt != null &&
        now.difference(_lastTriggerAt!) < requiredCooldown &&
        _lastTriggeredAction == best.actionId) {
      return GestureMatchOutcome(
        status: GestureMatchStatus.cooldownSuppressed,
        reason: 'Suppressed during post-trigger cooldown.',
        matchedGesture: best,
        bestSimilarity: scored.bestSim,
        secondBestSimilarity: scored.secondBestSim,
      );
    }

    _lastTriggerAt = now;
    _lastTriggeredAction = best.actionId;
    _voteWindow.clear();
    return GestureMatchOutcome(
      status: GestureMatchStatus.matched,
      reason: 'Matched "${best.name}" cleanly.',
      matchedGesture: best,
      bestSimilarity: scored.bestSim,
      secondBestSimilarity: scored.secondBestSim,
    );
  }

  void _pushVote(String? id) {
    _voteWindow.add(id);
    if (_voteWindow.length > windowSize) {
      _voteWindow.removeAt(0);
    }
  }
}

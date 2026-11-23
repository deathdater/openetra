import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';
import '../../../core/inference/specialist/native_specialist_providers.dart';
import '../../../core/storage/openetra_database.dart';
import 'recorded_scene_memory.dart';
import 'scene_understanding_engine.dart';

/// Relates live or recorded scene observations to the user's locally stored
/// personal objects (`personal_objects` + `object_embeddings`), recognizing
/// registered items with high certainty via 96-dim cosine similarity (>= 0.80)
/// or high-confidence label matching (>= 0.72).
class RegisteredObjectSceneMatcher {
  const RegisteredObjectSceneMatcher({
    this.embeddingThreshold = 0.80,
    this.labelConfidenceThreshold = 0.72,
  });

  final double embeddingThreshold;
  final double labelConfidenceThreshold;

  Future<List<RecognizedRegisteredMatch>> matchInObservation({
    required VisionObservation observation,
    required OpenetraDatabase database,
    CapturedFrame? frame,
    EmbeddingProvider? embeddingProvider,
  }) async {
    final profiles = await database.listPersonalObjects();
    if (profiles.isEmpty || observation.objects.isEmpty) return const [];

    final matches = <RecognizedRegisteredMatch>[];
    final seenProfileIds = <String>{};

    for (final profile in profiles) {
      final embeddings = await database.getObjectEmbeddings(profile.id);
      final targetLower = profile.name.trim().toLowerCase();
      if (targetLower.isEmpty) continue;

      RecognizedRegisteredMatch? bestMatch;

      for (final det in observation.objects) {
        final detLower = det.name.trim().toLowerCase();
        final labelMatches = detLower == targetLower ||
            detLower.contains(targetLower) ||
            targetLower.contains(detLower);

        final pos = SceneUnderstandingEngine.deriveRelativePosition(
          det.boundingBox,
          positionHint: det.positionHint,
        );
        final zone = RecordedSceneAggregator.zoneKey(pos);

        // Tier 1: Visual 96-dim embedding verification when saved embeddings exist.
        if (embeddings.isNotEmpty &&
            frame != null &&
            frame.rgbBytes != null &&
            embeddingProvider != null &&
            det.confidence >= 0.45) {
          final liveVec = await embeddingProvider.computeEmbedding(
            frame,
            det.boundingBox,
          );
          if (liveVec != null && liveVec.isNotEmpty) {
            var bestCos = -1.0;
            for (final savedVec in embeddings) {
              final cos = cosineSimilarity(liveVec, savedVec);
              if (cos > bestCos) bestCos = cos;
            }
            if (bestCos >= embeddingThreshold) {
              if (bestMatch == null || bestCos > bestMatch.certainty) {
                bestMatch = RecognizedRegisteredMatch(
                  objectId: profile.id,
                  objectName: profile.name,
                  zone: zone,
                  certainty: bestCos,
                  matchedByEmbedding: true,
                );
              }
              continue;
            }
          }
        }

        // Tier 2: High-confidence label match when visual embeddings aren't present.
        if (embeddings.isEmpty &&
            labelMatches &&
            det.confidence >= labelConfidenceThreshold) {
          if (bestMatch == null || det.confidence > bestMatch.certainty) {
            bestMatch = RecognizedRegisteredMatch(
              objectId: profile.id,
              objectName: profile.name,
              zone: zone,
              certainty: det.confidence,
              matchedByEmbedding: false,
            );
          }
        }
      }

      if (bestMatch != null && seenProfileIds.add(profile.id)) {
        matches.add(bestMatch);
        final now = DateTime.now();
        await database.recordLastSeen(
          id: '${profile.id}_${now.millisecondsSinceEpoch}',
          objectId: profile.id,
          sceneSetting: observation.setting ?? 'scene',
          relativePosition: bestMatch.zone,
          confidence: bestMatch.certainty,
          seenAt: now,
        );
      }
    }

    matches.sort((a, b) => b.certainty.compareTo(a.certainty));
    return matches;
  }
}

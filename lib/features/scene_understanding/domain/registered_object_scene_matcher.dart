import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';
import '../../../core/inference/specialist/native_specialist_providers.dart';
import '../../../core/storage/openetra_database.dart';
import 'recorded_scene_memory.dart';
import 'scene_understanding_engine.dart';

/// Relates live, search, or recorded scene observations to the user's locally
/// stored personal objects (`personal_objects` + `object_embeddings`) with
/// strict false-positive protection:
///
/// 1. Semantic label/synonym agreement (`matchesObjectLabel`) is ALWAYS
///    required so an unrelated object (e.g., a chair or wall) is never falsely
///    reported as a registered personal belonging.
/// 2. When saved visual embeddings exist and a live crop embedding is computed,
///    visual appearance MUST corroborate the detection (`cosine >= 0.78`),
///    rejecting different-looking objects of the same class.
/// 3. When no visual embeddings are stored (name-only registration), a high
///    detection confidence (`>= 0.72`) is required.
class RegisteredObjectSceneMatcher {
  const RegisteredObjectSceneMatcher({
    this.embeddingThreshold = 0.78,
    this.minDetectionConfidenceWithEmbedding = 0.50,
    this.labelConfidenceThreshold = 0.72,
  });

  final double embeddingThreshold;
  final double minDetectionConfidenceWithEmbedding;
  final double labelConfidenceThreshold;

  static const Set<String> _stopWords = {
    'my',
    'the',
    'a',
    'an',
    'this',
    'that',
    'personal',
    'registered',
    'item',
    'object',
    'thing',
    'of',
    'for',
    'in',
    'on',
  };

  static const List<Set<String>> _synonymGroups = [
    {'bottle', 'flask', 'tumbler', 'thermos', 'waterbottle'},
    {'cup', 'mug', 'teacup'},
    {'phone', 'mobile', 'cellphone', 'smartphone', 'handset'},
    {'glasses', 'eyeglasses', 'spectacles', 'specs', 'sunglasses', 'goggles'},
    {'key', 'keys', 'keychain', 'keyring'},
    {'wallet', 'billfold', 'cardholder', 'pouch'},
    {'bag', 'backpack', 'handbag', 'tote', 'satchel', 'rucksack', 'purse'},
    {'laptop', 'notebook', 'computer', 'macbook'},
    {'watch', 'wristwatch', 'smartwatch'},
    {'remote', 'controller'},
    {'cane', 'stick'},
    {'headphone', 'headphones', 'earphone', 'earphones', 'earbuds', 'headset'},
    {'charger', 'adapter', 'cable'},
    {'book', 'diary'},
    {'umbrella', 'parasol'},
    {'medicine', 'pill', 'pills', 'tablet', 'tablets'},
  ];

  static String _stem(String token) {
    var t = token.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (t.length > 4 && t.endsWith('es') && !t.endsWith('glasses')) {
      t = t.substring(0, t.length - 2);
    } else if (t.length > 3 && t.endsWith('s') && !t.endsWith('ss')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  static Set<String> _tokens(String raw) {
    return raw
        .toLowerCase()
        .split(RegExp(r'[\s_\-/]+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((w) => w.isNotEmpty && !_stopWords.contains(w))
        .expand((w) => {w, _stem(w)})
        .where((w) => w.isNotEmpty)
        .toSet();
  }

  /// Flexible offline label matcher supporting exact, substring, singular/plural
  /// stems, multi-word user names (e.g. "my blue bottle" <-> "bottle"), and
  /// everyday household synonyms (e.g. "specs" <-> "glasses").
  static bool matchesObjectLabel(String registeredName, String detectedName) {
    final reg = registeredName.trim().toLowerCase();
    final det = detectedName.trim().toLowerCase();
    if (reg.isEmpty || det.isEmpty) return false;
    if (reg == det || reg.contains(det) || det.contains(reg)) return true;

    final regTokens = _tokens(reg);
    final detTokens = _tokens(det);
    if (regTokens.isEmpty || detTokens.isEmpty) return false;

    if (regTokens.intersection(detTokens).isNotEmpty) return true;

    for (final group in _synonymGroups) {
      if (regTokens.intersection(group).isNotEmpty &&
          detTokens.intersection(group).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<List<RecognizedRegisteredMatch>> matchInObservation({
    required VisionObservation observation,
    required OpenetraDatabase database,
    CapturedFrame? frame,
    EmbeddingProvider? embeddingProvider,
    List<PersonalObjectProfile>? profilesOverride,
  }) async {
    final profiles = profilesOverride ?? await database.listPersonalObjects();
    if (profiles.isEmpty || observation.objects.isEmpty) return const [];

    final matches = <RecognizedRegisteredMatch>[];
    final seenProfileIds = <String>{};

    for (final profile in profiles) {
      if (profile.name.trim().isEmpty) continue;
      final embeddings = await database.getObjectEmbeddings(profile.id);

      RecognizedRegisteredMatch? bestMatch;

      for (final det in observation.objects) {
        // Strict semantic gate: never report a registered object if Mirage
        // detected an unrelated object class (e.g., chair, wall, table).
        if (!matchesObjectLabel(profile.name, det.name)) continue;

        final pos = SceneUnderstandingEngine.deriveRelativePosition(
          det.boundingBox,
          positionHint: det.positionHint,
        );
        final zone = RecordedSceneAggregator.zoneKey(pos);

        // Tier 1: When saved visual embeddings exist and live RGB is available,
        // require visual appearance corroboration (>= embeddingThreshold).
        if (embeddings.isNotEmpty &&
            frame != null &&
            frame.rgbBytes != null &&
            embeddingProvider != null) {
          if (det.confidence < minDetectionConfidenceWithEmbedding) continue;
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
            }
            // Do NOT fall back to label-only if a visual embedding was computed
            // and failed verification — this prevents false positives.
            continue;
          }
        }

        // Tier 2: High-confidence label match when no visual embedding is stored
        // (or when embedding provider is unavailable on host).
        if (det.confidence >= labelConfidenceThreshold) {
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

import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';
import '../../../core/inference/specialist/native_specialist_providers.dart';
import '../../../core/storage/openetra_database.dart';
import 'recorded_scene_memory.dart';
import 'scene_understanding_engine.dart';

/// Relates live, search, or recorded scene observations to the user's locally
/// stored personal objects (`personal_objects` + `object_embeddings`),
/// recognizing registered items via:
/// - Tier 1: 96-dim visual embedding cosine similarity (`>= 0.78`, or `>= 0.58`
///   when corroborated by a label match), and
/// - Tier 2: Token/synonym-aware label matching (`>= 0.60` confidence) when
///   visual embeddings are absent or unavailable.
class RegisteredObjectSceneMatcher {
  const RegisteredObjectSceneMatcher({
    this.embeddingThreshold = 0.78,
    this.fusedEmbeddingThreshold = 0.58,
    this.visualRejectionFloor = 0.45,
    this.labelConfidenceThreshold = 0.60,
  });

  final double embeddingThreshold;
  final double fusedEmbeddingThreshold;
  final double visualRejectionFloor;
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
    {'cup', 'mug', 'teacup', 'coffee'},
    {'phone', 'mobile', 'cellphone', 'smartphone', 'handset'},
    {'glasses', 'eyeglasses', 'spectacles', 'specs', 'sunglasses', 'goggles'},
    {'key', 'keys', 'keychain', 'keyring'},
    {'wallet', 'billfold', 'cardholder'},
    {'bag', 'backpack', 'handbag', 'tote', 'satchel', 'rucksack', 'purse'},
    {'laptop', 'notebook', 'computer', 'macbook'},
    {'watch', 'wristwatch', 'smartwatch'},
    {'remote', 'controller'},
    {'cane', 'stick'},
    {'headphone', 'headphones', 'earphone', 'earphones', 'earbuds', 'headset'},
    {'charger', 'adapter', 'cable'},
    {'book', 'notebook', 'diary'},
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
      final embeddings = await database.getObjectEmbeddings(profile.id);
      if (profile.name.trim().isEmpty) continue;

      RecognizedRegisteredMatch? bestMatch;

      for (final det in observation.objects) {
        final labelMatches = matchesObjectLabel(profile.name, det.name);

        final pos = SceneUnderstandingEngine.deriveRelativePosition(
          det.boundingBox,
          positionHint: det.positionHint,
        );
        final zone = RecordedSceneAggregator.zoneKey(pos);

        double? bestCos;
        if (embeddings.isNotEmpty &&
            frame != null &&
            frame.rgbBytes != null &&
            embeddingProvider != null &&
            det.confidence >= 0.35) {
          final liveVec = await embeddingProvider.computeEmbedding(
            frame,
            det.boundingBox,
          );
          if (liveVec != null && liveVec.isNotEmpty) {
            var maxSim = -1.0;
            for (final savedVec in embeddings) {
              final cos = cosineSimilarity(liveVec, savedVec);
              if (cos > maxSim) maxSim = cos;
            }
            bestCos = maxSim;
          }
        }

        // Tier 1A: Strong standalone visual embedding match (even if label differs).
        if (bestCos != null && bestCos >= embeddingThreshold) {
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

        // Tier 1B: Fused label + moderate visual similarity match.
        if (labelMatches &&
            bestCos != null &&
            bestCos >= fusedEmbeddingThreshold &&
            det.confidence >= 0.40) {
          final fused = (bestCos * 0.65) + (det.confidence * 0.35);
          if (bestMatch == null || fused > bestMatch.certainty) {
            bestMatch = RecognizedRegisteredMatch(
              objectId: profile.id,
              objectName: profile.name,
              zone: zone,
              certainty: fused,
              matchedByEmbedding: true,
            );
          }
          continue;
        }

        // Tier 2: Label match when no visual embedding contradicted it.
        // If a live visual embedding was computed and strongly contradicted the
        // saved appearance (< visualRejectionFloor), avoid a false-positive match.
        final visuallyContradicted =
            bestCos != null && bestCos < visualRejectionFloor;
        if (labelMatches &&
            !visuallyContradicted &&
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

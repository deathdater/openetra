import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/localization/indic_scene_lexicon.dart';
import '../../../core/localization/openetra_localizer.dart';
import 'scene_understanding_engine.dart';

class RecordedSceneItem extends Equatable {
  const RecordedSceneItem({
    required this.name,
    required this.zone,
    required this.confidence,
    this.count = 1,
  });

  final String name;
  /// One of: `ahead`, `left`, `right`, `overhead`.
  final String zone;
  final double confidence;
  final int count;

  Map<String, dynamic> toJson() => {
        'name': name,
        'zone': zone,
        'confidence': confidence,
        'count': count,
      };

  static RecordedSceneItem fromJson(Map<String, dynamic> raw) {
    return RecordedSceneItem(
      name: (raw['name'] ?? '').toString(),
      zone: (raw['zone'] ?? 'ahead').toString(),
      confidence: (raw['confidence'] as num?)?.toDouble() ?? 0.5,
      count: (raw['count'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  List<Object?> get props => [name, zone, confidence, count];
}

class RecognizedRegisteredMatch extends Equatable {
  const RecognizedRegisteredMatch({
    required this.objectId,
    required this.objectName,
    required this.zone,
    required this.certainty,
    required this.matchedByEmbedding,
  });

  final String objectId;
  final String objectName;
  /// One of: `ahead`, `left`, `right`, `overhead`.
  final String zone;
  final double certainty;
  final bool matchedByEmbedding;

  Map<String, dynamic> toJson() => {
        'objectId': objectId,
        'objectName': objectName,
        'zone': zone,
        'certainty': certainty,
        'matchedByEmbedding': matchedByEmbedding,
      };

  static RecognizedRegisteredMatch fromJson(Map<String, dynamic> raw) {
    return RecognizedRegisteredMatch(
      objectId: (raw['objectId'] ?? '').toString(),
      objectName: (raw['objectName'] ?? '').toString(),
      zone: (raw['zone'] ?? 'ahead').toString(),
      certainty: (raw['certainty'] as num?)?.toDouble() ?? 0.75,
      matchedByEmbedding: raw['matchedByEmbedding'] == true,
    );
  }

  @override
  List<Object?> get props =>
      [objectId, objectName, zone, certainty, matchedByEmbedding];
}

/// Complete offline scene understanding captured from a multi-frame video pan,
/// with editable title and custom spoken note dynamically voiced in the user's
/// active language (`en-IN` + 7 Indian languages).
class RecordedSceneRecord extends Equatable {
  const RecordedSceneRecord({
    required this.id,
    required this.title,
    required this.environment,
    this.lighting,
    required this.items,
    required this.readableTexts,
    required this.recognizedRegisteredObjects,
    this.customNote,
    required this.frameCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String environment;
  final String? lighting;
  final List<RecordedSceneItem> items;
  final List<String> readableTexts;
  final List<RecognizedRegisteredMatch> recognizedRegisteredObjects;
  final String? customNote;
  final int frameCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecordedSceneRecord copyWith({
    String? title,
    String? customNote,
    DateTime? updatedAt,
  }) {
    return RecordedSceneRecord(
      id: id,
      title: title ?? this.title,
      environment: environment,
      lighting: lighting,
      items: items,
      readableTexts: readableTexts,
      recognizedRegisteredObjects: recognizedRegisteredObjects,
      customNote: customNote ?? this.customNote,
      frameCount: frameCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String encodeSummaryJson() => jsonEncode({
        'lighting': lighting,
        'items': items.map((e) => e.toJson()).toList(),
        'readableTexts': readableTexts,
      });

  String encodeRegisteredMatchesJson() =>
      jsonEncode(recognizedRegisteredObjects.map((e) => e.toJson()).toList());

  static RecordedSceneRecord fromDbRow(Map<String, dynamic> row) {
    final summaryRaw = jsonDecode((row['summary_json'] as String?) ?? '{}');
    final summaryMap = summaryRaw is Map
        ? Map<String, dynamic>.from(summaryRaw)
        : <String, dynamic>{};
    final items = (summaryMap['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => RecordedSceneItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final texts = (summaryMap['readableTexts'] as List? ?? const [])
        .map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final regRaw =
        jsonDecode((row['recognized_objects_json'] as String?) ?? '[]');
    final regList = (regRaw is List ? regRaw : const [])
        .whereType<Map>()
        .map((m) =>
            RecognizedRegisteredMatch.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    return RecordedSceneRecord(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? 'Saved Scene').toString(),
      environment: (row['environment'] ?? 'unclassified area').toString(),
      lighting: summaryMap['lighting']?.toString(),
      items: items,
      readableTexts: texts,
      recognizedRegisteredObjects: regList,
      customNote: row['custom_note']?.toString(),
      frameCount: (row['frame_count'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at_ms'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at_ms'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Dynamically renders the stored scene breakdown + custom note in [locale]
  /// (`en-IN` and all 7 Indian languages).
  String buildSpokenBreakdown(String locale) {
    final lang = OpenetraLocalizer.langCode(locale);
    final parts = <String>[];

    // 1. Title & environment breakdown
    final envClean = environment.trim();
    final hasEnv =
        envClean.isNotEmpty && envClean.toLowerCase() != 'unclassified area';
    if (lang == 'en') {
      if (hasEnv) {
        parts.add(
          'Recorded scene "$title", captured across $frameCount views of a $envClean.',
        );
      } else {
        parts.add('Recorded scene "$title", captured across $frameCount views.');
      }
    } else {
      final envLoc = hasEnv ? IndicSceneLexicon.translateTerm(envClean, lang) : '';
      parts.add(switch (lang) {
        'hi' => hasEnv
            ? 'सहेजा गया दृश्य "$title", $envLoc के $frameCount दृश्यों का पूरा विवरण।'
            : 'सहेजा गया दृश्य "$title", $frameCount दृश्यों का पूरा विवरण।',
        'kn' => hasEnv
            ? 'ಉಳಿಸಿದ ದೃಶ್ಯ "$title", $envLoc ನ $frameCount ನೋಟಗಳ ಸಂಪೂರ್ಣ ವಿವರಣೆ.'
            : 'ಉಳಿಸಿದ ದೃಶ್ಯ "$title", $frameCount ನೋಟಗಳ ಸಂಪೂರ್ಣ ವಿವರಣೆ.',
        'ta' => hasEnv
            ? 'சேமிக்கப்பட்ட காட்சி "$title", $envLoc பகுதியின் $frameCount காட்சிகளின் முழு விளக்கம்.'
            : 'சேமிக்கப்பட்ட காட்சி "$title", $frameCount காட்சிகளின் முழு விளக்கம்.',
        'te' => hasEnv
            ? 'సేవ్ చేసిన దృశ్యం "$title", $envLoc యొక్క $frameCount దృశ్యాల పూర్తి వివరణ.'
            : 'సేవ్ చేసిన దృశ్యం "$title", $frameCount దృశ్యాల పూర్తి వివరణ.',
        'ml' => hasEnv
            ? 'സേവ് ചെയ്ത ദൃശ്യം "$title", $envLoc ഭാഗത്തെ $frameCount കാഴ്ചകളുടെ പൂർണ്ണ വിവരണം.'
            : 'സേവ് ചെയ്ത ദൃശ്യം "$title", $frameCount കാഴ്ചകളുടെ പൂർണ്ണ വിവരണം.',
        'mr' => hasEnv
            ? 'जतन केलेले दृश्य "$title", $envLoc मधील $frameCount दृश्यांचे संपूर्ण वर्णन.'
            : 'जतन केलेले दृश्य "$title", $frameCount दृश्यांचे संपूर्ण वर्णन.',
        'bn' => hasEnv
            ? 'সংরক্ষিত দৃশ্য "$title", $envLoc এলাকার $frameCount টি দৃশ্যের সম্পূর্ণ বিবরণ।'
            : 'সংরক্ষিত দৃশ্য "$title", $frameCount টি দৃশ্যের সম্পূর্ণ বিবরণ।',
        _ => 'Recorded scene "$title".',
      });
    }

    // 2. Spatial breakdown of all items discovered across the video clip
    for (final zone in const ['ahead', 'left', 'right', 'overhead']) {
      final zoneItems = items.where((i) => i.zone == zone).take(4).toList();
      if (zoneItems.isEmpty) continue;
      if (lang == 'en') {
        final names = zoneItems
            .map((e) => e.count > 1 ? '${e.count} ${e.name}s' : e.name)
            .join(', ');
        final prefix = switch (zone) {
          'ahead' => 'Ahead:',
          'left' => 'To the left:',
          'right' => 'To the right:',
          _ => 'Overhead:',
        };
        parts.add('$prefix $names.');
      } else {
        final fakeNodes = zoneItems
            .map(
              (e) => SceneGraphNode(
                entityId: 0,
                name: e.name,
                instanceCount: e.count,
                primaryBox: const BoundingBox(x1: 0, y1: 0, x2: 10, y2: 10),
                relativePosition: const RelativePosition(
                  horizontal: HorizontalZone.center,
                  vertical: VerticalZone.middle,
                ),
                confidence: e.confidence,
                isUncertain: e.confidence < 0.55,
                sourceModelId: 'recorded_scene',
              ),
            )
            .toList();
        parts.add(OpenetraLocalizer.indicZoneBreakdown(zone, fakeNodes, lang));
      }
    }

    // 3. Visible text discovered in clip
    if (readableTexts.isNotEmpty) {
      parts.add(
        OpenetraLocalizer.sceneTextLead(
          readableTexts.take(4).join(', '),
          locale,
        ),
      );
    }

    // 4. Recognized registered personal objects
    for (final reg in recognizedRegisteredObjects.take(3)) {
      parts.add(
        OpenetraLocalizer.registeredObjectSpotted(
          objectName: reg.objectName,
          zone: reg.zone,
          locale: locale,
        ),
      );
    }

    // 5. User's custom modification / personal spoken note
    final note = customNote?.trim() ?? '';
    if (note.isNotEmpty) {
      parts.add(OpenetraLocalizer.customNoteSpoken(note, locale));
    }

    return parts.join(' ');
  }

  @override
  List<Object?> get props => [
        id,
        title,
        environment,
        lighting,
        items,
        readableTexts,
        recognizedRegisteredObjects,
        customNote,
        frameCount,
        createdAt,
        updatedAt,
      ];
}

/// Fuses multiple sampled keyframes from a recorded scene pan into a single
/// deduplicated, holistic [RecordedSceneRecord].
class RecordedSceneAggregator {
  const RecordedSceneAggregator();

  static String zoneKey(RelativePosition pos) {
    if (pos.vertical == VerticalZone.overhead) return 'overhead';
    switch (pos.horizontal) {
      case HorizontalZone.center:
        return 'ahead';
      case HorizontalZone.left:
      case HorizontalZone.farLeft:
        return 'left';
      case HorizontalZone.right:
      case HorizontalZone.farRight:
        return 'right';
    }
  }

  RecordedSceneRecord aggregate({
    required String id,
    required String title,
    required List<VisionObservation> observations,
    List<RecognizedRegisteredMatch> registeredMatches = const [],
    String? customNote,
    DateTime? now,
  }) {
    final envCounts = <String, int>{};
    String? bestLighting;
    final itemBest = <String, RecordedSceneItem>{};
    final textSet = <String>{};

    for (final obs in observations) {
      final env = obs.setting?.trim() ?? '';
      if (env.isNotEmpty && env.toLowerCase() != 'unclassified area') {
        envCounts[env] = (envCounts[env] ?? 0) + 1;
      }
      if (bestLighting == null &&
          obs.lighting != null &&
          obs.lighting!.trim().isNotEmpty) {
        bestLighting = obs.lighting!.trim();
      }
      for (final obj in obs.objects) {
        if (obj.confidence < 0.45) continue;
        final pos = SceneUnderstandingEngine.deriveRelativePosition(
          obj.boundingBox,
          positionHint: obj.positionHint,
        );
        final zone = zoneKey(pos);
        final key = '${obj.name.trim().toLowerCase()}::$zone';
        final existing = itemBest[key];
        if (existing == null || obj.confidence > existing.confidence) {
          itemBest[key] = RecordedSceneItem(
            name: obj.name.trim(),
            zone: zone,
            confidence: obj.confidence,
            count: existing == null ? 1 : existing.count,
          );
        }
      }
      for (final t in obs.textSpans) {
        if (t.confidence >= 0.40 && t.text.trim().isNotEmpty) {
          textSet.add(t.text.trim());
        }
      }
    }

    var dominantEnv = 'unclassified area';
    var topEnvCount = 0;
    envCounts.forEach((k, v) {
      if (v > topEnvCount) {
        topEnvCount = v;
        dominantEnv = k;
      }
    });

    final sortedItems = itemBest.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    // Deduplicate registered matches by objectId keeping highest certainty
    final regById = <String, RecognizedRegisteredMatch>{};
    for (final m in registeredMatches) {
      final prev = regById[m.objectId];
      if (prev == null || m.certainty > prev.certainty) {
        regById[m.objectId] = m;
      }
    }

    final ts = now ?? DateTime.now();
    return RecordedSceneRecord(
      id: id,
      title: title.trim().isEmpty
          ? (dominantEnv != 'unclassified area'
              ? 'Recorded $dominantEnv'
              : 'Recorded Scene')
          : title.trim(),
      environment: dominantEnv,
      lighting: bestLighting,
      items: sortedItems.take(12).toList(),
      readableTexts: textSet.take(8).toList(),
      recognizedRegisteredObjects: regById.values.toList(),
      customNote: customNote,
      frameCount: observations.length,
      createdAt: ts,
      updatedAt: ts,
    );
  }
}

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/entities/entities.dart';
import '../../errors/openetra_failure.dart';
import '../ai_model_registry.dart';

/// Parses empirically verified Cactus Mirage JSON outputs into typed domain
/// [VisionObservation] entities.
class MirageResponseParser {
  const MirageResponseParser();

  static const _uuid = Uuid();

  VisionObservation parse({
    required String rawJson,
    required int inputWidth,
    required int inputHeight,
    required int processingDurationMs,
    required ImageQualityMetrics imageQuality,
    String modelId = AIModelRegistry.mirageId,
    String modelVersion = AIModelRegistry.mirageRevision,
    String sourceCapability = 'mirage_describe',
    DateTime? timestamp,
  }) {
    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(rawJson);
      if (raw is! Map<String, dynamic>) {
        throw const InferenceFailure('Mirage JSON root is not an object');
      }
      decoded = raw;
    } on OpenetraFailure {
      rethrow;
    } catch (e) {
      throw InferenceFailure('Failed parsing Mirage JSON output', cause: e);
    }

    final sceneMetadata = <String, String>{};
    final rawScene = decoded['scene'];
    if (rawScene is Map) {
      for (final entry in rawScene.entries) {
        if (entry.value != null) {
          sceneMetadata[entry.key.toString()] = entry.value.toString();
        }
      }
    }

    final entityNamesById = <int, String>{};
    final objects = <ObjectDetection>[];
    final rawObjects = decoded['objects'];
    if (rawObjects is List) {
      for (final item in rawObjects) {
        if (item is! Map) continue;
        final entityId = (item['id'] as num?)?.toInt() ?? 0;
        final name = (item['name'] ?? 'unknown').toString().trim();
        final score = ((item['score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
        final rawBbox = item['bbox'] is List ? item['bbox'] as List : const [];
        final bbox = BoundingBox.fromList(rawBbox);
        final posHint = item['position']?.toString();

        final attributes = <ObjectAttribute>[];
        final desc = item['description'];
        if (desc is Map) {
          for (final entry in desc.entries) {
            if (entry.value != null) {
              attributes.add(
                ObjectAttribute(
                  key: entry.key.toString(),
                  value: entry.value.toString(),
                ),
              );
            }
          }
        }

        final mask = _parseMask(item['mask']);

        entityNamesById.putIfAbsent(entityId, () => name);
        objects.add(
          ObjectDetection(
            entityId: entityId,
            name: name,
            boundingBox: bbox,
            confidence: score,
            positionHint: posHint,
            attributes: attributes,
            mask: mask,
          ),
        );
      }
    }

    final textSpans = <PerceivedTextSpan>[];
    final rawText = decoded['text'];
    if (rawText is List) {
      for (final item in rawText) {
        if (item is! Map) continue;
        final str = (item['string'] ?? '').toString();
        if (str.trim().isEmpty) continue;
        final rawBbox = item['bbox'] is List ? item['bbox'] as List : const [];
        final score = ((item['score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
        textSpans.add(
          PerceivedTextSpan(
            text: str,
            boundingBox: BoundingBox.fromList(rawBbox),
            confidence: score,
          ),
        );
      }
    }

    final relationships = <SpatialRelationship>[];
    final rawRelations = decoded['relations'];
    if (rawRelations is List) {
      for (final item in rawRelations) {
        if (item is! Map) continue;
        final subId = (item['subject'] as num?)?.toInt() ?? -1;
        final objId = (item['object'] as num?)?.toInt() ?? -1;
        final pred = (item['predicate'] ?? '').toString().trim();
        if (subId < 0 || objId < 0 || pred.isEmpty) continue;

        final subName = entityNamesById[subId] ?? 'object_$subId';
        final objName = entityNamesById[objId] ?? 'object_$objId';
        final subScore = _maxEntityScore(objects, subId);
        final objScore = _maxEntityScore(objects, objId);
        final relConf = (subScore < objScore ? subScore : objScore);

        relationships.add(
          SpatialRelationship(
            subjectEntityId: subId,
            subjectName: subName,
            predicate: pred,
            objectEntityId: objId,
            objectName: objName,
            confidence: relConf,
            source: modelId,
          ),
        );
      }
    }

    final events = <VisualEvent>[];
    final rawEvents = decoded['events'];
    if (rawEvents is List) {
      for (final item in rawEvents) {
        if (item is! Map) continue;
        final actorId = (item['actor'] as num?)?.toInt() ?? -1;
        final action = (item['action'] ?? '').toString().trim();
        if (actorId < 0 || action.isEmpty) continue;
        events.add(
          VisualEvent(
            actorEntityId: actorId,
            actorName: entityNamesById[actorId] ?? 'actor_$actorId',
            action: action,
          ),
        );
      }
    }

    final formResult = decoded['form'] is Map
        ? Map<String, dynamic>.from(decoded['form'] as Map)
        : const <String, dynamic>{};

    final topObjectConf = objects.isEmpty
        ? 0.0
        : objects.map((o) => o.confidence).reduce((a, b) => a > b ? a : b);
    final topTextConf = textSpans.isEmpty
        ? 0.0
        : textSpans.map((t) => t.confidence).reduce((a, b) => a > b ? a : b);
    final overallConfidence =
        topObjectConf > topTextConf ? topObjectConf : topTextConf;

    final status = imageQuality.isDegraded
        ? ValidationStatus.degraded
        : (overallConfidence >= 0.45 || formResult.isNotEmpty
            ? ValidationStatus.verified
            : ValidationStatus.uncertain);

    return VisionObservation(
      provenance: ObservationProvenance(
        observationId: _uuid.v4(),
        timestamp: timestamp ?? DateTime.now(),
        modelId: modelId,
        modelVersion: modelVersion,
        confidence: overallConfidence,
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        processingDurationMs: processingDurationMs,
        sourceCapability: sourceCapability,
        validationStatus: status,
      ),
      imageQuality: imageQuality,
      sceneMetadata: sceneMetadata,
      objects: objects,
      textSpans: textSpans,
      relationships: relationships,
      events: events,
      formResult: formResult,
      rawReasoningTrace: decoded['reasoning']?.toString(),
    );
  }

  static double _maxEntityScore(List<ObjectDetection> objects, int id) {
    double best = 0.35;
    for (final o in objects) {
      if (o.entityId == id && o.confidence > best) {
        best = o.confidence;
      }
    }
    return best;
  }

  static SegmentationMask? _parseMask(dynamic rawMask) {
    if (rawMask == null) return null;
    if (rawMask is Map) {
      final rawSize = rawMask['size'];
      final rawCounts = rawMask['counts'];
      final size = rawSize is List
          ? rawSize.map((e) => (e as num).toInt()).toList()
          : null;
      final counts = rawCounts is List
          ? rawCounts.map((e) => (e as num).toInt()).toList()
          : const <int>[];
      return SegmentationMask(
        format: MaskFormat.bitmap,
        bitmapSize: size,
        bitmapRleCounts: counts,
      );
    }
    if (rawMask is List && rawMask.isNotEmpty) {
      if (rawMask.first is List) {
        final polys = rawMask
            .whereType<List>()
            .map((p) => p.map((e) => (e as num).toInt()).toList())
            .toList();
        return SegmentationMask(format: MaskFormat.polygons, polygons: polys);
      }
      final flat = rawMask.whereType<num>().map((e) => e.toInt()).toList();
      return SegmentationMask(format: MaskFormat.largest, polygons: [flat]);
    }
    return null;
  }
}

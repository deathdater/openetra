import '../../../core/domain/entities/entities.dart';

/// Deterministic scene graph builder & accessibility-first summary generator.
/// Never invents relationships or metric distances and always separates
/// high-confidence observations from uncertain guesses.
class SceneUnderstandingEngine {
  const SceneUnderstandingEngine({
    this.uncertainThreshold = 0.45,
    this.relationConfidenceThreshold = 0.48,
  });

  final double uncertainThreshold;
  final double relationConfidenceThreshold;

  SceneDescription build(
    VisionObservation observation, {
    SceneGraph? previousGraph,
  }) {
    final groupedNodes = _buildDeduplicatedNodes(observation);
    final groundLevelNodes = groupedNodes
        .where((n) => n.relativePosition.vertical == VerticalZone.groundLevel)
        .toList(growable: false);
    final overheadNodes = groupedNodes
        .where((n) => n.relativePosition.vertical == VerticalZone.overhead)
        .toList(growable: false);
    final uncertainNodes = groupedNodes
        .where((n) => n.isUncertain)
        .toList(growable: false);

    final groundedRelations = observation.relationships
        .where((r) =>
            r.subjectEntityId != r.objectEntityId &&
            r.confidence >= relationConfidenceThreshold)
        .toList(growable: false);

    final changes = _computeChanges(previousGraph, groupedNodes);
    final readableTexts = observation.textSpans
        .where((t) => t.confidence >= 0.40 && t.text.trim().isNotEmpty)
        .map((t) => t.text.trim())
        .toList(growable: false);

    final environment = observation.setting?.trim().isNotEmpty == true
        ? observation.setting!.trim()
        : 'unclassified area';

    final graph = SceneGraph(
      provenance: observation.provenance,
      environmentCategory: environment,
      nodes: groupedNodes,
      relationships: groundedRelations,
      events: observation.events,
      groundLevelNodes: groundLevelNodes,
      overheadNodes: overheadNodes,
      uncertainNodes: uncertainNodes,
      changes: changes,
      readableTexts: readableTexts,
      surface: observation.surface,
      lighting: observation.lighting,
    );

    final keyPoints = _buildKeyPoints(
      observation: observation,
      graph: graph,
    );
    final spoken = _composeSpeech(
      observation: observation,
      graph: graph,
    );

    return SceneDescription(
      provenance: observation.provenance,
      sceneGraph: graph,
      spokenSummary: spoken,
      keyPoints: keyPoints,
      metadata: SceneSummaryMetadata(
        hasUncertainElements: uncertainNodes.isNotEmpty,
        isDegraded: observation.imageQuality.isDegraded,
        totalNodes: groupedNodes.length,
        degradationNote: observation.imageQuality.isDegraded
            ? observation.imageQuality.degradationReasons.join(', ')
            : null,
      ),
    );
  }

  List<SceneGraphNode> _buildDeduplicatedNodes(VisionObservation obs) {
    final buckets = <String, List<ObjectDetection>>{};
    for (final obj in obs.objects) {
      final normName = obj.name.trim().toLowerCase();
      final key = '${obj.entityId}::$normName';
      buckets.putIfAbsent(key, () => []).add(obj);
    }

    final nodes = <SceneGraphNode>[];
    for (final group in buckets.values) {
      group.sort((a, b) => b.confidence.compareTo(a.confidence));
      final lead = group.first;
      final relPos = deriveRelativePosition(
        lead.boundingBox,
        positionHint: lead.positionHint,
      );
      nodes.add(
        SceneGraphNode(
          entityId: lead.entityId,
          name: lead.name,
          instanceCount: group.length,
          primaryBox: lead.boundingBox,
          relativePosition: relPos,
          confidence: lead.confidence,
          sourceModelId: obs.provenance.modelId,
          isUncertain: lead.confidence < uncertainThreshold,
          attributes: lead.attributes,
        ),
      );
    }

    // Prioritize center/foreground and high-confidence entities first.
    nodes.sort((a, b) {
      final prioA = _salienceScore(a);
      final prioB = _salienceScore(b);
      return prioB.compareTo(prioA);
    });
    return nodes;
  }

  static double _salienceScore(SceneGraphNode n) {
    double s = n.confidence;
    if (n.relativePosition.horizontal == HorizontalZone.center) s += 0.25;
    if (n.relativePosition.vertical == VerticalZone.groundLevel) s += 0.15;
    if (n.primaryBox.areaRatio > 0.12) s += 0.15;
    if (n.isUncertain) s -= 0.30;
    return s;
  }

  static RelativePosition deriveRelativePosition(
    BoundingBox box, {
    String? positionHint,
  }) {
    final cx = box.centerX;
    final cy = box.centerY;

    final HorizontalZone h;
    if (cx < 200) {
      h = HorizontalZone.farLeft;
    } else if (cx < 380) {
      h = HorizontalZone.left;
    } else if (cx <= 620) {
      h = HorizontalZone.center;
    } else if (cx <= 800) {
      h = HorizontalZone.right;
    } else {
      h = HorizontalZone.farRight;
    }

    final hint = (positionHint ?? '').toLowerCase();
    final VerticalZone v;
    if (cy < 250 || hint.contains('ceiling') || hint.contains('overhead')) {
      v = VerticalZone.overhead;
    } else if (box.y2 > 750 ||
        cy > 680 ||
        hint.contains('floor') ||
        hint.contains('foreground') ||
        hint.contains('ground')) {
      v = VerticalZone.groundLevel;
    } else {
      v = VerticalZone.middle;
    }

    return RelativePosition(horizontal: h, vertical: v);
  }

  static List<SceneChange> _computeChanges(
    SceneGraph? prev,
    List<SceneGraphNode> current,
  ) {
    if (prev == null) return const [];
    final changes = <SceneChange>[];
    final prevByName = <String, SceneGraphNode>{
      for (final n in prev.nodes) n.name.toLowerCase(): n,
    };
    final currByName = <String, SceneGraphNode>{
      for (final n in current) n.name.toLowerCase(): n,
    };

    for (final entry in currByName.entries) {
      final old = prevByName[entry.key];
      if (old == null) {
        changes.add(
          SceneChange(
            type: SceneChangeType.appeared,
            objectName: entry.value.name,
            summary:
                '${entry.value.name} appeared in the ${entry.value.relativePosition.toSpokenPhrase()}',
          ),
        );
      } else if (old.relativePosition.horizontal !=
          entry.value.relativePosition.horizontal) {
        changes.add(
          SceneChange(
            type: SceneChangeType.shifted,
            objectName: entry.value.name,
            summary:
                '${entry.value.name} shifted toward ${entry.value.relativePosition.toSpokenPhrase()}',
          ),
        );
      }
    }

    for (final entry in prevByName.entries) {
      if (!currByName.containsKey(entry.key)) {
        changes.add(
          SceneChange(
            type: SceneChangeType.disappeared,
            objectName: entry.value.name,
            summary: '${entry.value.name} is no longer in view',
          ),
        );
      }
    }
    return changes;
  }

  static String _formatNodePhrase(SceneGraphNode n) {
    final label = n.instanceCount > 1
        ? '${n.instanceCount} ${_pluralize(n.name)}'
        : n.name;
    final pos = n.relativePosition.toSpokenPhrase();
    return '$label ($pos)';
  }

  static String _pluralize(String name) {
    final trimmed = name.trim();
    if (trimmed.endsWith('s')) return trimmed;
    return '${trimmed}s';
  }

  List<String> _buildKeyPoints({
    required VisionObservation observation,
    required SceneGraph graph,
  }) {
    final points = <String>[];
    if (observation.imageQuality.isDegraded) {
      points.add(
        'Visibility degraded due to ${observation.imageQuality.degradationReasons.join(" and ")}.',
      );
    }
    points.add('Environment: ${graph.environmentCategory}');
    for (final node in graph.nodes.where((n) => !n.isUncertain).take(5)) {
      points.add('${_formatNodePhrase(node)} [${(node.confidence * 100).round()}%]');
    }
    if (graph.readableTexts.isNotEmpty) {
      points.add('Visible text: ${graph.readableTexts.join(", ")}');
    }
    return points;
  }

  String _composeSpeech({
    required VisionObservation observation,
    required SceneGraph graph,
  }) {
    final parts = <String>[];

    if (observation.imageQuality.isDegraded) {
      parts.add(
        'Image quality is limited due to ${observation.imageQuality.degradationReasons.join(" and ")}.',
      );
    }

    final settingClause = StringBuffer('You appear to be in a ${graph.environmentCategory}');
    if (graph.surface != null && graph.surface!.isNotEmpty) {
      settingClause.write(' on a ${graph.surface} surface');
    }
    if (graph.lighting != null && graph.lighting!.isNotEmpty) {
      settingClause.write(' with ${graph.lighting} lighting');
    }
    settingClause.write('.');
    parts.add(settingClause.toString());

    final confidentNodes = graph.nodes.where((n) => !n.isUncertain).toList();
    if (confidentNodes.isNotEmpty) {
      final topItems = confidentNodes.take(4).map(_formatNodePhrase).join(', ');
      parts.add('Key items visible: $topItems.');
    } else if (graph.nodes.isEmpty) {
      parts.add('No distinct objects stood out clearly in this frame.');
    }

    if (graph.relationships.isNotEmpty) {
      final rel = graph.relationships.first;
      parts.add('${rel.subjectName} is ${rel.predicate.replaceAll("_", " ")} ${rel.objectName}.');
    }

    if (graph.events.isNotEmpty) {
      final ev = graph.events.first;
      parts.add('${ev.actorName} appears to be ${ev.action}.');
    }

    if (graph.readableTexts.isNotEmpty) {
      parts.add('Visible text reads: ${graph.readableTexts.take(3).join(", ")}.');
    }

    final uncertain = graph.uncertainNodes.take(2).map((n) => n.name).toList();
    if (uncertain.isNotEmpty) {
      parts.add('Possibly also present, with lower certainty: ${uncertain.join(", ")}.');
    }

    return parts.join(' ');
  }
}

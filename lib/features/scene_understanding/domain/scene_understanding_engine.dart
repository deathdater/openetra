import '../../../core/domain/entities/entities.dart';
import '../../../core/localization/openetra_localizer.dart';

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
    String locale = 'en-IN',
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
      locale: locale,
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

  static String _formatNodePhrase(SceneGraphNode n, {String locale = 'en-IN'}) {
    final label = n.instanceCount > 1
        ? '${n.instanceCount} ${_pluralize(n.name)}'
        : n.name;
    final pos = OpenetraLocalizer.relativePosition(n.relativePosition, locale);
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

  static String _indefiniteArticle(String word) {
    final trimmed = word.trim().toLowerCase();
    if (trimmed.isEmpty) return 'a';
    const vowels = {'a', 'e', 'i', 'o', 'u'};
    return vowels.contains(trimmed[0]) ? 'an' : 'a';
  }

  static String _naturalEntityLabel(SceneGraphNode n) {
    final cleanName = n.name.trim();
    if (n.instanceCount > 1) {
      return '${n.instanceCount} ${_pluralize(cleanName)}';
    }
    return '${_indefiniteArticle(cleanName)} $cleanName';
  }

  static String _joinNaturalList(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(", ")}, and ${items.last}';
  }

  static String _naturalZoneSentence(
    String zonePrefix,
    List<SceneGraphNode> nodes,
  ) {
    final labels = nodes.map(_naturalEntityLabel).toList();
    final isPlural = nodes.length > 1 || nodes.first.instanceCount > 1;
    final verb = isPlural ? 'are' : 'is';
    return '$zonePrefix $verb ${_joinNaturalList(labels)}.';
  }

  String _composeSpeech({
    required VisionObservation observation,
    required SceneGraph graph,
    required String locale,
  }) {
    final parts = <String>[];
    final isEnglish = OpenetraLocalizer.langCode(locale) == 'en';

    if (observation.imageQuality.isDegraded) {
      parts.add(
        OpenetraLocalizer.degradedNotice(
          observation.imageQuality.degradationReasons,
          locale,
        ),
      );
    }

    if (!isEnglish) {
      parts.add(
        OpenetraLocalizer.composeNaturalIndicScene(
          graph: graph,
          locale: locale,
        ),
      );
      return parts.where((p) => p.trim().isNotEmpty).join(' ');
    }

    // Human-natural English scene narration grouped by spatial zones.
    final env = graph.environmentCategory.trim();
    if (env.isNotEmpty && env.toLowerCase() != 'unclassified area') {
      final details = <String>[];
      if (graph.lighting != null && graph.lighting!.trim().isNotEmpty) {
        details.add('with ${graph.lighting!.trim()} lighting');
      }
      if (graph.surface != null && graph.surface!.trim().isNotEmpty) {
        details.add('on a ${graph.surface!.trim()} surface');
      }
      final suffix = details.isEmpty ? '' : ', ${details.join(" ")}';
      parts.add(
        'You appear to be in ${_indefiniteArticle(env)} $env$suffix.',
      );
    }

    final confidentNodes =
        graph.nodes.where((n) => !n.isUncertain).take(5).toList();
    if (confidentNodes.isNotEmpty) {
      final ahead = <SceneGraphNode>[];
      final left = <SceneGraphNode>[];
      final right = <SceneGraphNode>[];
      final overhead = <SceneGraphNode>[];

      for (final node in confidentNodes) {
        if (node.relativePosition.vertical == VerticalZone.overhead) {
          overhead.add(node);
        } else {
          switch (node.relativePosition.horizontal) {
            case HorizontalZone.center:
              ahead.add(node);
            case HorizontalZone.left:
            case HorizontalZone.farLeft:
              left.add(node);
            case HorizontalZone.right:
            case HorizontalZone.farRight:
              right.add(node);
          }
        }
      }

      if (ahead.isNotEmpty) {
        parts.add(_naturalZoneSentence('Directly ahead of you', ahead));
      }
      if (left.isNotEmpty) {
        parts.add(_naturalZoneSentence('To your left, there', left));
      }
      if (right.isNotEmpty) {
        parts.add(_naturalZoneSentence('On your right, there', right));
      }
      if (overhead.isNotEmpty) {
        parts.add(_naturalZoneSentence('Overhead, there', overhead));
      }
    } else if (graph.nodes.isEmpty) {
      parts.add(
        'Nothing distinct stands out clearly in this frame. Try panning the camera slowly.',
      );
    }

    if (graph.relationships.isNotEmpty) {
      final rel = graph.relationships.first;
      final pred = rel.predicate.replaceAll('_', ' ').trim();
      final subj =
          '${_indefiniteArticle(rel.subjectName)} ${rel.subjectName}';
      parts.add(
        '${subj[0].toUpperCase()}${subj.substring(1)} is $pred the ${rel.objectName}.',
      );
    }

    if (graph.events.isNotEmpty) {
      final ev = graph.events.first;
      final actor = '${_indefiniteArticle(ev.actorName)} ${ev.actorName}';
      parts.add(
        '${actor[0].toUpperCase()}${actor.substring(1)} appears to be ${ev.action}.',
      );
    }

    if (graph.readableTexts.isNotEmpty) {
      parts.add(
        'Visible text reads: ${_joinNaturalList(graph.readableTexts.take(3).toList())}.',
      );
    }

    if (graph.changes.isNotEmpty) {
      final appeared = graph.changes
          .where((c) => c.type == SceneChangeType.appeared)
          .take(2)
          .map((c) => c.summary)
          .toList();
      if (appeared.isNotEmpty) {
        parts.add('Newly in view: ${appeared.join("; ")}.');
      }
    }

    final uncertain =
        graph.uncertainNodes.take(2).map((n) => '${_indefiniteArticle(n.name)} ${n.name}').toList();
    if (uncertain.isNotEmpty) {
      parts.add(
        'Less certain, there may also be ${_joinNaturalList(uncertain)}.',
      );
    }

    return parts.join(' ');
  }
}

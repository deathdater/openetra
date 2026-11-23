import '../../../core/domain/entities/entities.dart';

/// Maintains a rolling in-memory window of recent SceneGraphs (without pixels)
/// to answer offline follow-up questions accurately and avoid hallucination when stale.
class ContextualQueryResolver {
  ContextualQueryResolver({
    this.maxSnapshots = 5,
    this.maxFreshness = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxSnapshots;
  final Duration maxFreshness;
  final DateTime Function() _clock;
  final List<SceneGraph> _history = [];

  List<SceneGraph> get history => List.unmodifiable(_history);

  void recordGraph(SceneGraph graph) {
    _history.insert(0, graph);
    if (_history.length > maxSnapshots) {
      _history.removeLast();
    }
  }

  void clear() => _history.clear();

  String answerFollowUp(String query, {SceneGraph? fallbackGraph}) {
    final graph = _history.isNotEmpty ? _history.first : fallbackGraph;
    if (graph == null) {
      return 'No scene has been captured yet. Tap or say Describe Surroundings first.';
    }

    final age = _clock().difference(graph.provenance.timestamp);
    if (age > maxFreshness) {
      return 'The last scene capture is ${age.inSeconds} seconds old and may be outdated. Capture a fresh surroundings view for current details.';
    }

    final q = query.trim().toLowerCase();

    if (q.contains('left') || q.contains('बायें') || q.contains('ಎಡ')) {
      final matches = graph.nodes.where((n) =>
          n.relativePosition.horizontal == HorizontalZone.left ||
          n.relativePosition.horizontal == HorizontalZone.farLeft);
      return _describeZoneMatches('on the left', matches);
    }

    if (q.contains('right') || q.contains('दायें') || q.contains('ಬಲ')) {
      final matches = graph.nodes.where((n) =>
          n.relativePosition.horizontal == HorizontalZone.right ||
          n.relativePosition.horizontal == HorizontalZone.farRight);
      return _describeZoneMatches('on the right', matches);
    }

    if (q.contains('center') || q.contains('front') || q.contains('ahead')) {
      final matches = graph.nodes.where((n) =>
          n.relativePosition.horizontal == HorizontalZone.center);
      return _describeZoneMatches('in the center ahead', matches);
    }

    if (q.contains('overhead') || q.contains('above') || q.contains('ceiling')) {
      return _describeZoneMatches('overhead', graph.overheadNodes);
    }

    if (q.contains('ground') || q.contains('floor')) {
      return _describeZoneMatches('at ground level', graph.groundLevelNodes);
    }

    if (q.contains('text') ||
        q.contains('written') ||
        q.contains('read') ||
        q.contains('what does') ||
        q.contains('sign say')) {
      if (graph.readableTexts.isEmpty) {
        return 'No readable Latin text was spotted in the last frame.';
      }
      return 'Visible text from the last frame: ${graph.readableTexts.join(", ")}.';
    }

    if (q.contains('change') || q.contains('moved')) {
      if (graph.changes.isEmpty) {
        return 'No significant changes detected compared to the previous capture.';
      }
      return graph.changes.take(4).map((c) => c.summary).join('. ');
    }

    if (q.contains('where') || q.contains('lighting') || q.contains('surface')) {
      final surfaceNote =
          graph.surface != null ? ' Surface appears ${graph.surface}.' : '';
      final lightNote =
          graph.lighting != null ? ' Lighting is ${graph.lighting}.' : '';
      return 'Environment appears to be ${graph.environmentCategory}.$surfaceNote$lightNote';
    }

    // Specific noun check, e.g. "any chairs?" or "is there a door?"
    final stopWords = <String>{
      'is',
      'are',
      'there',
      'any',
      'a',
      'an',
      'the',
      'what',
      'where',
      'can',
      'you',
      'see',
      'do',
    };
    final tokens = q
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toList();

    for (final token in tokens) {
      final needle = token.endsWith('s') && token.length > 3
          ? token.substring(0, token.length - 1)
          : token;
      final hits = graph.nodes.where(
        (n) => n.name.toLowerCase().contains(needle),
      );
      if (hits.isNotEmpty) {
        final summary = hits
            .map((h) =>
                '${h.isUncertain ? "possibly " : ""}${h.instanceCount > 1 ? "${h.instanceCount} " : ""}${h.name} in the ${h.relativePosition.toSpokenPhrase()}')
            .join(', ');
        return 'Yes: $summary.';
      }
    }

    if (tokens.isNotEmpty) {
      return 'I did not spot ${tokens.join(" ")} in the last scene capture.';
    }

    return 'You are in a ${graph.environmentCategory} with ${graph.nodes.length} grouped objects observed.';
  }

  static String _describeZoneMatches(
    String zoneLabel,
    Iterable<SceneGraphNode> matches,
  ) {
    final list = matches.toList();
    if (list.isEmpty) {
      return 'Nothing distinct stood out $zoneLabel in the last capture.';
    }
    final items = list.take(4).map((n) {
      final count = n.instanceCount > 1 ? '${n.instanceCount} ' : '';
      final prefix = n.isUncertain ? 'possibly ' : '';
      return '$prefix$count${n.name}';
    }).join(', ');
    return 'Observed $zoneLabel: $items.';
  }
}

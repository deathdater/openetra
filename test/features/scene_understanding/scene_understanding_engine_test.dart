import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/mirage/mirage_response_parser.dart';
import 'package:openetra/features/scene_understanding/domain/contextual_query_resolver.dart';
import 'package:openetra/features/scene_understanding/domain/scene_understanding_engine.dart';

void main() {
  const parser = MirageResponseParser();
  const engine = SceneUnderstandingEngine();

  test('deduplicates repeated entity detections and filters low-confidence hallucinated relations', () {
    final json = File('test/fixtures/mirage/probe_139.json').readAsStringSync();
    final obs = parser.parse(
      rawJson: json,
      inputWidth: 640,
      inputHeight: 426,
      processingDurationMs: 220,
      imageQuality: ImageQualityMetrics.nominal,
    );

    final desc = engine.build(obs);
    final chairNode = desc.sceneGraph.nodes.firstWhere((n) => n.name == 'chair');

    expect(chairNode.instanceCount, 11);
    expect(desc.sceneGraph.nodes.where((n) => n.name == 'chair').length, 1);
    expect(desc.spokenSummary.contains('11 chairs'), isTrue);
    expect(
      'chair'.allMatches(desc.spokenSummary.toLowerCase()).length,
      lessThanOrEqualTo(2),
    );
    // rug (score 0.327 < 0.48) relation onto dining table must be suppressed.
    expect(
      desc.sceneGraph.relationships.any((r) => r.subjectName == 'rug'),
      isFalse,
    );
    // vase (0.521) on dining table (0.598) is retained.
    expect(
      desc.sceneGraph.relationships.any((r) => r.subjectName == 'vase'),
      isTrue,
    );
    // Never fabricates metric distance units.
    expect(RegExp(r'\b\d+\s*(meters?|feet|cm)\b').hasMatch(desc.spokenSummary), isFalse);
  });

  test('computes temporal changes and answers offline follow-up questions cleanly', () {
    final now = DateTime(2026, 11, 23, 10, 0, 0);
    final json231049 = File('test/fixtures/mirage/probe_full_231049.json').readAsStringSync();
    final json139 = File('test/fixtures/mirage/probe_139.json').readAsStringSync();

    final obs1 = parser.parse(
      rawJson: json139,
      inputWidth: 640,
      inputHeight: 426,
      processingDurationMs: 200,
      imageQuality: ImageQualityMetrics.nominal,
      timestamp: now,
    );
    final obs2 = parser.parse(
      rawJson: json231049,
      inputWidth: 427,
      inputHeight: 640,
      processingDurationMs: 160,
      imageQuality: ImageQualityMetrics.nominal,
      timestamp: now,
    );

    final desc1 = engine.build(obs1);
    final desc2 = engine.build(obs2, previousGraph: desc1.sceneGraph);
    expect(desc2.sceneGraph.changes.any((c) => c.type == SceneChangeType.appeared), isTrue);
    expect(desc2.sceneGraph.changes.any((c) => c.type == SceneChangeType.disappeared), isTrue);

    DateTime currentClock = now;
    final resolver = ContextualQueryResolver(
      clock: () => currentClock,
      maxFreshness: const Duration(seconds: 15),
    );
    resolver.recordGraph(desc2.sceneGraph);

    expect(resolver.answerFollowUp('what text did you see?'), contains('ARRET'));
    expect(resolver.answerFollowUp('what is on the left?'), contains('car'));
    expect(resolver.answerFollowUp('is there a stop sign?'), contains('Yes: stop sign'));

    currentClock = now.add(const Duration(seconds: 25));
    expect(resolver.answerFollowUp('what is on the left?'), contains('outdated'));
  });
}

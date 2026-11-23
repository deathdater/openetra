import 'package:equatable/equatable.dart';
import 'provenance_and_quality.dart';
import 'scene_graph.dart';

class SceneSummaryMetadata extends Equatable {
  const SceneSummaryMetadata({
    required this.hasUncertainElements,
    required this.isDegraded,
    required this.totalNodes,
    this.degradationNote,
  });

  final bool hasUncertainElements;
  final bool isDegraded;
  final int totalNodes;
  final String? degradationNote;

  @override
  List<Object?> get props => [
        hasUncertainElements,
        isDegraded,
        totalNodes,
        degradationNote,
      ];
}

/// Concise, accessibility-ready natural language scene summary paired with its graph.
class SceneDescription extends Equatable {
  const SceneDescription({
    required this.provenance,
    required this.sceneGraph,
    required this.spokenSummary,
    required this.keyPoints,
    required this.metadata,
  });

  final ObservationProvenance provenance;
  final SceneGraph sceneGraph;
  final String spokenSummary;
  final List<String> keyPoints;
  final SceneSummaryMetadata metadata;

  @override
  List<Object?> get props => [
        provenance,
        sceneGraph,
        spokenSummary,
        keyPoints,
        metadata,
      ];
}

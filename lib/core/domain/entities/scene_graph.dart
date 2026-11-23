import 'package:equatable/equatable.dart';
import 'object_detection.dart';
import 'provenance_and_quality.dart';
import 'spatial_relationship.dart';

enum HorizontalZone { farLeft, left, center, right, farRight }

enum VerticalZone { overhead, middle, groundLevel }

/// Deterministic image-relative spatial zone derived from bounding box coordinates.
class RelativePosition extends Equatable {
  const RelativePosition({
    required this.horizontal,
    required this.vertical,
  });

  final HorizontalZone horizontal;
  final VerticalZone vertical;

  String toSpokenPhrase() {
    final h = switch (horizontal) {
      HorizontalZone.farLeft => 'far left',
      HorizontalZone.left => 'left',
      HorizontalZone.center => 'center',
      HorizontalZone.right => 'right',
      HorizontalZone.farRight => 'far right',
    };
    final v = switch (vertical) {
      VerticalZone.overhead => 'upper view',
      VerticalZone.middle => '',
      VerticalZone.groundLevel => 'foreground',
    };
    return v.isEmpty ? h : '$h ($v)';
  }

  @override
  List<Object?> get props => [horizontal, vertical];
}

/// Deduplicated entity node inside a structured SceneGraph.
class SceneGraphNode extends Equatable {
  const SceneGraphNode({
    required this.entityId,
    required this.name,
    required this.instanceCount,
    required this.primaryBox,
    required this.relativePosition,
    required this.confidence,
    required this.sourceModelId,
    required this.isUncertain,
    this.attributes = const [],
  });

  final int entityId;
  final String name;
  final int instanceCount;
  final BoundingBox primaryBox;
  final RelativePosition relativePosition;
  final double confidence;
  final String sourceModelId;
  final bool isUncertain;
  final List<ObjectAttribute> attributes;

  @override
  List<Object?> get props => [
        entityId,
        name,
        instanceCount,
        primaryBox,
        relativePosition,
        confidence,
        sourceModelId,
        isUncertain,
        attributes,
      ];
}

enum SceneChangeType { appeared, disappeared, shifted }

class SceneChange extends Equatable {
  const SceneChange({
    required this.type,
    required this.objectName,
    required this.summary,
  });

  final SceneChangeType type;
  final String objectName;
  final String summary;

  @override
  List<Object?> get props => [type, objectName, summary];
}

/// Structured representation of the user's immediate visual surroundings.
class SceneGraph extends Equatable {
  const SceneGraph({
    required this.provenance,
    required this.environmentCategory,
    required this.nodes,
    required this.relationships,
    required this.events,
    required this.groundLevelNodes,
    required this.overheadNodes,
    required this.uncertainNodes,
    required this.changes,
    required this.readableTexts,
    this.surface,
    this.lighting,
  });

  final ObservationProvenance provenance;
  final String environmentCategory;
  final List<SceneGraphNode> nodes;
  final List<SpatialRelationship> relationships;
  final List<VisualEvent> events;
  final List<SceneGraphNode> groundLevelNodes;
  final List<SceneGraphNode> overheadNodes;
  final List<SceneGraphNode> uncertainNodes;
  final List<SceneChange> changes;
  final List<String> readableTexts;
  final String? surface;
  final String? lighting;

  @override
  List<Object?> get props => [
        provenance,
        environmentCategory,
        nodes,
        relationships,
        events,
        groundLevelNodes,
        overheadNodes,
        uncertainNodes,
        changes,
        readableTexts,
        surface,
        lighting,
      ];
}

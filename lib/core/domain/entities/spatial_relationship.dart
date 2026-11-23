import 'package:equatable/equatable.dart';

/// Spatial or semantic relationship between two scene entities.
class SpatialRelationship extends Equatable {
  const SpatialRelationship({
    required this.subjectEntityId,
    required this.subjectName,
    required this.predicate,
    required this.objectEntityId,
    required this.objectName,
    required this.confidence,
    required this.source,
  });

  final int subjectEntityId;
  final String subjectName;
  final String predicate;
  final int objectEntityId;
  final String objectName;
  final double confidence;
  final String source;

  @override
  List<Object?> get props => [
        subjectEntityId,
        subjectName,
        predicate,
        objectEntityId,
        objectName,
        confidence,
        source,
      ];
}

/// Action or visual event observed in the frame.
class VisualEvent extends Equatable {
  const VisualEvent({
    required this.actorEntityId,
    required this.actorName,
    required this.action,
  });

  final int actorEntityId;
  final String actorName;
  final String action;

  @override
  List<Object?> get props => [actorEntityId, actorName, action];
}

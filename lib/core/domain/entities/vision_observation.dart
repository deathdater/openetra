import 'package:equatable/equatable.dart';
import 'object_detection.dart';
import 'provenance_and_quality.dart';
import 'spatial_relationship.dart';

/// Raw visual text span returned inside perception.
class PerceivedTextSpan extends Equatable {
  const PerceivedTextSpan({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });

  final String text;
  final BoundingBox boundingBox;
  final double confidence;

  @override
  List<Object?> get props => [text, boundingBox, confidence];
}

/// Structured perception record emitted by Mirage or another vision provider.
class VisionObservation extends Equatable {
  const VisionObservation({
    required this.provenance,
    required this.imageQuality,
    this.sceneMetadata = const {},
    this.objects = const [],
    this.textSpans = const [],
    this.relationships = const [],
    this.events = const [],
    this.formResult = const {},
    this.rawReasoningTrace,
  });

  final ObservationProvenance provenance;
  final ImageQualityMetrics imageQuality;
  final Map<String, String> sceneMetadata;
  final List<ObjectDetection> objects;
  final List<PerceivedTextSpan> textSpans;
  final List<SpatialRelationship> relationships;
  final List<VisualEvent> events;
  final Map<String, dynamic> formResult;
  final String? rawReasoningTrace;

  String? get setting => sceneMetadata['setting'];
  String? get lighting => sceneMetadata['lighting'];
  String? get surface => sceneMetadata['surface'];

  @override
  List<Object?> get props => [
        provenance,
        imageQuality,
        sceneMetadata,
        objects,
        textSpans,
        relationships,
        events,
        formResult,
        rawReasoningTrace,
      ];
}

import 'package:equatable/equatable.dart';
import 'object_detection.dart';
import 'provenance_and_quality.dart';

enum DetectedScript {
  latin,
  devanagari,
  kannada,
  tamil,
  telugu,
  malayalam,
  bengali,
  mixed,
  unknown,
}

class TextLineObservation extends Equatable {
  const TextLineObservation({
    required this.text,
    required this.boundingBox,
    required this.confidence,
    required this.script,
  });

  final String text;
  final BoundingBox boundingBox;
  final double confidence;
  final DetectedScript script;

  @override
  List<Object?> get props => [text, boundingBox, confidence, script];
}

/// Unified OCR output reconstructed in reading order.
class TextRecognitionResult extends Equatable {
  const TextRecognitionResult({
    required this.provenance,
    required this.detectedScript,
    required this.orderedLines,
    required this.fullText,
    required this.targetLocale,
    required this.engineUsed,
    this.packAvailable = true,
    this.missingPackNotice,
  });

  final ObservationProvenance provenance;
  final DetectedScript detectedScript;
  final List<TextLineObservation> orderedLines;
  final String fullText;
  final String targetLocale;
  final String engineUsed;
  final bool packAvailable;
  final String? missingPackNotice;

  bool get isEmpty => orderedLines.isEmpty || fullText.trim().isEmpty;

  @override
  List<Object?> get props => [
        provenance,
        detectedScript,
        orderedLines,
        fullText,
        targetLocale,
        engineUsed,
        packAvailable,
        missingPackNotice,
      ];
}

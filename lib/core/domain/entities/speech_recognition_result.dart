import 'package:equatable/equatable.dart';
import 'provenance_and_quality.dart';

enum VoiceIntentType {
  describeSurroundings,
  lookForHazards,
  readText,
  identifyCurrency,
  findObject,
  followUpQuery,
  repeatLast,
  stopSpeaking,
  switchMode,
  switchLanguage,
  openSettings,
  unknown,
}

class VoiceIntent extends Equatable {
  const VoiceIntent({
    required this.type,
    required this.rawTranscript,
    this.targetArgument,
    this.confidence = 1.0,
  });

  final VoiceIntentType type;
  final String rawTranscript;
  final String? targetArgument;
  final double confidence;

  @override
  List<Object?> get props => [type, rawTranscript, targetArgument, confidence];
}

/// Speech recognition result from an offline ASR engine or local command decoder.
class SpeechRecognitionResult extends Equatable {
  const SpeechRecognitionResult({
    required this.provenance,
    required this.transcript,
    required this.locale,
    required this.intent,
    required this.isOfflineEngine,
  });

  final ObservationProvenance provenance;
  final String transcript;
  final String locale;
  final VoiceIntent intent;
  final bool isOfflineEngine;

  @override
  List<Object?> get props => [
        provenance,
        transcript,
        locale,
        intent,
        isOfflineEngine,
      ];
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';

abstract class SmartReaderEvent extends Equatable {
  const SmartReaderEvent();

  @override
  List<Object?> get props => [];
}

class ReadObservedText extends SmartReaderEvent {
  const ReadObservedText({
    required this.observation,
    required this.targetLocale,
    this.frame,
  });

  final VisionObservation observation;
  final String targetLocale;
  final CapturedFrame? frame;

  @override
  List<Object?> get props => [observation, targetLocale, frame];
}

class SmartReaderState extends Equatable {
  const SmartReaderState({
    this.latestResult,
    this.isReading = false,
  });

  final TextRecognitionResult? latestResult;
  final bool isReading;

  @override
  List<Object?> get props => [latestResult, isReading];
}

/// Phase 1 baseline BLoC; OcrRouter & ReadingOrderReconstructor attach in Phase 4.
class SmartReaderBloc extends Bloc<SmartReaderEvent, SmartReaderState> {
  SmartReaderBloc({
    Future<TextRecognitionResult> Function(
      VisionObservation,
      String,
      CapturedFrame?,
    )? reader,
  })  : _reader = reader,
        super(const SmartReaderState()) {
    on<ReadObservedText>(_onRead);
  }

  Future<TextRecognitionResult> Function(
    VisionObservation,
    String,
    CapturedFrame?,
  )? _reader;

  void attachRouter(
    Future<TextRecognitionResult> Function(
      VisionObservation,
      String,
      CapturedFrame?,
    ) reader,
  ) {
    _reader = reader;
  }

  Future<void> _onRead(
    ReadObservedText event,
    Emitter<SmartReaderState> emit,
  ) async {
    emit(SmartReaderState(latestResult: state.latestResult, isReading: true));
    if (_reader != null) {
      final result = await _reader!(
        event.observation,
        event.targetLocale,
        event.frame,
      );
      emit(SmartReaderState(latestResult: result, isReading: false));
      return;
    }
    final lines = event.observation.textSpans
        .map((s) => TextLineObservation(
              text: s.text,
              boundingBox: s.boundingBox,
              confidence: s.confidence,
              script: DetectedScript.latin,
            ))
        .toList();
    emit(SmartReaderState(
      isReading: false,
      latestResult: TextRecognitionResult(
        provenance: event.observation.provenance,
        detectedScript: DetectedScript.latin,
        orderedLines: lines,
        fullText: lines.map((l) => l.text).join(' '),
        targetLocale: event.targetLocale,
        engineUsed: event.observation.provenance.modelId,
      ),
    ));
  }
}

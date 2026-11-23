import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/audio/voice_intent_router.dart';
import '../../../core/domain/entities/entities.dart';

abstract class VoiceAssistantEvent extends Equatable {
  const VoiceAssistantEvent();

  @override
  List<Object?> get props => [];
}

class SubmitVoiceTranscript extends VoiceAssistantEvent {
  const SubmitVoiceTranscript(this.transcript);
  final String transcript;

  @override
  List<Object?> get props => [transcript];
}

class AssistantResponseDelivered extends VoiceAssistantEvent {
  const AssistantResponseDelivered(this.response);
  final AssistantResponse response;

  @override
  List<Object?> get props => [response];
}

class VoiceAssistantState extends Equatable {
  const VoiceAssistantState({
    this.lastIntent,
    this.lastResponse,
    this.history = const [],
  });

  final VoiceIntent? lastIntent;
  final AssistantResponse? lastResponse;
  final List<AssistantResponse> history;

  @override
  List<Object?> get props => [lastIntent, lastResponse, history];
}

class VoiceAssistantBloc
    extends Bloc<VoiceAssistantEvent, VoiceAssistantState> {
  VoiceAssistantBloc({VoiceIntentRouter? intentRouter})
      : _intentRouter = intentRouter ?? const VoiceIntentRouter(),
        super(const VoiceAssistantState()) {
    on<SubmitVoiceTranscript>(_onTranscript);
    on<AssistantResponseDelivered>(_onDelivered);
  }

  final VoiceIntentRouter _intentRouter;

  void _onTranscript(
    SubmitVoiceTranscript event,
    Emitter<VoiceAssistantState> emit,
  ) {
    final intent = _intentRouter.parse(event.transcript);
    emit(VoiceAssistantState(
      lastIntent: intent,
      lastResponse: state.lastResponse,
      history: state.history,
    ));
  }

  void _onDelivered(
    AssistantResponseDelivered event,
    Emitter<VoiceAssistantState> emit,
  ) {
    emit(VoiceAssistantState(
      lastIntent: state.lastIntent,
      lastResponse: event.response,
      history: [event.response, ...state.history].take(20).toList(),
    ));
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../accessibility/accessibility_announcer.dart';
import '../../domain/entities/entities.dart';
import '../speech_controller.dart';

abstract class AudioEvent extends Equatable {
  const AudioEvent();

  @override
  List<Object?> get props => [];
}

class SpeakAssistantResponse extends AudioEvent {
  const SpeakAssistantResponse(this.response);
  final AssistantResponse response;

  @override
  List<Object?> get props => [response];
}

class InterruptSpeechRequested extends AudioEvent {
  const InterruptSpeechRequested();
}

class RepeatSpeechRequested extends AudioEvent {
  const RepeatSpeechRequested();
}

class UpdateSpeechConfig extends AudioEvent {
  const UpdateSpeechConfig({this.locale, this.speechRate});
  final String? locale;
  final double? speechRate;

  @override
  List<Object?> get props => [locale, speechRate];
}

class AudioBlocState extends Equatable {
  const AudioBlocState({
    this.isSpeaking = false,
    this.locale = 'en-IN',
    this.speechRate = 0.52,
    this.lastSpokenText = '',
  });

  final bool isSpeaking;
  final String locale;
  final double speechRate;
  final String lastSpokenText;

  @override
  List<Object?> get props => [isSpeaking, locale, speechRate, lastSpokenText];
}

class AudioBloc extends Bloc<AudioEvent, AudioBlocState> {
  AudioBloc({
    required this.announcer,
    required this.speechController,
  }) : super(AudioBlocState(
          locale: speechController.currentLocale,
          speechRate: speechController.speechRate,
        )) {
    on<SpeakAssistantResponse>(_onSpeak);
    on<InterruptSpeechRequested>(_onInterrupt);
    on<RepeatSpeechRequested>(_onRepeat);
    on<UpdateSpeechConfig>(_onConfigure);
  }

  final AccessibilityAnnouncer announcer;
  final SpeechController speechController;

  Future<void> _onSpeak(
    SpeakAssistantResponse event,
    Emitter<AudioBlocState> emit,
  ) async {
    emit(AudioBlocState(
      isSpeaking: true,
      locale: event.response.locale,
      speechRate: speechController.speechRate,
      lastSpokenText: event.response.spokenText,
    ));
    await announcer.announce(event.response);
    emit(AudioBlocState(
      isSpeaking: false,
      locale: event.response.locale,
      speechRate: speechController.speechRate,
      lastSpokenText: event.response.spokenText,
    ));
  }

  Future<void> _onInterrupt(
    InterruptSpeechRequested event,
    Emitter<AudioBlocState> emit,
  ) async {
    await announcer.interrupt();
    emit(AudioBlocState(
      isSpeaking: false,
      locale: state.locale,
      speechRate: state.speechRate,
      lastSpokenText: state.lastSpokenText,
    ));
  }

  Future<void> _onRepeat(
    RepeatSpeechRequested event,
    Emitter<AudioBlocState> emit,
  ) async {
    await announcer.repeatLast();
  }

  Future<void> _onConfigure(
    UpdateSpeechConfig event,
    Emitter<AudioBlocState> emit,
  ) async {
    await speechController.configure(
      locale: event.locale,
      rate: event.speechRate,
    );
    emit(AudioBlocState(
      isSpeaking: state.isSpeaking,
      locale: speechController.currentLocale,
      speechRate: speechController.speechRate,
      lastSpokenText: state.lastSpokenText,
    ));
  }
}

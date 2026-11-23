import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/entities/entities.dart';

abstract class SceneUnderstandingEvent extends Equatable {
  const SceneUnderstandingEvent();

  @override
  List<Object?> get props => [];
}

class ProcessSceneObservation extends SceneUnderstandingEvent {
  const ProcessSceneObservation(this.observation);
  final VisionObservation observation;

  @override
  List<Object?> get props => [observation];
}

class AnswerSceneFollowUp extends SceneUnderstandingEvent {
  const AnswerSceneFollowUp(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class SceneUnderstandingState extends Equatable {
  const SceneUnderstandingState({
    this.latestDescription,
    this.followUpAnswer,
    this.isProcessing = false,
  });

  final SceneDescription? latestDescription;
  final String? followUpAnswer;
  final bool isProcessing;

  @override
  List<Object?> get props => [latestDescription, followUpAnswer, isProcessing];
}

/// Phase 1 baseline BLoC; full deterministic SceneUnderstandingEngine &
/// ContextualQueryResolver are injected in Phase 3 (v0.4.0).
class SceneUnderstandingBloc
    extends Bloc<SceneUnderstandingEvent, SceneUnderstandingState> {
  SceneUnderstandingBloc({
    SceneDescription Function(VisionObservation, SceneGraph?)? builder,
    String Function(String, SceneGraph?)? followUpResolver,
  })  : _builder = builder,
        _followUpResolver = followUpResolver,
        super(const SceneUnderstandingState()) {
    on<ProcessSceneObservation>(_onProcess);
    on<AnswerSceneFollowUp>(_onFollowUp);
  }

  SceneDescription Function(VisionObservation, SceneGraph?)? _builder;
  String Function(String, SceneGraph?)? _followUpResolver;

  void attachEngine({
    required SceneDescription Function(VisionObservation, SceneGraph?) builder,
    required String Function(String, SceneGraph?) followUpResolver,
  }) {
    _builder = builder;
    _followUpResolver = followUpResolver;
  }

  void _onProcess(
    ProcessSceneObservation event,
    Emitter<SceneUnderstandingState> emit,
  ) {
    final prevGraph = state.latestDescription?.sceneGraph;
    final built = _builder != null
        ? _builder!(event.observation, prevGraph)
        : _fallbackBuild(event.observation);
    emit(SceneUnderstandingState(latestDescription: built));
  }

  void _onFollowUp(
    AnswerSceneFollowUp event,
    Emitter<SceneUnderstandingState> emit,
  ) {
    final graph = state.latestDescription?.sceneGraph;
    final answer = _followUpResolver != null
        ? _followUpResolver!(event.query, graph)
        : (graph == null
            ? 'Please capture a surroundings description first.'
            : 'Current setting is ${graph.environmentCategory} with ${graph.nodes.length} grouped objects.');
    emit(SceneUnderstandingState(
      latestDescription: state.latestDescription,
      followUpAnswer: answer,
    ));
  }

  static SceneDescription _fallbackBuild(VisionObservation obs) {
    final setting = obs.setting ?? 'indoor or outdoor area';
    final names = obs.objects.map((o) => o.name).toSet().take(5).join(', ');
    final summary = names.isEmpty
        ? 'Scene looks like a $setting.'
        : 'Scene looks like a $setting with $names.';
    final graph = SceneGraph(
      provenance: obs.provenance,
      environmentCategory: setting,
      nodes: const [],
      relationships: obs.relationships,
      events: obs.events,
      groundLevelNodes: const [],
      overheadNodes: const [],
      uncertainNodes: const [],
      changes: const [],
      readableTexts: obs.textSpans.map((t) => t.text).toList(),
      surface: obs.surface,
      lighting: obs.lighting,
    );
    return SceneDescription(
      provenance: obs.provenance,
      sceneGraph: graph,
      spokenSummary: summary,
      keyPoints: [summary],
      metadata: SceneSummaryMetadata(
        hasUncertainElements: false,
        isDegraded: obs.imageQuality.isDegraded,
        totalNodes: obs.objects.length,
      ),
    );
  }
}

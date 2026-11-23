import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';
import '../../../core/inference/specialist/native_specialist_providers.dart';
import '../../../core/storage/openetra_database.dart';
import '../../scene_understanding/domain/registered_object_scene_matcher.dart';

abstract class ObjectMemoryEvent extends Equatable {
  const ObjectMemoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadPersonalObjects extends ObjectMemoryEvent {
  const LoadPersonalObjects();
}

class RegisterPersonalObject extends ObjectMemoryEvent {
  const RegisterPersonalObject({
    required this.name,
    this.category = 'personal',
    this.colorHint,
    this.description,
    this.sampleFrame,
    this.sampleCrop,
  });

  final String name;
  final String category;
  final String? colorHint;
  final String? description;
  final CapturedFrame? sampleFrame;
  final BoundingBox? sampleCrop;

  @override
  List<Object?> get props => [
        name,
        category,
        colorHint,
        description,
        sampleFrame,
        sampleCrop,
      ];
}

class RemovePersonalObject extends ObjectMemoryEvent {
  const RemovePersonalObject(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class FindPersonalObject extends ObjectMemoryEvent {
  const FindPersonalObject(
    this.objectName, {
    this.observation,
    this.frame,
  });
  final String objectName;
  final VisionObservation? observation;
  final CapturedFrame? frame;

  @override
  List<Object?> get props => [objectName, observation, frame];
}

class ObjectMemoryState extends Equatable {
  const ObjectMemoryState({
    this.profiles = const [],
    this.lastSearchResult,
    this.isSearching = false,
  });

  final List<PersonalObjectProfile> profiles;
  final String? lastSearchResult;
  final bool isSearching;

  @override
  List<Object?> get props => [profiles, lastSearchResult, isSearching];
}

class ObjectMemoryBloc extends Bloc<ObjectMemoryEvent, ObjectMemoryState> {
  ObjectMemoryBloc({
    required this.database,
    this.embeddingProvider,
  }) : super(const ObjectMemoryState()) {
    on<LoadPersonalObjects>(_onLoad);
    on<RegisterPersonalObject>(_onRegister);
    on<RemovePersonalObject>(_onRemove);
    on<FindPersonalObject>(_onFind);
  }

  final OpenetraDatabase database;
  final EmbeddingProvider? embeddingProvider;
  static const _uuid = Uuid();

  Future<void> _onLoad(
    LoadPersonalObjects event,
    Emitter<ObjectMemoryState> emit,
  ) async {
    final list = await database.listPersonalObjects();
    emit(ObjectMemoryState(
      profiles: list,
      lastSearchResult: state.lastSearchResult,
    ));
  }

  Future<void> _onRegister(
    RegisterPersonalObject event,
    Emitter<ObjectMemoryState> emit,
  ) async {
    final now = DateTime.now();
    final objId = _uuid.v4();
    await database.upsertPersonalObject(
      PersonalObjectProfile(
        id: objId,
        name: event.name.trim(),
        category: event.category,
        colorHint: event.colorHint,
        description: event.description,
        createdAt: now,
        updatedAt: now,
      ),
    );
    bool embedded = false;
    if (event.sampleFrame != null && embeddingProvider != null) {
      final vec = await embeddingProvider!.computeEmbedding(
        event.sampleFrame!,
        event.sampleCrop ?? const BoundingBox(x1: 0, y1: 0, x2: 1000, y2: 1000),
      );
      if (vec != null && vec.isNotEmpty) {
        await database.saveObjectEmbedding(
          id: _uuid.v4(),
          objectId: objId,
          modelId: embeddingProvider!.modelId,
          vector: Float32List.fromList(vec),
        );
        embedded = true;
      }
    }
    final list = await database.listPersonalObjects();
    emit(ObjectMemoryState(
      profiles: list,
      lastSearchResult: embedded
          ? 'Saved ${event.name.trim()} with visual appearance embedding offline.'
          : 'Saved ${event.name.trim()} to personal object memory.',
    ));
  }

  Future<void> _onRemove(
    RemovePersonalObject event,
    Emitter<ObjectMemoryState> emit,
  ) async {
    await database.deletePersonalObject(event.id);
    final list = await database.listPersonalObjects();
    emit(ObjectMemoryState(
      profiles: list,
      lastSearchResult: 'Removed item from personal object memory.',
    ));
  }

  Future<void> _onFind(
    FindPersonalObject event,
    Emitter<ObjectMemoryState> emit,
  ) async {
    final target = event.objectName.trim().toLowerCase();
    final obs = event.observation;
    final currentProfiles = state.profiles.isNotEmpty
        ? state.profiles
        : await database.listPersonalObjects();

    if (obs == null) {
      final profiles = currentProfiles.where(
        (p) => RegisteredObjectSceneMatcher.matchesObjectLabel(p.name, target),
      );
      final historyNote = profiles.isNotEmpty && profiles.first.lastSeenSetting != null
          ? ' Last seen in ${profiles.first.lastSeenSetting}.'
          : '';
      emit(ObjectMemoryState(
        profiles: currentProfiles,
        lastSearchResult: 'Capture a scene to search for $target.$historyNote',
      ));
      return;
    }

    final matchingProfile = currentProfiles.where(
      (p) => RegisteredObjectSceneMatcher.matchesObjectLabel(p.name, target),
    );
    List<List<double>> storedVecs = const [];
    if (matchingProfile.isNotEmpty) {
      storedVecs = await database.getObjectEmbeddings(matchingProfile.first.id);
    }

    // Require semantic label/synonym match first so unrelated objects in the
    // scene can never falsely match via HSV/edge histogram similarity.
    final matches = obs.objects
        .where((o) => RegisteredObjectSceneMatcher.matchesObjectLabel(target, o.name))
        .toList();

    if (matches.isEmpty) {
      emit(ObjectMemoryState(
        profiles: currentProfiles,
        lastSearchResult:
            'Could not find $target in the current camera view. Try panning slowly.',
      ));
      return;
    }

    // Score label-matched candidates with visual embedding similarity if available.
    ObjectDetection bestMatch = matches.first;
    double bestCosine = -1.0;
    if (event.frame != null &&
        embeddingProvider != null &&
        storedVecs.isNotEmpty) {
      for (final candidate in matches) {
        final candVec = await embeddingProvider!.computeEmbedding(
          event.frame!,
          candidate.boundingBox,
        );
        if (candVec == null) continue;
        for (final refVec in storedVecs) {
          final sim = cosineSimilarity(candVec, refVec);
          if (sim > bestCosine) {
            bestCosine = sim;
            bestMatch = candidate;
          }
        }
      }
    }

    String zone(BoundingBox b) {
      final cx = b.centerX;
      if (cx < 200) return 'far left';
      if (cx < 380) return 'left';
      if (cx <= 620) return 'center';
      if (cx <= 800) return 'right';
      return 'far right';
    }

    if (matches.length > 1 && bestCosine < 0.78) {
      final locations = matches.take(3).map((m) => zone(m.boundingBox)).join(', ');
      emit(ObjectMemoryState(
        profiles: currentProfiles,
        lastSearchResult:
            'I see ${matches.length} possible matches for $target at: $locations. Please confirm which one you want.',
      ));
      return;
    }

    if (storedVecs.isNotEmpty && bestCosine >= 0.0 && bestCosine < 0.72) {
      emit(ObjectMemoryState(
        profiles: currentProfiles,
        lastSearchResult:
            'Could not confirm your registered $target in the current camera view (visual appearance did not match). Try panning slowly.',
      ));
      return;
    }

    final pos = zone(bestMatch.boundingBox);
    if (matchingProfile.isNotEmpty) {
      await database.recordLastSeen(
        id: _uuid.v4(),
        objectId: matchingProfile.first.id,
        sceneSetting: obs.setting ?? 'current view',
        relativePosition: pos,
        confidence: bestMatch.confidence,
      );
    }

    final displayName = matchingProfile.isNotEmpty
        ? matchingProfile.first.name
        : bestMatch.name;
    final embedNote = bestCosine >= 0.76
        ? ', visual appearance similarity ${(bestCosine * 100).round()}%'
        : '';
    final list = await database.listPersonalObjects();
    emit(ObjectMemoryState(
      profiles: list,
      lastSearchResult:
          'Found $displayName in the $pos of the camera view (confidence ${(bestMatch.confidence * 100).round()}%$embedNote).',
    ));
  }
}

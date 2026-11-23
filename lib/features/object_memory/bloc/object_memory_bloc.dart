import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/storage/openetra_database.dart';

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
  });

  final String name;
  final String category;
  final String? colorHint;
  final String? description;

  @override
  List<Object?> get props => [name, category, colorHint, description];
}

class RemovePersonalObject extends ObjectMemoryEvent {
  const RemovePersonalObject(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class FindPersonalObject extends ObjectMemoryEvent {
  const FindPersonalObject(this.objectName, {this.observation});
  final String objectName;
  final VisionObservation? observation;

  @override
  List<Object?> get props => [objectName, observation];
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
  ObjectMemoryBloc({required this.database}) : super(const ObjectMemoryState()) {
    on<LoadPersonalObjects>(_onLoad);
    on<RegisterPersonalObject>(_onRegister);
    on<RemovePersonalObject>(_onRemove);
    on<FindPersonalObject>(_onFind);
  }

  final OpenetraDatabase database;
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
    await database.upsertPersonalObject(
      PersonalObjectProfile(
        id: _uuid.v4(),
        name: event.name.trim(),
        category: event.category,
        colorHint: event.colorHint,
        description: event.description,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final list = await database.listPersonalObjects();
    emit(ObjectMemoryState(
      profiles: list,
      lastSearchResult: 'Saved ${event.name.trim()} to personal object memory.',
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
    if (obs == null) {
      final profiles = state.profiles.where(
        (p) => p.name.toLowerCase().contains(target),
      );
      final historyNote = profiles.isNotEmpty && profiles.first.lastSeenSetting != null
          ? ' Last seen in ${profiles.first.lastSeenSetting}.'
          : '';
      emit(ObjectMemoryState(
        profiles: state.profiles,
        lastSearchResult: 'Capture a scene to search for $target.$historyNote',
      ));
      return;
    }

    final matches = obs.objects.where((o) {
      final n = o.name.toLowerCase();
      return n == target || n.contains(target) || target.contains(n);
    }).toList();

    if (matches.isEmpty) {
      emit(ObjectMemoryState(
        profiles: state.profiles,
        lastSearchResult:
            'Could not find $target in the current camera view. Try panning slowly.',
      ));
      return;
    }

    String zone(BoundingBox b) {
      final cx = b.centerX;
      if (cx < 200) return 'far left';
      if (cx < 380) return 'left';
      if (cx <= 620) return 'center';
      if (cx <= 800) return 'right';
      return 'far right';
    }

    if (matches.length > 1) {
      final locations = matches.take(3).map((m) => zone(m.boundingBox)).join(', ');
      emit(ObjectMemoryState(
        profiles: state.profiles,
        lastSearchResult:
            'I see ${matches.length} possible matches for $target at: $locations. Please confirm which one you want.',
      ));
      return;
    }

    final found = matches.first;
    final pos = zone(found.boundingBox);
    final matchingProfile = state.profiles.where(
      (p) => p.name.toLowerCase().contains(target),
    );
    if (matchingProfile.isNotEmpty) {
      await database.recordLastSeen(
        id: _uuid.v4(),
        objectId: matchingProfile.first.id,
        sceneSetting: obs.setting ?? 'current view',
        relativePosition: pos,
        confidence: found.confidence,
      );
    }

    final list = await database.listPersonalObjects();
    emit(ObjectMemoryState(
      profiles: list,
      lastSearchResult:
          'Found ${found.name} in the $pos of the camera view (confidence ${(found.confidence * 100).round()}%).',
    ));
  }
}

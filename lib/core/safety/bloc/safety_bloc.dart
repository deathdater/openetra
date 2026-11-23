import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/entities.dart';
import '../../storage/openetra_database.dart';

abstract class SafetyBlocEvent extends Equatable {
  const SafetyBlocEvent();

  @override
  List<Object?> get props => [];
}

class RecordSafetyEvent extends SafetyBlocEvent {
  const RecordSafetyEvent(this.event);
  final SafetyEvent event;

  @override
  List<Object?> get props => [event];
}

class LoadSafetyHistory extends SafetyBlocEvent {
  const LoadSafetyHistory();
}

class ClearSafetyDegradation extends SafetyBlocEvent {
  const ClearSafetyDegradation();
}

class SafetyBlocState extends Equatable {
  const SafetyBlocState({
    this.events = const [],
    this.isDegraded = false,
    this.activeDegradationMessage,
  });

  final List<SafetyEvent> events;
  final bool isDegraded;
  final String? activeDegradationMessage;

  @override
  List<Object?> get props => [events, isDegraded, activeDegradationMessage];
}

class SafetyBloc extends Bloc<SafetyBlocEvent, SafetyBlocState> {
  SafetyBloc({this.database}) : super(const SafetyBlocState()) {
    on<RecordSafetyEvent>(_onRecord);
    on<LoadSafetyHistory>(_onLoad);
    on<ClearSafetyDegradation>(_onClear);
  }

  final OpenetraDatabase? database;

  Future<void> _onRecord(
    RecordSafetyEvent event,
    Emitter<SafetyBlocState> emit,
  ) async {
    await database?.logSafetyEvent(event.event);
    final updated = [event.event, ...state.events].take(50).toList();
    final isDegraded = event.event.type == SafetyEventType.degradedQuality ||
        event.event.type == SafetyEventType.thermalThrottle ||
        event.event.type == SafetyEventType.modelIntegrityViolation;
    emit(SafetyBlocState(
      events: updated,
      isDegraded: isDegraded ? true : state.isDegraded,
      activeDegradationMessage:
          isDegraded ? event.event.message : state.activeDegradationMessage,
    ));
  }

  Future<void> _onLoad(
    LoadSafetyHistory event,
    Emitter<SafetyBlocState> emit,
  ) async {
    final rows = await database?.listSafetyEvents() ?? const <SafetyEvent>[];
    emit(SafetyBlocState(
      events: rows,
      isDegraded: state.isDegraded,
      activeDegradationMessage: state.activeDegradationMessage,
    ));
  }

  void _onClear(
    ClearSafetyDegradation event,
    Emitter<SafetyBlocState> emit,
  ) {
    emit(SafetyBlocState(events: state.events, isDegraded: false));
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/ai_model_registry.dart';
import '../../../core/inference/model_provider.dart';
import '../../../core/storage/openetra_database.dart';

abstract class ModelManagerEvent extends Equatable {
  const ModelManagerEvent();

  @override
  List<Object?> get props => [];
}

class RefreshModelRegistry extends ModelManagerEvent {
  const RefreshModelRegistry();
}

class VerifyAndLoadVisionModel extends ModelManagerEvent {
  const VerifyAndLoadVisionModel();
}

class ModelManagerState extends Equatable {
  const ModelManagerState({
    this.models = const [],
    this.benchmarks = const [],
    this.isWorking = false,
    this.statusMessage,
  });

  final List<ModelMetadata> models;
  final List<ModelPerformance> benchmarks;
  final bool isWorking;
  final String? statusMessage;

  @override
  List<Object?> get props => [models, benchmarks, isWorking, statusMessage];
}

class ModelManagerBloc extends Bloc<ModelManagerEvent, ModelManagerState> {
  ModelManagerBloc({
    required this.registry,
    required this.visionProvider,
    this.database,
  }) : super(ModelManagerState(models: registry.allModels)) {
    on<RefreshModelRegistry>(_onRefresh);
    on<VerifyAndLoadVisionModel>(_onVerifyAndLoad);
  }

  final AIModelRegistry registry;
  final VisionInferenceProvider visionProvider;
  final OpenetraDatabase? database;

  Future<void> _onRefresh(
    RefreshModelRegistry event,
    Emitter<ModelManagerState> emit,
  ) async {
    emit(ModelManagerState(
      models: registry.allModels,
      benchmarks: registry.recentBenchmarks,
      statusMessage: 'Model registry refreshed',
    ));
  }

  Future<void> _onVerifyAndLoad(
    VerifyAndLoadVisionModel event,
    Emitter<ModelManagerState> emit,
  ) async {
    emit(ModelManagerState(
      models: registry.allModels,
      benchmarks: registry.recentBenchmarks,
      isWorking: true,
      statusMessage: 'Verifying SHA-256 checksum and loading Mirage...',
    ));
    try {
      final perf = await visionProvider.load();
      registry.recordPerformance(perf);
      final current = registry.getById(visionProvider.modelId);
      if (current != null) {
        final updated = current.copyWith(status: ModelStatus.loadedInMemory);
        registry.updateModel(updated);
        await database?.upsertModelRecord(
          updated,
          actualSha256: updated.expectedSha256,
          verifiedAt: DateTime.now(),
        );
      }
      emit(ModelManagerState(
        models: registry.allModels,
        benchmarks: registry.recentBenchmarks,
        isWorking: false,
        statusMessage: 'Mirage verified and loaded in ${perf.coldLoadMs} ms.',
      ));
    } catch (e) {
      final current = registry.getById(visionProvider.modelId);
      if (current != null) {
        registry.updateModel(current.copyWith(status: ModelStatus.checksumFailed));
      }
      emit(ModelManagerState(
        models: registry.allModels,
        benchmarks: registry.recentBenchmarks,
        isWorking: false,
        statusMessage: 'Model verification failed: $e',
      ));
    }
  }
}

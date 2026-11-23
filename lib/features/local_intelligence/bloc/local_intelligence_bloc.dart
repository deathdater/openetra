import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/openetra_database.dart';
import '../domain/deterministic_summary_engine.dart';
import '../domain/local_intelligence_config.dart';
import '../domain/local_llm_engine.dart';
import '../domain/local_model_catalogue.dart';
import '../domain/operation_history_event.dart';
import '../domain/summary_orchestrator.dart';

abstract class LocalIntelligenceEvent extends Equatable {
  const LocalIntelligenceEvent();

  @override
  List<Object?> get props => [];
}

class LoadLocalIntelligence extends LocalIntelligenceEvent {
  const LoadLocalIntelligence();
}

class SetLocalIntelligenceEnabled extends LocalIntelligenceEvent {
  const SetLocalIntelligenceEnabled(this.enabled);
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class SetOperationHistoryEnabled extends LocalIntelligenceEvent {
  const SetOperationHistoryEnabled(this.enabled);
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class SetAiSummariesEnabled extends LocalIntelligenceEvent {
  const SetAiSummariesEnabled(this.enabled);
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class SetWifiOnlyDownload extends LocalIntelligenceEvent {
  const SetWifiOnlyDownload(this.wifiOnly);
  final bool wifiOnly;

  @override
  List<Object?> get props => [wifiOnly];
}

class SetHistoryRetentionDays extends LocalIntelligenceEvent {
  const SetHistoryRetentionDays(this.days);
  final int days;

  @override
  List<Object?> get props => [days];
}

class RefreshOperationHistory extends LocalIntelligenceEvent {
  const RefreshOperationHistory({
    this.filterType,
    this.filterStatus,
    this.searchQuery,
    this.clearFilters = false,
  });

  final OperationType? filterType;
  final OperationStatus? filterStatus;
  final String? searchQuery;
  final bool clearFilters;

  @override
  List<Object?> get props => [filterType, filterStatus, searchQuery, clearFilters];
}

class RequestActivitySummary extends LocalIntelligenceEvent {
  const RequestActivitySummary({
    required this.range,
    this.style = SummaryStyle.brief,
  });

  final HistoryTimeRange range;
  final SummaryStyle style;

  @override
  List<Object?> get props => [range, style];
}

class AskHistoricalQuestion extends LocalIntelligenceEvent {
  const AskHistoricalQuestion(this.question);
  final String question;

  @override
  List<Object?> get props => [question];
}

class DownloadAndInstallModel extends LocalIntelligenceEvent {
  const DownloadAndInstallModel({
    required this.modelId,
    this.authToken,
  });

  final String modelId;
  final String? authToken;

  @override
  List<Object?> get props => [modelId, authToken];
}

class CancelModelDownload extends LocalIntelligenceEvent {
  const CancelModelDownload();
}

class ActivateInstalledModel extends LocalIntelligenceEvent {
  const ActivateInstalledModel(this.modelId);
  final String modelId;

  @override
  List<Object?> get props => [modelId];
}

class _ModelDownloadProgressUpdated extends LocalIntelligenceEvent {
  const _ModelDownloadProgressUpdated(this.progress);
  final ModelDownloadProgress progress;

  @override
  List<Object?> get props => [
        progress.modelId,
        progress.downloadedBytes,
        progress.totalBytes,
        progress.progress,
        progress.status,
      ];
}

class VerifyAndActivateModel extends LocalIntelligenceEvent {
  const VerifyAndActivateModel({
    required this.modelId,
    required this.filePath,
    this.expectedSha256,
  });

  final String modelId;
  final String filePath;
  final String? expectedSha256;

  @override
  List<Object?> get props => [modelId, filePath, expectedSha256];
}

class DeleteDownloadedModel extends LocalIntelligenceEvent {
  const DeleteDownloadedModel(this.modelId);
  final String modelId;

  @override
  List<Object?> get props => [modelId];
}

class ClearOperationHistoryRequested extends LocalIntelligenceEvent {
  const ClearOperationHistoryRequested();
}

class ResetLocalIntelligenceRequested extends LocalIntelligenceEvent {
  const ResetLocalIntelligenceRequested();
}

class LocalIntelligenceState extends Equatable {
  const LocalIntelligenceState({
    this.config = const LocalIntelligenceConfig(),
    this.deviceProfile = DeviceHardwareProfile.unknown,
    this.history = const [],
    this.installedModelIds = const {},
    this.installedModelPaths = const {},
    this.downloadingModelId,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalDownloadBytes = 0,
    this.activeFilterType,
    this.activeFilterStatus,
    this.searchQuery = '',
    this.latestSummary,
    this.isBusy = false,
    this.statusMessage,
  });

  final LocalIntelligenceConfig config;
  final DeviceHardwareProfile deviceProfile;
  final List<OperationHistoryEvent> history;
  final Set<String> installedModelIds;
  final Map<String, String> installedModelPaths;
  final String? downloadingModelId;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalDownloadBytes;
  final OperationType? activeFilterType;
  final OperationStatus? activeFilterStatus;
  final String searchQuery;
  final ActivitySummaryResult? latestSummary;
  final bool isBusy;
  final String? statusMessage;

  LocalIntelligenceState copyWith({
    LocalIntelligenceConfig? config,
    DeviceHardwareProfile? deviceProfile,
    List<OperationHistoryEvent>? history,
    Set<String>? installedModelIds,
    Map<String, String>? installedModelPaths,
    String? downloadingModelId,
    bool clearDownloadingModel = false,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalDownloadBytes,
    OperationType? activeFilterType,
    bool clearFilterType = false,
    OperationStatus? activeFilterStatus,
    bool clearFilterStatus = false,
    String? searchQuery,
    ActivitySummaryResult? latestSummary,
    bool clearSummary = false,
    bool? isBusy,
    String? statusMessage,
    bool clearStatus = false,
  }) {
    return LocalIntelligenceState(
      config: config ?? this.config,
      deviceProfile: deviceProfile ?? this.deviceProfile,
      history: history ?? this.history,
      installedModelIds: installedModelIds ?? this.installedModelIds,
      installedModelPaths: installedModelPaths ?? this.installedModelPaths,
      downloadingModelId: clearDownloadingModel
          ? null
          : (downloadingModelId ?? this.downloadingModelId),
      downloadProgress: clearDownloadingModel
          ? 0.0
          : (downloadProgress ?? this.downloadProgress),
      downloadedBytes: clearDownloadingModel
          ? 0
          : (downloadedBytes ?? this.downloadedBytes),
      totalDownloadBytes: clearDownloadingModel
          ? 0
          : (totalDownloadBytes ?? this.totalDownloadBytes),
      activeFilterType:
          clearFilterType ? null : (activeFilterType ?? this.activeFilterType),
      activeFilterStatus: clearFilterStatus
          ? null
          : (activeFilterStatus ?? this.activeFilterStatus),
      searchQuery: searchQuery ?? this.searchQuery,
      latestSummary:
          clearSummary ? null : (latestSummary ?? this.latestSummary),
      isBusy: isBusy ?? this.isBusy,
      statusMessage:
          clearStatus ? null : (statusMessage ?? this.statusMessage),
    );
  }

  @override
  List<Object?> get props => [
        config,
        deviceProfile,
        history,
        installedModelIds,
        installedModelPaths,
        downloadingModelId,
        downloadProgress,
        downloadedBytes,
        totalDownloadBytes,
        activeFilterType,
        activeFilterStatus,
        searchQuery,
        latestSummary,
        isBusy,
        statusMessage,
      ];
}

class LocalIntelligenceBloc
    extends Bloc<LocalIntelligenceEvent, LocalIntelligenceState> {
  LocalIntelligenceBloc({
    required this.database,
    required this.llmEngine,
    required this.summaryOrchestrator,
  }) : super(const LocalIntelligenceState()) {
    on<LoadLocalIntelligence>(_onLoad);
    on<SetLocalIntelligenceEnabled>(_onSetEnabled);
    on<SetOperationHistoryEnabled>(_onSetHistoryEnabled);
    on<SetAiSummariesEnabled>(_onSetSummariesEnabled);
    on<SetWifiOnlyDownload>(_onSetWifiOnly);
    on<SetHistoryRetentionDays>(_onSetRetention);
    on<RefreshOperationHistory>(_onRefreshHistory);
    on<RequestActivitySummary>(_onRequestSummary);
    on<AskHistoricalQuestion>(_onAskQuestion);
    on<DownloadAndInstallModel>(_onDownloadAndInstallModel);
    on<CancelModelDownload>(_onCancelModelDownload);
    on<ActivateInstalledModel>(_onActivateInstalledModel);
    on<_ModelDownloadProgressUpdated>(_onDownloadProgressUpdated);
    on<VerifyAndActivateModel>(_onVerifyAndActivateModel);
    on<DeleteDownloadedModel>(_onDeleteModel);
    on<ClearOperationHistoryRequested>(_onClearHistory);
    on<ResetLocalIntelligenceRequested>(_onResetAll);
  }

  final OpenetraDatabase database;
  final LocalLlmEngine llmEngine;
  final SummaryOrchestrator summaryOrchestrator;
  StreamSubscription<ModelDownloadProgress>? _progressSub;

  @override
  Future<void> close() async {
    await _progressSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    LoadLocalIntelligence event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final cfg = await database.loadLocalIntelligenceConfig();
    final device = await llmEngine.probeDevice();
    await database.pruneExpiredOperationHistory();
    final rows = await database.queryOperationHistory(limit: 200);
    final models = await database.listInstalledLocalModels();
    final installedIds = <String>{};
    final installedPaths = <String, String>{};
    for (final m in models) {
      if (m['status'] == 'verified') {
        final id = m['model_id'].toString();
        installedIds.add(id);
        final path = m['local_path']?.toString() ?? '';
        if (path.isNotEmpty) {
          installedPaths[id] = path;
        }
      }
    }
    emit(state.copyWith(
      config: cfg,
      deviceProfile: device,
      history: rows,
      installedModelIds: installedIds,
      installedModelPaths: installedPaths,
    ));
  }

  Future<void> _onSetEnabled(
    SetLocalIntelligenceEnabled event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final next = state.config.copyWith(
      enabled: event.enabled,
      privacyNoticeAccepted:
          event.enabled ? true : state.config.privacyNoticeAccepted,
    );
    emit(state.copyWith(
      config: next,
      statusMessage: event.enabled
          ? 'Local Intelligence Beta enabled. Existing history and deterministic summaries are ready.'
          : 'Local Intelligence Beta disabled. On-device LLM unloaded. Existing history remains stored per your retention setting.',
    ));
    await database.saveLocalIntelligenceConfig(next);
    if (!event.enabled) {
      await llmEngine.unloadModel();
      summaryOrchestrator.resetSessionContext();
    }
  }

  Future<void> _onSetHistoryEnabled(
    SetOperationHistoryEnabled event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final next = state.config.copyWith(historyEnabled: event.enabled);
    emit(state.copyWith(
      config: next,
      statusMessage: event.enabled
          ? 'Operation history recording enabled.'
          : 'Operation history recording paused. Previously stored records are kept until you clear them.',
    ));
    await database.saveLocalIntelligenceConfig(next);
  }

  Future<void> _onSetSummariesEnabled(
    SetAiSummariesEnabled event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final next = state.config.copyWith(summariesEnabled: event.enabled);
    emit(state.copyWith(
      config: next,
      statusMessage: event.enabled
          ? 'On-device AI summaries enabled (uses deterministic fallback if no verified model is loaded).'
          : 'On-device AI summaries disabled. Deterministic structured summaries remain available.',
    ));
    await database.saveLocalIntelligenceConfig(next);
    if (!event.enabled) {
      await llmEngine.unloadModel();
    }
  }

  Future<void> _onSetWifiOnly(
    SetWifiOnlyDownload event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final next = state.config.copyWith(wifiOnlyDownload: event.wifiOnly);
    emit(state.copyWith(
      config: next,
      statusMessage: event.wifiOnly
          ? 'Model downloads restricted to Wi-Fi only.'
          : 'Model downloads allowed on Wi-Fi and mobile data.',
    ));
    await database.saveLocalIntelligenceConfig(next);
  }

  Future<void> _onSetRetention(
    SetHistoryRetentionDays event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final next = state.config.copyWith(retentionDays: event.days);
    emit(state.copyWith(
      config: next,
      statusMessage:
          'History retention updated to ${HistoryRetentionOptions.labelFor(event.days)}.',
    ));
    await database.saveLocalIntelligenceConfig(next);
  }

  Future<void> _onRefreshHistory(
    RefreshOperationHistory event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final type = event.clearFilters ? null : (event.filterType ?? state.activeFilterType);
    final status = event.clearFilters ? null : (event.filterStatus ?? state.activeFilterStatus);
    final search = event.clearFilters ? '' : (event.searchQuery ?? state.searchQuery);
    final rows = await database.queryOperationHistory(
      type: type,
      status: status,
      search: search,
      limit: 200,
    );
    emit(state.copyWith(
      history: rows,
      activeFilterType: type,
      clearFilterType: type == null,
      activeFilterStatus: status,
      clearFilterStatus: status == null,
      searchQuery: search,
    ));
  }

  Future<void> _onRequestSummary(
    RequestActivitySummary event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, statusMessage: 'Preparing activity summary...'));
    final res = await summaryOrchestrator.summarizeRange(
      config: state.config,
      range: event.range,
      style: event.style,
    );
    emit(state.copyWith(
      isBusy: false,
      latestSummary: res,
      statusMessage: res.spokenSummary,
    ));
  }

  Future<void> _onAskQuestion(
    AskHistoricalQuestion event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final q = event.question.trim();
    if (q.isEmpty) return;
    emit(state.copyWith(isBusy: true, statusMessage: 'Checking local activity history...'));
    final res = await summaryOrchestrator.askHistoricalQuestion(
      config: state.config,
      question: q,
    );
    emit(state.copyWith(
      isBusy: false,
      latestSummary: res,
      statusMessage: res.spokenSummary,
    ));
  }

  void _onDownloadProgressUpdated(
    _ModelDownloadProgressUpdated event,
    Emitter<LocalIntelligenceState> emit,
  ) {
    if (state.downloadingModelId != event.progress.modelId) return;
    emit(state.copyWith(
      downloadProgress: event.progress.progress,
      downloadedBytes: event.progress.downloadedBytes,
      totalDownloadBytes: event.progress.totalBytes,
    ));
  }

  Future<void> _onDownloadAndInstallModel(
    DownloadAndInstallModel event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    if (state.downloadingModelId != null) {
      emit(state.copyWith(
        statusMessage: 'A model download is already in progress.',
      ));
      return;
    }

    final spec = LocalModelCatalogue.byId(event.modelId);
    if (spec == null) {
      emit(state.copyWith(statusMessage: 'Unknown model ID: ${event.modelId}.'));
      return;
    }

    final compat = spec.evaluateDevice(state.deviceProfile);
    if (!compat.isCompatible) {
      emit(state.copyWith(
        statusMessage:
            '${spec.displayName} is not compatible with this device: ${compat.reasons.join(' ')}',
      ));
      return;
    }

    emit(state.copyWith(
      isBusy: true,
      downloadingModelId: spec.modelId,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalDownloadBytes: spec.packageSizeMb * 1024 * 1024,
      statusMessage: 'Downloading ${spec.displayName} (~${spec.packageSizeMb} MB)...',
    ));

    await _progressSub?.cancel();
    _progressSub = llmEngine.downloadProgressStream.listen(
      (progress) {
        if (!isClosed) {
          add(_ModelDownloadProgressUpdated(progress));
        }
      },
      onError: (_) {},
    );

    final ModelDownloadResult dl;
    try {
      dl = await llmEngine.downloadModel(
        spec: spec,
        wifiOnly: state.config.wifiOnlyDownload,
        authToken: event.authToken,
      );
    } finally {
      await _progressSub?.cancel();
      _progressSub = null;
    }

    if (!dl.success || dl.filePath == null || dl.filePath!.isEmpty) {
      emit(state.copyWith(
        isBusy: false,
        clearDownloadingModel: true,
        statusMessage: dl.cancelled
            ? 'Download of ${spec.displayName} cancelled.'
            : 'Download failed for ${spec.displayName}: ${dl.error ?? "Unknown error"}',
      ));
      return;
    }

    emit(state.copyWith(
      clearDownloadingModel: true,
      isBusy: true,
      statusMessage: 'Verifying SHA-256 integrity of ${spec.displayName}...',
    ));

    final ver = await llmEngine.verifyLocalModelFile(
      modelId: spec.modelId,
      filePath: dl.filePath!,
      expectedSha256: spec.expectedSha256,
    );
    if (!ver.verified) {
      await llmEngine.deleteModelFiles(spec.modelId);
      emit(state.copyWith(
        isBusy: false,
        statusMessage:
            'Checksum verification failed for ${spec.displayName}: ${ver.error ?? "Corrupted download"}. Removed partial file.',
      ));
      return;
    }

    await database.upsertInstalledLocalModel(
      modelId: spec.modelId,
      version: spec.version,
      localPath: dl.filePath!,
      sha256: ver.sha256 ?? '',
      sizeBytes: ver.sizeBytes,
      status: 'verified',
    );

    final nextIds = {...state.installedModelIds, spec.modelId};
    final nextPaths = {...state.installedModelPaths, spec.modelId: dl.filePath!};
    final refreshedDevice = await llmEngine.probeDevice();

    emit(state.copyWith(
      installedModelIds: nextIds,
      installedModelPaths: nextPaths,
      deviceProfile: refreshedDevice,
      statusMessage: 'Initializing ${spec.displayName} on-device...',
    ));

    await llmEngine.unloadModel();
    final loaded = await llmEngine.initializeModel(
      modelId: spec.modelId,
      filePath: dl.filePath!,
    );
    final smokeOk = loaded && await llmEngine.runSmokeTest();
    if (!smokeOk) {
      await llmEngine.unloadModel();
      emit(state.copyWith(
        isBusy: false,
        statusMessage:
            '${spec.displayName} downloaded and verified on disk, but could not initialize on this device. Deterministic summaries remain active.',
      ));
      return;
    }

    final nextCfg = state.config.copyWith(activeModelId: spec.modelId);
    await database.saveLocalIntelligenceConfig(nextCfg);

    emit(state.copyWith(
      isBusy: false,
      config: nextCfg,
      statusMessage: '${spec.displayName} downloaded, verified, and active offline.',
    ));
  }

  Future<void> _onCancelModelDownload(
    CancelModelDownload event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    await llmEngine.cancelDownload();
    emit(state.copyWith(
      isBusy: false,
      clearDownloadingModel: true,
      statusMessage: 'Model download cancelled.',
    ));
  }

  Future<void> _onActivateInstalledModel(
    ActivateInstalledModel event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final filePath = state.installedModelPaths[event.modelId];
    if (filePath == null || filePath.isEmpty) {
      emit(state.copyWith(
        statusMessage: 'Model file path not found for ${event.modelId}. Please re-download.',
      ));
      return;
    }
    final spec = LocalModelCatalogue.byId(event.modelId);
    add(VerifyAndActivateModel(
      modelId: event.modelId,
      filePath: filePath,
      expectedSha256: spec?.expectedSha256,
    ));
  }

  Future<void> _onVerifyAndActivateModel(
    VerifyAndActivateModel event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    final spec = LocalModelCatalogue.byId(event.modelId);
    if (spec == null) {
      emit(state.copyWith(statusMessage: 'Unknown model ID: ${event.modelId}.'));
      return;
    }
    final compat = spec.evaluateDevice(state.deviceProfile);
    if (!compat.isCompatible) {
      emit(state.copyWith(
        statusMessage:
            '${spec.displayName} is not compatible with this device: ${compat.reasons.join(' ')}',
      ));
      return;
    }

    emit(state.copyWith(
      isBusy: true,
      statusMessage: 'Verifying checksum and initializing ${spec.displayName}...',
    ));
    final ver = await llmEngine.verifyLocalModelFile(
      modelId: spec.modelId,
      filePath: event.filePath,
      expectedSha256: event.expectedSha256,
    );
    if (!ver.verified) {
      emit(state.copyWith(
        isBusy: false,
        statusMessage:
            'Verification failed for ${spec.displayName}: ${ver.error ?? "Invalid package"}. Deterministic summaries remain active.',
      ));
      return;
    }

    await llmEngine.unloadModel();
    final loaded = await llmEngine.initializeModel(
      modelId: spec.modelId,
      filePath: event.filePath,
    );
    final smokeOk = loaded && await llmEngine.runSmokeTest();
    if (!smokeOk) {
      await llmEngine.unloadModel();
      emit(state.copyWith(
        isBusy: false,
        statusMessage:
            '${spec.displayName} verified on disk, but runtime smoke test did not pass on this device. Deterministic summaries remain active.',
      ));
      return;
    }

    await database.upsertInstalledLocalModel(
      modelId: spec.modelId,
      version: spec.version,
      localPath: event.filePath,
      sha256: ver.sha256 ?? '',
      sizeBytes: ver.sizeBytes,
      status: 'verified',
    );
    final nextCfg = state.config.copyWith(activeModelId: spec.modelId);
    await database.saveLocalIntelligenceConfig(nextCfg);

    final nextIds = {...state.installedModelIds, spec.modelId};
    final nextPaths = {...state.installedModelPaths, spec.modelId: event.filePath};
    emit(state.copyWith(
      isBusy: false,
      config: nextCfg,
      installedModelIds: nextIds,
      installedModelPaths: nextPaths,
      statusMessage: '${spec.displayName} verified and active offline.',
    ));
  }

  Future<void> _onDeleteModel(
    DeleteDownloadedModel event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    await llmEngine.deleteModelFiles(event.modelId);
    await database.deleteInstalledLocalModel(event.modelId);
    final nextIds = Set<String>.from(state.installedModelIds)..remove(event.modelId);
    final nextPaths = Map<String, String>.from(state.installedModelPaths)..remove(event.modelId);
    final nextCfg = state.config.activeModelId == event.modelId
        ? state.config.copyWith(clearActiveModel: true)
        : state.config;
    await database.saveLocalIntelligenceConfig(nextCfg);
    final refreshedDevice = await llmEngine.probeDevice();
    emit(state.copyWith(
      config: nextCfg,
      deviceProfile: refreshedDevice,
      installedModelIds: nextIds,
      installedModelPaths: nextPaths,
      statusMessage:
          'Deleted model ${event.modelId}. Your local operation history remains intact.',
    ));
  }

  Future<void> _onClearHistory(
    ClearOperationHistoryRequested event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    await database.clearOperationHistory();
    summaryOrchestrator.resetSessionContext();
    emit(state.copyWith(
      history: const [],
      clearSummary: true,
      statusMessage:
          'Local operation history cleared. Any downloaded models remain untouched.',
    ));
  }

  Future<void> _onResetAll(
    ResetLocalIntelligenceRequested event,
    Emitter<LocalIntelligenceState> emit,
  ) async {
    await llmEngine.cancelDownload();
    for (final id in state.installedModelIds) {
      await llmEngine.deleteModelFiles(id);
      await database.deleteInstalledLocalModel(id);
    }
    await llmEngine.unloadModel();
    await database.clearOperationHistory();
    summaryOrchestrator.resetSessionContext();
    const fresh = LocalIntelligenceConfig();
    await database.saveLocalIntelligenceConfig(fresh);
    final refreshedDevice = await llmEngine.probeDevice();
    emit(state.copyWith(
      config: fresh,
      deviceProfile: refreshedDevice,
      history: const [],
      installedModelIds: const {},
      installedModelPaths: const {},
      clearDownloadingModel: true,
      clearSummary: true,
      statusMessage:
          'Local Intelligence reset: disabled, models removed, and operation history cleared.',
    ));
  }
}

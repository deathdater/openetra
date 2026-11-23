import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/theme.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/local_intelligence/bloc/local_intelligence_bloc.dart';
import 'package:openetra/features/local_intelligence/domain/deterministic_summary_engine.dart';
import 'package:openetra/features/local_intelligence/domain/local_llm_engine.dart';
import 'package:openetra/features/local_intelligence/domain/local_model_catalogue.dart';
import 'package:openetra/features/local_intelligence/domain/operation_history_collector.dart';
import 'package:openetra/features/local_intelligence/domain/operation_history_event.dart';
import 'package:openetra/features/local_intelligence/domain/summary_orchestrator.dart';
import 'package:openetra/features/local_intelligence/presentation/activity_history_screen.dart';
import 'package:openetra/features/local_intelligence/presentation/local_intelligence_settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeLocalLlmEngine implements LocalLlmEngine {
  _FakeLocalLlmEngine();

  final DeviceHardwareProfile device = const DeviceHardwareProfile(
    androidApiLevel: 34,
    totalRamMb: 6144,
    availableStorageMb: 8000,
    supportedAbis: ['arm64-v8a'],
    liteRtLmRuntimeAvailable: true,
  );
  bool shouldPassVerification = true;
  bool shouldPassSmokeTest = true;
  bool shouldPassDownload = true;
  InternetAccessStatus fakeInternet = InternetAccessStatus.availableWifi;
  String? fakeSummaryResponse =
      'Earlier today you completed 2 recorded activities: 1 scene description and 1 text reading.';
  String? _loaded;
  int generateCallCount = 0;
  int unloadCallCount = 0;
  int downloadCallCount = 0;
  int openInternetSettingsCount = 0;
  bool lastWifiOnlyArg = true;
  final List<String> deletedModels = [];
  final StreamController<ModelDownloadProgress> _progressController =
      StreamController<ModelDownloadProgress>.broadcast();

  @override
  String? get loadedModelId => _loaded;

  @override
  Stream<ModelDownloadProgress> get downloadProgressStream =>
      _progressController.stream;

  @override
  Future<DeviceHardwareProfile> probeDevice() async => device;

  @override
  Future<InternetAccessStatus> checkInternetAccess() async => fakeInternet;

  @override
  Future<bool> openInternetSettings() async {
    openInternetSettingsCount++;
    return true;
  }

  @override
  Future<ModelDownloadResult> downloadModel({
    required LocalModelSpec spec,
    required bool wifiOnly,
    String? authToken,
  }) async {
    downloadCallCount++;
    lastWifiOnlyArg = wifiOnly;
    _progressController.add(ModelDownloadProgress(
      modelId: spec.modelId,
      downloadedBytes: 150 * 1024 * 1024,
      totalBytes: spec.packageSizeMb * 1024 * 1024,
      progress: 0.5,
      status: 'downloading',
    ));
    if (!shouldPassDownload) {
      return const ModelDownloadResult(
        success: false,
        error: 'Wi-Fi only download is enabled.',
      );
    }
    return ModelDownloadResult(
      success: true,
      filePath: '/tmp/${spec.modelId}__${spec.fileName}',
      sizeBytes: spec.packageSizeMb * 1024 * 1024,
    );
  }

  @override
  Future<void> cancelDownload() async {}

  @override
  Future<ModelVerificationResult> verifyLocalModelFile({
    required String modelId,
    required String filePath,
    String? expectedSha256,
  }) async {
    if (!shouldPassVerification) {
      return const ModelVerificationResult(
        verified: false,
        error: 'SHA-256 mismatch',
      );
    }
    return const ModelVerificationResult(
      verified: true,
      sha256: 'abc123verified',
      sizeBytes: 450 * 1024 * 1024,
    );
  }

  @override
  Future<bool> initializeModel({
    required String modelId,
    required String filePath,
  }) async {
    _loaded = modelId;
    return true;
  }

  @override
  Future<bool> runSmokeTest() async => shouldPassSmokeTest;

  @override
  Future<String?> generateBoundedSummary({
    required String systemInstruction,
    required String boundedHistoryContext,
    required String userQuestion,
    int maxOutputTokens = 160,
  }) async {
    generateCallCount++;
    return fakeSummaryResponse;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = null;
    unloadCallCount++;
  }

  @override
  Future<bool> deleteModelFiles(String modelId) async {
    if (_loaded == modelId) _loaded = null;
    deletedModels.add(modelId);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('OperationHistorySanitizer redacts emails, phone numbers, passwords and frames history distinctly from live view', () {
    final sanitized = OperationHistorySanitizer.sanitizeSummary(
      'Call +91 9876543210 or email user@example.com with password: secret123',
    );
    expect(sanitized, isNot(contains('9876543210')));
    expect(sanitized, isNot(contains('user@example.com')));
    expect(sanitized, isNot(contains('secret123')));
    expect(sanitized, contains('[redacted number]'));
    expect(sanitized, contains('[redacted email]'));

    final now = DateTime(2026, 11, 23, 16, 30);
    final ev = OperationHistoryEvent(
      eventId: 'e1',
      operationType: OperationType.sceneDescription,
      status: OperationStatus.completed,
      startedAt: now.subtract(const Duration(seconds: 3)),
      completedAt: now,
      durationMs: 3000,
      sanitizedSummary: 'Described a living room with a table.',
    );
    final spoken = ev.buildHistoricalSpokenDetail();
    expect(spoken, contains('Earlier record'));
    expect(spoken, contains('not a current camera view'));
  });

  test('Local Intelligence is disabled by default; collector records nothing when disabled and deduplicates/prunes when enabled', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final tables = await db.listTableNames();
    expect(tables, containsAll(['operation_history_events', 'local_intelligence_models']));

    final defaultCfg = await db.loadLocalIntelligenceConfig();
    expect(defaultCfg.enabled, isFalse);
    expect(defaultCfg.historyEnabled, isFalse);
    expect(defaultCfg.summariesEnabled, isFalse);

    var cfg = defaultCfg;
    var fakeNow = DateTime(2026, 11, 23, 10, 0, 0);
    final collector = OperationHistoryCollector(
      database: db,
      configProvider: () => cfg,
      clock: () => fakeNow,
    );

    // Disabled -> nothing recorded
    final recordedWhileOff = await collector.record(
      type: OperationType.sceneDescription,
      status: OperationStatus.completed,
      rawSummary: 'Described kitchen.',
      startedAt: fakeNow,
    );
    expect(recordedWhileOff, isFalse);
    expect(await db.queryOperationHistory(), isEmpty);

    // Enable -> records event, deduplicates rapid repeat, prunes expired
    cfg = cfg.copyWith(enabled: true, historyEnabled: true, retentionDays: 7);
    expect(
      await collector.record(
        type: OperationType.sceneDescription,
        status: OperationStatus.completed,
        rawSummary: 'Described kitchen.',
        startedAt: fakeNow,
      ),
      isTrue,
    );
    // Duplicate within 1.5s ignored
    expect(
      await collector.record(
        type: OperationType.sceneDescription,
        status: OperationStatus.completed,
        rawSummary: 'Described kitchen.',
        startedAt: fakeNow,
      ),
      isFalse,
    );
    expect((await db.queryOperationHistory()).length, 1);

    // Advance past 7-day retention -> pruned on next record
    fakeNow = fakeNow.add(const Duration(days: 8));
    await collector.record(
      type: OperationType.textReading,
      status: OperationStatus.completed,
      rawSummary: 'Read English label.',
      startedAt: fakeNow,
    );
    final remaining = await db.queryOperationHistory();
    expect(remaining.length, 1);
    expect(remaining.first.operationType, OperationType.textReading);

    await db.close();
  });

  test('End-to-end Local Intelligence lifecycle: enable, verify model, summarize, follow-up, disable unloads LLM, independent delete model vs clear history', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final fakeLlm = _FakeLocalLlmEngine();
    final now = DateTime(2026, 11, 23, 14, 0, 0);
    final orchestrator = SummaryOrchestrator(
      database: db,
      llmEngine: fakeLlm,
      clock: () => now,
    );
    final bloc = LocalIntelligenceBloc(
      database: db,
      llmEngine: fakeLlm,
      summaryOrchestrator: orchestrator,
    );

    bloc.add(const LoadLocalIntelligence());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(bloc.state.config.enabled, isFalse);

    // Enable feature, history, and summaries
    bloc.add(const SetLocalIntelligenceEnabled(true));
    bloc.add(const SetOperationHistoryEnabled(true));
    bloc.add(const SetAiSummariesEnabled(true));
    await Future<void>.delayed(const Duration(milliseconds: 120));

    // Verify & activate Qwen3-0.6B
    bloc.add(const VerifyAndActivateModel(
      modelId: 'qwen3-0.6b-q4',
      filePath: '/tmp/qwen3-0.6b-q4.litertlm',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(bloc.state.config.activeModelId, 'qwen3-0.6b-q4');
    expect(bloc.state.installedModelIds, contains('qwen3-0.6b-q4'));

    // Insert 2 operations today (scene + OCR)
    await db.insertOperationHistoryEvent(
      OperationHistoryEvent(
        eventId: 'ev-1',
        operationType: OperationType.sceneDescription,
        status: OperationStatus.completed,
        startedAt: now.subtract(const Duration(minutes: 10)),
        completedAt: now.subtract(const Duration(minutes: 9)),
        durationMs: 3200,
        sanitizedSummary: 'Described living room with sofa and chair.',
      ),
    );
    await db.insertOperationHistoryEvent(
      OperationHistoryEvent(
        eventId: 'ev-2',
        operationType: OperationType.textReading,
        status: OperationStatus.completed,
        startedAt: now.subtract(const Duration(minutes: 5)),
        completedAt: now.subtract(const Duration(minutes: 4)),
        durationMs: 2500,
        sanitizedSummary: 'Read English printed sign.',
      ),
    );

    // Request daily summary -> uses verified local LLM
    bloc.add(const RequestActivitySummary(range: HistoryTimeRange.today));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(fakeLlm.generateCallCount, 1);
    expect(bloc.state.latestSummary?.isDeterministicFallback, isFalse);
    expect(bloc.state.latestSummary?.generatedByModelId, 'qwen3-0.6b-q4');

    // Disable Local Intelligence -> unloads LLM, no LLM inference occurs after disable
    bloc.add(const SetLocalIntelligenceEnabled(false));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fakeLlm.loadedModelId, isNull);
    expect(fakeLlm.unloadCallCount, greaterThanOrEqualTo(1));

    // Deterministic summary still works without LLM & makes 0 new LLM calls
    bloc.add(const AskHistoricalQuestion('How many were text reading?'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fakeLlm.generateCallCount, 1);
    expect(bloc.state.latestSummary?.isDeterministicFallback, isTrue);
    expect(bloc.state.latestSummary?.spokenSummary, contains('1 of 2'));

    // Re-enable -> retained history is still intact
    bloc.add(const SetLocalIntelligenceEnabled(true));
    bloc.add(const RefreshOperationHistory());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(bloc.state.history.length, 2);

    // Delete model ONLY -> history remains intact!
    bloc.add(const DeleteDownloadedModel('qwen3-0.6b-q4'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(bloc.state.installedModelIds, isEmpty);
    expect((await db.queryOperationHistory()).length, 2);

    // Re-install model, then Clear History ONLY -> model remains intact!
    bloc.add(const VerifyAndActivateModel(
      modelId: 'qwen3-0.6b-q4',
      filePath: '/tmp/qwen3-0.6b-q4.litertlm',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    bloc.add(const ClearOperationHistoryRequested());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await db.queryOperationHistory(), isEmpty);
    expect(bloc.state.installedModelIds, contains('qwen3-0.6b-q4'));

    await bloc.close();
    await db.close();
  });

  testWidgets('LocalIntelligenceSettingsScreen and ActivityHistoryScreen render cleanly across themes', (tester) async {
    late OpenetraDatabase db;
    late LocalIntelligenceBloc bloc;
    await tester.runAsync(() async {
      db = await OpenetraDatabase.open(
        factory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
      final fakeLlm = _FakeLocalLlmEngine();
      bloc = LocalIntelligenceBloc(
        database: db,
        llmEngine: fakeLlm,
        summaryOrchestrator: SummaryOrchestrator(
          database: db,
          llmEngine: fakeLlm,
        ),
      )..add(const LoadLocalIntelligence());
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: OpenetraTheme.buildDarkTheme(),
        home: BlocProvider.value(
          value: bloc,
          child: const LocalIntelligenceSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Intelligence (Beta)'), findsOneWidget);
    expect(find.text('Local Intelligence Beta: Disabled'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Qwen3-0.6B (Compact)'), 300);
    expect(find.text('Qwen3-0.6B (Compact)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Download (~328 MB)'), 300);
    expect(find.text('Download (~328 MB)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Open Local Activity History & Summaries'),
      -300,
    );
    await tester.ensureVisible(
      find.text('Open Local Activity History & Summaries'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Local Activity History & Summaries'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityHistoryScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No recorded activities yet'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No recorded activities yet'), findsOneWidget);

    await tester.runAsync(() async {
      await bloc.close();
      await db.close();
    });
  });

  test('DownloadAndInstallModel downloads, verifies, persists, and activates model respecting Wi-Fi-only toggle', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final fakeLlm = _FakeLocalLlmEngine();
    final bloc = LocalIntelligenceBloc(
      database: db,
      llmEngine: fakeLlm,
      summaryOrchestrator: SummaryOrchestrator(
        database: db,
        llmEngine: fakeLlm,
      ),
    );

    bloc.add(const LoadLocalIntelligence());
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(bloc.state.config.wifiOnlyDownload, isTrue);

    bloc.add(const SetWifiOnlyDownload(false));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(bloc.state.config.wifiOnlyDownload, isFalse);

    // Offline -> mandatory internet gate blocks download & flags internetActionRequired
    fakeLlm.fakeInternet = const InternetAccessStatus(
      hasPermission: true,
      isConnected: false,
      isWifi: false,
    );
    bloc.add(const DownloadAndInstallModel(modelId: 'qwen3-0.6b-q4'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fakeLlm.downloadCallCount, 0);
    expect(bloc.state.internetActionRequired, isTrue);
    expect(bloc.state.statusMessage, contains('Internet access is required'));

    // Reconnect -> download succeeds
    fakeLlm.fakeInternet = InternetAccessStatus.availableWifi;
    bloc.add(const DownloadAndInstallModel(modelId: 'qwen3-0.6b-q4'));
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(fakeLlm.downloadCallCount, 1);
    expect(fakeLlm.lastWifiOnlyArg, isFalse);
    expect(bloc.state.internetActionRequired, isFalse);
    expect(bloc.state.installedModelIds, contains('qwen3-0.6b-q4'));
    expect(bloc.state.config.activeModelId, 'qwen3-0.6b-q4');
    expect(bloc.state.downloadingModelId, isNull);

    await bloc.close();
    await db.close();
  });
}

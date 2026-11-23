import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/accessibility/accessibility_announcer.dart';
import 'package:openetra/core/assistive/assistive_action.dart';
import 'package:openetra/core/assistive/assistive_action_router.dart';
import 'package:openetra/core/assistive/audio_arbitrator.dart';
import 'package:openetra/core/assistive/camera_resource_manager.dart';
import 'package:openetra/core/assistive/custom_gesture_record.dart';
import 'package:openetra/core/assistive/feedback_dispatcher.dart';
import 'package:openetra/core/assistive/permission_coordinator.dart';
import 'package:openetra/core/assistive/task_orchestrator.dart';
import 'package:openetra/core/audio/bloc/audio_bloc.dart';
import 'package:openetra/core/audio/haptic_feedback_service.dart';
import 'package:openetra/core/audio/speech_controller.dart';
import 'package:openetra/core/camera/camera_controller_bridge.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeCameraSource implements CameraSource {
  int startCount = 0;
  int stopCount = 0;
  double nextLuma = 128.0;

  @override
  Future<void> start({int minIntervalMs = 500}) async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<CapturedFrame> captureFrame() async {
    return CapturedFrame(
      width: 640,
      height: 480,
      capturedAt: DateTime(2026, 11, 23),
      qualityMetrics: ImageQualityMetrics(
        meanLuma: nextLuma,
        lumaStdDev: 40,
        laplacianVariance: 120,
        overexposedRatio: 0,
        underexposedRatio: 0,
      ),
    );
  }
}

class _TestOverlaySink implements FloatingOverlayStateSink {
  final List<AssistiveTaskSnapshot> received = [];

  @override
  Future<void> publishWidgetState(AssistiveTaskSnapshot snapshot) async {
    received.add(snapshot);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('AssistiveActionRouter, CapabilityAvailabilityService, and PermissionCoordinator enforce background/permission policies', () async {
    final gateway = DefaultInMemoryPermissionGateway({
      OpenetraPermission.camera: PermissionGrantState.granted,
      OpenetraPermission.microphone: PermissionGrantState.denied,
      OpenetraPermission.notifications: PermissionGrantState.granted,
      OpenetraPermission.overlay: PermissionGrantState.denied,
    });
    final perms = PermissionCoordinator(gateway: gateway);
    final avail = CapabilityAvailabilityService(permissions: perms);

    expect(AssistiveActionRouter.parseId('describe_scene'), AssistiveActionId.describeScene);
    expect(AssistiveActionRouter.parseId('start_emergency_assistance'), AssistiveActionId.startEmergencyAssistance);
    expect(AssistiveActionRouter.parseId('toggle_flashlight'), AssistiveActionId.toggleFlashlight);

    const camSpec = AssistiveActionSpec(
      id: AssistiveActionId.describeScene,
      displayName: 'Describe Scene',
      accessibleDescription: 'Describes view',
      backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
      requiresCamera: true,
    );
    const bgTorchSpec = AssistiveActionSpec(
      id: AssistiveActionId.toggleFlashlight,
      displayName: 'Toggle Flashlight',
      accessibleDescription: 'Toggles torch',
      backgroundCategory: BackgroundExecutionCategory.backgroundSafe,
    );

    expect((await avail.evaluate(camSpec, fromBackground: false)).canExecuteNow, isTrue);
    final bgCam = await avail.evaluate(camSpec, fromBackground: true);
    expect(bgCam.state, AvailabilityState.requiresForegroundUi);

    expect((await avail.evaluate(bgTorchSpec, fromBackground: true)).canExecuteNow, isTrue);

    gateway.setStateForTest(OpenetraPermission.camera, PermissionGrantState.denied);
    final revokedCam = await avail.evaluate(camSpec);
    expect(revokedCam.state, AvailabilityState.missingPermission);
    expect(revokedCam.missingPermission, OpenetraPermission.camera);

    await perms.dispose();
  });

  test('TaskOrchestrator handles phases, duplicate taps, preemption, timeouts, and FeedbackDispatcher sanitization', () async {
    var fakeNow = DateTime(2026, 11, 23, 12, 0, 0);
    final perms = PermissionCoordinator(
      gateway: DefaultInMemoryPermissionGateway({
        OpenetraPermission.camera: PermissionGrantState.granted,
        OpenetraPermission.microphone: PermissionGrantState.granted,
      }),
    );
    final avail = CapabilityAvailabilityService(permissions: perms);
    final router = AssistiveActionRouter();
    final speech = SpeechController(enablePlatformTts: false);
    final audioBloc = AudioBloc(
      announcer: AccessibilityAnnouncer(
        speechController: speech,
        hapticService: HapticFeedbackService(),
      ),
      speechController: speech,
    );
    final orchestrator = TaskOrchestrator(
      router: router,
      availabilityService: avail,
      clock: () => fakeNow,
    );
    final dispatcher = FeedbackDispatcher(
      orchestrator: orchestrator,
      audioBloc: audioBloc,
    );
    final sink = _TestOverlaySink();
    dispatcher.attachOverlaySink(sink);
    dispatcher.start();

    final gate = Completer<void>();
    var sceneCalls = 0;
    var emergencyCalled = false;

    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.describeScene,
        displayName: 'Describe Scene',
        accessibleDescription: 'Captures and describes surroundings',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
        timeout: Duration(milliseconds: 200),
      ),
      handler: (ctx) async {
        sceneCalls++;
        orchestrator.updatePhase(
          ctx.taskId,
          AssistiveTaskPhase.aiInference,
          statusLabel: 'Private scene caption should stay off external sink',
        );
        await gate.future;
      },
    );

    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.startEmergencyAssistance,
        displayName: 'Emergency Assistance',
        accessibleDescription: 'Opens trusted emergency confirmation',
        backgroundCategory: BackgroundExecutionCategory.backgroundSafe,
        preemptsActiveTask: true,
      ),
      handler: (ctx) async {
        emergencyCalled = true;
      },
    );

    final firstFuture = orchestrator.dispatch(AssistiveActionId.describeScene, sourceTrigger: 'orb_tap');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(orchestrator.currentSnapshot.phase, AssistiveTaskPhase.aiInference);

    // Duplicate tap within 450 ms is rejected cleanly.
    final dup = await orchestrator.dispatch(AssistiveActionId.describeScene, sourceTrigger: 'orb_tap');
    expect(dup.accepted, isFalse);
    expect(sceneCalls, 1);

    // Emergency action preempts active scene task immediately.
    fakeNow = fakeNow.add(const Duration(seconds: 1));
    final emerg = await orchestrator.dispatch(
      AssistiveActionId.startEmergencyAssistance,
      sourceTrigger: 'orb_long_press',
      fromBackground: true,
    );
    expect(emerg.accepted, isTrue);
    expect(emergencyCalled, isTrue);
    gate.complete();
    await firstFuture;

    // FeedbackDispatcher sanitized labels never leak internal scene descriptions.
    expect(
      sink.received.every((s) => !s.statusLabel.contains('Private scene caption')),
      isTrue,
    );

    // Timeout enforcement cleanly marks task failed.
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.readText,
        displayName: 'Read Text',
        accessibleDescription: 'Slow hang',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        timeout: Duration(milliseconds: 40),
      ),
      handler: (_) => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    final timedOut = await orchestrator.dispatch(AssistiveActionId.readText);
    expect(timedOut.accepted, isFalse);
    expect(timedOut.finalSnapshot.phase, AssistiveTaskPhase.failed);

    await dispatcher.dispose();
    await audioBloc.close();
    await orchestrator.dispose();
    await perms.dispose();
  });

  test('CameraResourceManager enforces single-owner lease and shares active luma; AudioArbitrator deduplicates', () async {
    final cam = _FakeCameraSource()..nextLuma = 18.5;
    final mgr = CameraResourceManager(cameraSource: cam);
    final observedLumas = <double>[];
    mgr.addLumaListener(observedLumas.add);

    final sceneLease = await mgr.acquireLease(CameraLeasePurpose.scene);
    expect(cam.startCount, 1);

    await expectLater(
      () => mgr.acquireLease(CameraLeasePurpose.gestureSession),
      throwsStateError,
    );

    await mgr.captureFrame(sceneLease);
    expect(observedLumas, [18.5]);

    // Preempting cleanly stops previous lease owner.
    final gestureLease = await mgr.acquireLease(
      CameraLeasePurpose.gestureSession,
      preemptExisting: true,
    );
    expect(cam.stopCount, 1);
    expect(cam.startCount, 2);

    await mgr.releaseLease(gestureLease);
    expect(mgr.hasActiveLease, isFalse);
    expect(cam.stopCount, 2);

    // AudioArbitrator emergency preemption + cooldown deduplication.
    var now = DateTime(2026, 11, 23, 12, 10, 0);
    final speech = SpeechController(enablePlatformTts: false);
    final audioBloc = AudioBloc(
      announcer: AccessibilityAnnouncer(
        speechController: speech,
        hapticService: HapticFeedbackService(),
      ),
      speechController: speech,
    );
    final arbitrator = AudioArbitrator(
      audioBloc: audioBloc,
      speechController: speech,
      clock: () => now,
    );

    arbitrator.announceTransition(
      categoryKey: 'torch',
      spokenText: 'Flashlight on.',
      locale: 'en-IN',
      cooldown: const Duration(seconds: 3),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(audioBloc.state.lastSpokenText, 'Flashlight on.');

    // Within cooldown: skipped so TTS doesn't spam.
    now = now.add(const Duration(seconds: 1));
    arbitrator.announceTransition(
      categoryKey: 'torch',
      spokenText: 'Flashlight off.',
      locale: 'en-IN',
      cooldown: const Duration(seconds: 3),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(audioBloc.state.lastSpokenText, 'Flashlight on.');

    // Emergency preempts regardless of cooldown.
    await arbitrator.speakPriorityEmergency('Emergency confirmation open.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(audioBloc.state.lastSpokenText, 'Emergency confirmation open.');

    await audioBloc.close();
  });

  test('SQLite v2->v3 migration creates assistive_preferences & custom_gestures and clears both on wipe', () async {
    final tmpDir = Directory.systemTemp.createTempSync('openetra_v2_v3_');
    addTearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });
    final dbPath = p.join(tmpDir.path, 'legacy_v2.db');

    final v2 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE user_preferences (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              preferred_language TEXT NOT NULL,
              operating_mode TEXT NOT NULL,
              high_contrast INTEGER NOT NULL,
              verbose_descriptions INTEGER NOT NULL,
              onboarding_completed INTEGER NOT NULL,
              safety_disclaimer_accepted INTEGER NOT NULL,
              speech_rate REAL NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE voice_config (
              locale TEXT PRIMARY KEY,
              speech_rate REAL NOT NULL,
              pitch REAL NOT NULL,
              preferred_voice_name TEXT,
              is_offline_verified INTEGER NOT NULL,
              barge_in_enabled INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE personal_objects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              color_hint TEXT,
              description TEXT,
              created_at_ms INTEGER NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE object_embeddings (
              id TEXT PRIMARY KEY,
              object_id TEXT NOT NULL,
              model_id TEXT NOT NULL,
              embedding_blob BLOB NOT NULL,
              dimension INTEGER NOT NULL,
              created_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE last_seen_records (
              id TEXT PRIMARY KEY,
              object_id TEXT NOT NULL,
              scene_setting TEXT,
              relative_position TEXT,
              confidence REAL NOT NULL,
              seen_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE scanned_documents (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              detected_script TEXT NOT NULL,
              extracted_text TEXT NOT NULL,
              confidence REAL NOT NULL,
              language TEXT NOT NULL,
              created_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE conversation_history (
              id TEXT PRIMARY KEY,
              role TEXT NOT NULL,
              intent TEXT NOT NULL,
              utterance TEXT NOT NULL,
              language TEXT NOT NULL,
              created_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE model_registry (
              model_id TEXT PRIMARY KEY,
              version TEXT NOT NULL,
              task TEXT NOT NULL,
              runtime TEXT NOT NULL,
              file_path TEXT,
              expected_sha256 TEXT NOT NULL,
              actual_sha256 TEXT,
              verified_at_ms INTEGER,
              status TEXT NOT NULL,
              size_bytes INTEGER NOT NULL,
              licence TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE safety_events (
              id TEXT PRIMARY KEY,
              event_type TEXT NOT NULL,
              severity TEXT NOT NULL,
              message TEXT NOT NULL,
              degraded_reason TEXT,
              hazard_category TEXT,
              created_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE benchmark_metadata (
              id TEXT PRIMARY KEY,
              model_id TEXT NOT NULL,
              device_tier TEXT NOT NULL,
              input_width INTEGER NOT NULL,
              input_height INTEGER NOT NULL,
              cold_load_ms INTEGER NOT NULL,
              inference_ms INTEGER NOT NULL,
              thermal_state TEXT NOT NULL,
              recorded_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE local_products (
              barcode TEXT PRIMARY KEY,
              product_name TEXT NOT NULL,
              brand TEXT,
              net_quantity TEXT,
              category TEXT,
              source TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
          ''');
          await db.insert('local_products', {
            'barcode': '8901058851234',
            'product_name': 'Masala 2-Minute Noodles',
            'brand': 'Maggi',
            'net_quantity': '70 g',
            'category': 'packaged_food',
            'source': 'builtin_sample',
            'updated_at_ms': 1700000000000,
          });
        },
      ),
    );
    await v2.close();

    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: dbPath,
    );
    final tables = await db.listTableNames();
    expect(tables, containsAll(['assistive_preferences', 'custom_gestures']));
    expect(await db.lookupLocalProduct('8901058851234'), isNotNull);

    await db.setAssistivePreference('auto_torch_enabled', 'true');
    expect(await db.getAssistivePreference('auto_torch_enabled'), 'true');

    await db.upsertCustomGesture(
      CustomGestureRecord(
        id: 'g-1',
        name: 'Two Finger Tap',
        actionId: AssistiveActionId.describeScene,
        sampleCount: 5,
        templates: const [
          [1.0, 0.0, 0.0],
          [0.99, 0.1, 0.0],
        ],
        threshold: 0.85,
        isValidated: true,
        createdAt: DateTime(2026, 11, 23),
        updatedAt: DateTime(2026, 11, 23),
      ),
    );
    final loaded = await db.listCustomGestures();
    expect(loaded.single.name, 'Two Finger Tap');
    expect(loaded.single.actionId, AssistiveActionId.describeScene);

    await db.deleteAllUserData();
    expect(await db.listCustomGestures(), isEmpty);
    expect(await db.getAllAssistivePreferences(), isEmpty);
    expect(await db.lookupLocalProduct('8901058851234'), isNotNull);

    await db.close();
  });
}

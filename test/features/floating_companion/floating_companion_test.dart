import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/accessibility/accessibility_announcer.dart';
import 'package:openetra/core/assistive/assistive_action.dart';
import 'package:openetra/core/assistive/assistive_action_router.dart';
import 'package:openetra/core/assistive/feedback_dispatcher.dart';
import 'package:openetra/core/assistive/permission_coordinator.dart';
import 'package:openetra/core/assistive/task_orchestrator.dart';
import 'package:openetra/core/audio/bloc/audio_bloc.dart';
import 'package:openetra/core/audio/haptic_feedback_service.dart';
import 'package:openetra/core/audio/speech_controller.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/floating_companion/bloc/floating_companion_bloc.dart';
import 'package:openetra/features/floating_companion/data/native_floating_companion_bridge.dart';
import 'package:openetra/features/floating_companion/presentation/floating_widget_settings_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('FloatingCompanionBloc enforces overlay permission, routes Category A vs C cleanly, and publishes real task states to overlay sink', () async {
    final tempDir = Directory.systemTemp.createTempSync('openetra_float_test_');
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: p.join(tempDir.path, 'openetra.db'),
    );
    addTearDown(() async {
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final perms = PermissionCoordinator(
      gateway: DefaultInMemoryPermissionGateway({
        OpenetraPermission.camera: PermissionGrantState.granted,
        OpenetraPermission.overlay: PermissionGrantState.granted,
      }),
    );
    final router = AssistiveActionRouter();
    final executed = <(AssistiveActionId, String, bool)>[];

    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.toggleFlashlight,
        displayName: 'Toggle Flashlight',
        accessibleDescription: 'Background safe torch toggle',
        backgroundCategory: BackgroundExecutionCategory.backgroundSafe,
      ),
      handler: (ctx) async {
        executed.add((AssistiveActionId.toggleFlashlight, ctx.sourceTrigger, ctx.fromBackground));
      },
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.describeScene,
        displayName: 'Describe Scene',
        accessibleDescription: 'Requires foreground UI',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
      ),
      handler: (ctx) async {
        executed.add((AssistiveActionId.describeScene, ctx.sourceTrigger, ctx.fromBackground));
      },
    );

    var fakeNow = DateTime(2026, 11, 23, 15, 0, 0);
    final orchestrator = TaskOrchestrator(
      router: router,
      availabilityService: CapabilityAvailabilityService(permissions: perms),
      clock: () => fakeNow,
    );
    final speech = SpeechController(enablePlatformTts: false);
    final audioBloc = AudioBloc(
      announcer: AccessibilityAnnouncer(
        speechController: speech,
        hapticService: HapticFeedbackService(),
      ),
      speechController: speech,
    );
    final bridge = FakeFloatingCompanionBridge()..permissionGranted = false;
    final dispatcher = FeedbackDispatcher(
      orchestrator: orchestrator,
      audioBloc: audioBloc,
    )
      ..attachOverlaySink(bridge)
      ..start();

    final bloc = FloatingCompanionBloc(
      bridge: bridge,
      taskOrchestrator: orchestrator,
      database: db,
    );
    addTearDown(() async {
      await bloc.close();
      await dispatcher.dispose();
      await bridge.dispose();
      await audioBloc.close();
      await perms.dispose();
    });

    // 1. Permission denied -> cannot start overlay.
    bloc.add(const LoadFloatingCompanionConfig());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    bloc.add(const ToggleFloatingCompanion(true));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bridge.serviceRunning, isFalse);
    expect(bloc.state.statusMessage, contains('permission is required'));

    // 2. Grant permission -> starts overlay cleanly and persists reduced motion config.
    bridge.permissionGranted = true;
    bloc.add(const ToggleFloatingCompanion(true));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bridge.serviceRunning, isTrue);
    expect(bloc.state.config.enabled, isTrue);

    bloc.add(
      UpdateFloatingCompanionConfig(
        bloc.state.config.copyWith(reducedMotionOverride: true, orbSizeDp: 72),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bridge.lastConfig?.reducedMotionOverride, isTrue);
    expect(bridge.lastConfig?.orbSizeDp, 72);

    // 3. Background Category A action (toggle_flashlight) succeeds & publishes real state to overlay.
    bridge.simulateOrbTrigger('toggle_flashlight', fromBackground: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      executed,
      contains((AssistiveActionId.toggleFlashlight, 'floating_widget', true)),
    );
    expect(bridge.publishedStates, isNotEmpty);

    // 4. Background Category C action (describe_scene with fromBackground=true) blocked by availability policy!
    bridge.simulateOrbTrigger('describe_scene', fromBackground: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      executed.where((e) => e.$1 == AssistiveActionId.describeScene),
      isEmpty,
    );

    // 5. Same Category C action launched in foreground (fromBackground=false via MainActivity trampoline) succeeds!
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    bridge.simulateOrbTrigger('describe_scene', fromBackground: false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      executed.where((e) => e.$1 == AssistiveActionId.describeScene),
      hasLength(1),
    );

    // 6. Revoking overlay permission turns off companion gracefully.
    bridge.permissionGranted = false;
    bloc.add(const RefreshOverlayPermission());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bridge.serviceRunning, isFalse);
    expect(bloc.state.config.enabled, isFalse);
    expect(bloc.state.statusMessage, contains('revoked'));
  });

  testWidgets('FloatingWidgetSettingsScreen guides permission and toggles companion', (tester) async {
    final perms = PermissionCoordinator();
    final orchestrator = TaskOrchestrator(
      router: AssistiveActionRouter(),
      availabilityService: CapabilityAvailabilityService(permissions: perms),
    );
    final bridge = FakeFloatingCompanionBridge()..permissionGranted = false;
    final bloc = FloatingCompanionBloc(
      bridge: bridge,
      taskOrchestrator: orchestrator,
    )..add(const LoadFloatingCompanionConfig());
    addTearDown(() async {
      await bloc.close();
      await bridge.dispose();
      await perms.dispose();
    });

    await tester.pumpWidget(
      BlocProvider<FloatingCompanionBloc>.value(
        value: bloc,
        child: const MaterialApp(home: FloatingWidgetSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grant Overlay Permission (Android Settings)'), findsOneWidget);
    await tester.tap(find.text('Grant Overlay Permission (Android Settings)'));
    await tester.pumpAndSettle();
    expect(bridge.openSettingsCount, 1);

    bridge.permissionGranted = true;
    bloc.add(const RefreshOverlayPermission());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable Floating Assistive Orb'));
    await tester.pumpAndSettle();
    expect(bridge.serviceRunning, isTrue);
    expect(
      find.text('Floating Assistive Orb: Active (Tap to Stop)'),
      findsOneWidget,
    );
  });
}

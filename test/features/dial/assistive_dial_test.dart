import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/app.dart';
import 'package:openetra/core/accessibility/accessibility_announcer.dart';
import 'package:openetra/core/assistive/assistive_action.dart';
import 'package:openetra/core/assistive/assistive_action_router.dart';
import 'package:openetra/core/assistive/audio_arbitrator.dart';
import 'package:openetra/core/assistive/permission_coordinator.dart';
import 'package:openetra/core/assistive/task_orchestrator.dart';
import 'package:openetra/core/audio/bloc/audio_bloc.dart';
import 'package:openetra/core/audio/haptic_feedback_service.dart';
import 'package:openetra/core/audio/speech_controller.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/haptics/haptic_feedback_manager.dart';
import 'package:openetra/core/inference/mirage/mirage_response_parser.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/dial/bloc/assistive_dial_bloc.dart';
import 'package:openetra/features/dial/domain/dial_gesture_recognizer.dart';
import 'package:openetra/features/dial/models/dial_menu_node.dart';
import 'package:openetra/features/scene_understanding/domain/scene_understanding_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('DialGestureAnalyzer enforces distance, velocity, dominance, edge guard, multi-touch, and debounce', () {
    var fakeNow = DateTime(2026, 11, 23, 15, 0, 0);
    final analyzer = DialGestureAnalyzer(clock: () => fakeNow);
    const viewport = Size(400, 800);

    // Clear upward swipe -> slideUp
    expect(
      analyzer.classify(
        startPosition: const Offset(200, 450),
        endPosition: const Offset(210, 350),
        viewportSize: viewport,
        velocityDpPerSec: 400,
      ),
      DialGestureType.slideUp,
    );

    // Immediate rapid gesture within 250 ms -> debounced
    expect(
      analyzer.classify(
        startPosition: const Offset(200, 350),
        endPosition: const Offset(200, 460),
        viewportSize: viewport,
        velocityDpPerSec: 400,
      ),
      DialGestureType.none,
    );

    // Advance past debounce -> clear downward swipe -> slideDown
    fakeNow = fakeNow.add(const Duration(milliseconds: 300));
    expect(
      analyzer.classify(
        startPosition: const Offset(200, 350),
        endPosition: const Offset(205, 460),
        viewportSize: viewport,
        velocityDpPerSec: 320,
      ),
      DialGestureType.slideDown,
    );

    // Diagonal swipe (dx=80, dy=-80) rejected by 1.5x dominance rule
    fakeNow = fakeNow.add(const Duration(milliseconds: 300));
    expect(
      analyzer.classify(
        startPosition: const Offset(200, 400),
        endPosition: const Offset(280, 320),
        viewportSize: viewport,
        velocityDpPerSec: 400,
      ),
      DialGestureType.none,
    );

    // Multi-touch rejected
    expect(
      analyzer.classify(
        startPosition: const Offset(200, 450),
        endPosition: const Offset(200, 320),
        viewportSize: viewport,
        velocityDpPerSec: 500,
        pointerCount: 2,
      ),
      DialGestureType.none,
    );

    // System edge start (x=10 < 24dp) rejected
    expect(
      analyzer.classify(
        startPosition: const Offset(10, 400),
        endPosition: const Offset(100, 400),
        viewportSize: viewport,
        velocityDpPerSec: 500,
      ),
      DialGestureType.none,
    );

    // Horizontal swipe right -> browseNext, left -> browsePrevious
    expect(
      analyzer.classify(
        startPosition: const Offset(150, 400),
        endPosition: const Offset(220, 405),
        viewportSize: viewport,
        velocityDpPerSec: 250,
      ),
      DialGestureType.browseNext,
    );
    fakeNow = fakeNow.add(const Duration(milliseconds: 300));
    expect(
      analyzer.classify(
        startPosition: const Offset(220, 400),
        endPosition: const Offset(150, 402),
        viewportSize: viewport,
        velocityDpPerSec: 250,
      ),
      DialGestureType.browsePrevious,
    );
  });

  test('AssistiveDialBloc manages menus, distinctive haptics, confirmation, unavailable errors, and two-step root exit', () async {
    var fakeNow = DateTime(2026, 11, 23, 15, 30, 0);
    final router = AssistiveActionRouter();
    final triggered = <(AssistiveActionId, String)>[];
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.readText,
        displayName: 'Read Text',
        accessibleDescription: 'Reads visible text',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
      ),
      handler: (ctx) async {
        triggered.add((AssistiveActionId.readText, ctx.sourceTrigger));
      },
    );

    final permGateway = DefaultInMemoryPermissionGateway({
      OpenetraPermission.camera: PermissionGrantState.granted,
    });
    final perms = PermissionCoordinator(gateway: permGateway);
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
    final arbitrator = AudioArbitrator(
      audioBloc: audioBloc,
      speechController: speech,
      clock: () => fakeNow,
    );
    final haptics = HapticFeedbackManager(
      service: HapticFeedbackService(),
      clock: () => fakeNow,
    );

    final bloc = AssistiveDialBloc(
      taskOrchestrator: orchestrator,
      audioArbitrator: arbitrator,
      hapticManager: haptics,
      clock: () => fakeNow,
    );
    addTearDown(() async {
      await bloc.close();
      await audioBloc.close();
      await perms.dispose();
    });

    bloc.add(const DialInitialized());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.phase, DialLifecyclePhase.rootMenu);
    expect(bloc.focusedOption.id, 'root_describe');

    // Browse next -> Read Text (exploring never executes!)
    fakeNow = fakeNow.add(const Duration(milliseconds: 100));
    bloc.add(const DialBrowseNext());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.focusedOption.id, 'root_read');
    expect(triggered, isEmpty);
    expect(haptics.recentPatterns.last, HapticPattern.dialFocusTick);

    // Slide up -> enters Read Text submenu
    fakeNow = fakeNow.add(const Duration(milliseconds: 100));
    bloc.add(const DialSlideUpRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.phase, DialLifecyclePhase.submenu);
    expect(bloc.state.menuId, 'read_menu');
    expect(bloc.focusedOption.id, 'read_now');
    expect(haptics.recentPatterns.last, HapticPattern.dialSubmenuEnter);

    // Slide up -> executes Read Visible Text through TaskOrchestrator
    fakeNow = fakeNow.add(const Duration(milliseconds: 100));
    bloc.add(const DialSlideUpRequested());
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(triggered.single, (AssistiveActionId.readText, 'assistive_dial'));
    expect(bloc.state.phase, DialLifecyclePhase.completed);
    expect(haptics.recentPatterns, contains(HapticPattern.dialOpStart));
    expect(haptics.recentPatterns.last, HapticPattern.dialOpComplete);

    // Deny camera permission -> unavailable error keeps user in submenu
    permGateway.setStateForTest(
      OpenetraPermission.camera,
      PermissionGrantState.denied,
    );
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    bloc.add(const DialSlideUpRequested());
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(bloc.state.phase, DialLifecyclePhase.failed);
    expect(haptics.recentPatterns.last, HapticPattern.dialOpError);

    // Slide down -> restores parent menu and previously focused parent index (Read Text = 1)
    fakeNow = fakeNow.add(const Duration(milliseconds: 100));
    bloc.add(const DialSlideDownRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.menuId, OpenetraDialMenuTree.rootId);
    expect(bloc.state.focusedIndex, 1);
    expect(haptics.recentPatterns.last, HapticPattern.dialNavigateBack);

    // Focus Emergency Assistance (index 5) -> enter submenu -> requires explicit confirmation
    bloc.add(const DialFocusOptionAt(5));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(const DialSlideUpRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.menuId, 'emergency_menu');

    bloc.add(const DialSlideUpRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.phase, DialLifecyclePhase.confirmingAction);
    expect(bloc.state.pendingScreenRoute, isNull);
    expect(haptics.recentPatterns.last, HapticPattern.critical);

    // Second slide up confirms and emits emergency route
    bloc.add(const DialSlideUpRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.pendingScreenRoute, DialScreenRoute.emergencyAssistance);
    bloc.add(const DialNavigationRouteHandled());

    // Return to root -> two-step root exit within 5 s
    bloc.add(const DialSlideDownRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.menuId, OpenetraDialMenuTree.rootId);

    bloc.add(const DialSlideDownRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.phase, DialLifecyclePhase.exitArmed);
    expect(haptics.recentPatterns.last, HapticPattern.dialExitWarn);

    fakeNow = fakeNow.add(const Duration(seconds: 2));
    bloc.add(const DialSlideDownRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.phase, DialLifecyclePhase.exiting);
  });

  testWidgets('OpenetraApp defaults to accessible AssistiveDialPage with >=64dp controls and submenu navigation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late OpenetraDatabase db;
    late OpenetraDependencies deps;
    await tester.runAsync(() async {
      db = await OpenetraDatabase.open(
        factory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
      deps = await OpenetraDependencies.bootstrap(
        database: db,
        enablePlatformTts: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(OpenetraApp(deps: deps, skipOnboarding: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Root option 1 visible and all accessible dial buttons >= 64dp
    expect(find.text('Describe Surroundings'), findsOneWidget);
    for (final label in ['Previous', 'Select', 'Next', 'Exit', 'Repeat']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final size = tester.getSize(
        find.ancestor(of: finder, matching: find.byType(InkWell)).first,
      );
      expect(size.height, greaterThanOrEqualTo(64.0), reason: '$label < 64dp');
    }

    // Tap Next -> Read Text; tap Select -> enters Read Text submenu; tap Back -> returns to Read Text
    await tester.tap(find.text('Next'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.text('Read Text'), findsOneWidget);

    await tester.tap(find.text('Select'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.text('Read Visible Text'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.text('Read Text'), findsOneWidget);

    await tester.runAsync(() => db.close());
  });

  test('Dial menus omit redundant return items and include Continuous Scene Mode', () {
    final tree = OpenetraDialMenuTree.buildDefaultTree();
    for (final node in tree.values) {
      expect(
        node.options.any((o) => o.kind == DialOptionKind.returnParent),
        isFalse,
        reason: 'Menu ${node.id} should not contain redundant returnParent option',
      );
    }
    final describe = tree['describe_menu']!;
    expect(
      describe.options.any((o) => o.kind == DialOptionKind.toggleContinuousScene),
      isTrue,
    );
  });

  test('SpeechController strictly speaks sequentially without overriding in-flight statements', () async {
    final timeline = <String>[];
    final firstGate = Completer<void>();

    final controller = SpeechController(
      enablePlatformTts: false,
      testSpeakHook: (text) async {
        timeline.add('start:$text');
        if (text == 'First statement.') {
          await firstGate.future;
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        timeline.add('end:$text');
      },
    );

    final f1 = controller.speak('First statement.', locale: 'en-IN', speechRate: 0.5);
    final f2 = controller.speak('Second statement.', locale: 'en-IN', speechRate: 0.5);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Statement 2 must NOT have started while Statement 1 is still speaking!
    expect(timeline, ['start:First statement.']);

    firstGate.complete();
    await Future.wait([f1, f2]);
    expect(timeline, [
      'start:First statement.',
      'end:First statement.',
      'start:Second statement.',
      'end:Second statement.',
    ]);
  });

  test('SceneUnderstandingEngine produces clear human-natural spatial English descriptions', () {
    const parser = MirageResponseParser();
    const engine = SceneUnderstandingEngine();
    const sampleJson = '''
{
  "scene": {
    "setting": "living room",
    "lighting": "soft"
  },
  "objects": [
    {"id": 1, "name": "couch", "score": 0.92, "bbox": [350, 420, 650, 720]},
    {"id": 2, "name": "chair", "score": 0.88, "bbox": [60, 440, 260, 740]},
    {"id": 3, "name": "lamp", "score": 0.85, "bbox": [760, 320, 920, 640]}
  ],
  "text": [
    {"string": "EXIT", "score": 0.9, "bbox": [400, 80, 550, 140]}
  ]
}
''';
    final obs = parser.parse(
      rawJson: sampleJson,
      inputWidth: 640,
      inputHeight: 480,
      processingDurationMs: 120,
      imageQuality: ImageQualityMetrics.nominal,
    );

    final desc = engine.build(obs);
    expect(desc.spokenSummary, contains('You appear to be in a living room'));
    expect(desc.spokenSummary, contains('Directly ahead of you is a couch.'));
    expect(desc.spokenSummary, contains('To your left, there is a chair.'));
    expect(desc.spokenSummary, contains('On your right, there is a lamp.'));
    expect(desc.spokenSummary, contains('Visible text reads: EXIT.'));
    expect(desc.spokenSummary, isNot(contains('Setting:')));
    expect(desc.spokenSummary, isNot(contains('(ahead)')));
  });

  test('OpenetraCoordinator persists continuous scene break interval and runs/stops continuous mode cleanly', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final deps = await OpenetraDependencies.bootstrap(
      database: db,
      enablePlatformTts: false,
    );

    await deps.coordinator.setContinuousSceneBreakSeconds(9);
    expect(deps.coordinator.continuousSceneBreakSeconds, 9);
    expect(await db.getAssistivePreference('continuous_scene_break_sec'), '9');

    await deps.coordinator.toggleContinuousSceneUnderstanding(
      breakDurationOverride: const Duration(milliseconds: 50),
    );
    expect(deps.coordinator.isContinuousSceneActive, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await deps.coordinator.toggleContinuousSceneUnderstanding();
    expect(deps.coordinator.isContinuousSceneActive, isFalse);
  });
}

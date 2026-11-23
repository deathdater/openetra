import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/assistive/assistive_action.dart';
import 'package:openetra/core/assistive/assistive_action_router.dart';
import 'package:openetra/core/assistive/custom_gesture_record.dart';
import 'package:openetra/core/assistive/permission_coordinator.dart';
import 'package:openetra/core/assistive/task_orchestrator.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/gestures/bloc/gesture_automation_bloc.dart';
import 'package:openetra/features/gestures/data/native_gesture_gateway.dart';
import 'package:openetra/features/gestures/domain/gesture_enrollment_engine.dart';
import 'package:openetra/features/gestures/domain/gesture_recognition_engine.dart';
import 'package:openetra/features/gestures/domain/hand_landmark_features.dart';
import 'package:openetra/features/gestures/presentation/gesture_automation_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a geometrically realistic 21x3 hand pose from per-finger extension
/// factors (`[thumb, index, middle, ring, pinky]` in `[0.0=curled .. 1.0=extended]`)
/// plus optional spread and orientation tweaks.
List<double> _buildHandPose({
  required List<double> ext,
  double spread = 1.0,
  double thumbOut = 0.0,
  double tx = 0.5,
  double ty = 0.7,
  double scale = 0.25,
  double jitter = 0.0,
  math.Random? rng,
}) {
  final pts = List<double>.filled(63, 0.0);
  void setPt(int idx, double x, double y, double z) {
    final jx = rng != null && jitter > 0 ? (rng.nextDouble() * 2 - 1) * jitter : 0.0;
    final jy = rng != null && jitter > 0 ? (rng.nextDouble() * 2 - 1) * jitter : 0.0;
    final jz = rng != null && jitter > 0 ? (rng.nextDouble() * 2 - 1) * jitter * 0.5 : 0.0;
    pts[idx * 3] = tx + (x + jx) * scale;
    pts[idx * 3 + 1] = ty + (y + jy) * scale;
    pts[idx * 3 + 2] = (z + jz) * scale;
  }

  // Wrist (0)
  setPt(0, 0.0, 0.0, 0.0);

  // Thumb (1..4): curled tucks across palm; extended points outward/upward.
  final tExt = ext[0];
  setPt(1, -0.22, -0.16, -0.02);
  if (tExt >= 0.5) {
    setPt(2, -0.38 - thumbOut * 0.14, -0.34 - tExt * 0.12, -0.04);
    setPt(3, -0.52 - thumbOut * 0.24, -0.54 - tExt * 0.26, -0.05);
    setPt(4, -0.64 - thumbOut * 0.34, -0.76 - tExt * 0.38, -0.05);
  } else {
    setPt(2, -0.20, -0.28, -0.08);
    setPt(3, -0.06, -0.34, -0.14);
    setPt(4, 0.08, -0.32, -0.16);
  }

  // Four fingers: index (5..8), middle (9..12), ring (13..16), pinky (17..20)
  const baseX = [-0.26, -0.08, 0.10, 0.28];
  const baseY = [-0.62, -0.68, -0.64, -0.54];
  for (var f = 0; f < 4; f++) {
    final e = ext[f + 1];
    final bx = baseX[f];
    final by = baseY[f];
    final s = (f - 1.5) * 0.12 * spread;
    final startIdx = 5 + f * 4;
    setPt(startIdx, bx, by, 0.0);
    if (e >= 0.5) {
      // Extended finger
      setPt(startIdx + 1, bx + s * 0.4, by - 0.28 * e, -0.01);
      setPt(startIdx + 2, bx + s * 0.75, by - 0.54 * e, -0.02);
      setPt(startIdx + 3, bx + s * 1.1, by - 0.78 * e, -0.02);
    } else {
      // Curled finger folding inward toward palm
      setPt(startIdx + 1, bx * 0.85, by - 0.12 * e, -0.08);
      setPt(startIdx + 2, bx * 0.65, by + 0.10, -0.14);
      setPt(startIdx + 3, bx * 0.55, by + 0.26, -0.12);
    }
  }
  return pts;
}

HandLandmarkFrame _frameFromPose(List<double> raw63, {double presence = 0.95}) {
  return HandLandmarkFrame(
    rawLandmarks63: raw63,
    handPresenceScore: presence,
    handednessScore: 0.9,
    inferenceMs: 12,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('Held-out gesture evaluation achieves >=95% precision, recall, and unknown rejection with translation/scale invariance', () {
    final rng = math.Random(42);
    const enrollment = GestureEnrollmentEngine();
    final recognition = GestureRecognitionEngine(requiredVotes: 1, windowSize: 1);

    final classDefs = <String, ({List<double> ext, double spread, double thumbOut, AssistiveActionId action})>{
      'open_palm': (ext: [1.0, 1.0, 1.0, 1.0, 1.0], spread: 1.4, thumbOut: 0.9, action: AssistiveActionId.cancelActiveTask),
      'peace_v': (ext: [0.1, 1.0, 1.0, 0.1, 0.1], spread: 1.6, thumbOut: 0.0, action: AssistiveActionId.describeScene),
      'closed_fist': (ext: [0.1, 0.1, 0.1, 0.1, 0.1], spread: 0.3, thumbOut: 0.0, action: AssistiveActionId.toggleFlashlight),
      'index_point': (ext: [0.1, 1.0, 0.1, 0.1, 0.1], spread: 0.6, thumbOut: 0.0, action: AssistiveActionId.readText),
      'thumbs_up': (ext: [1.0, 0.1, 0.1, 0.1, 0.1], spread: 0.3, thumbOut: 1.2, action: AssistiveActionId.assessHazardCues),
    };

    // Enrol 5 training samples per class.
    final enrolled = <CustomGestureRecord>[];
    for (final entry in classDefs.entries) {
      final samples = <List<double>>[];
      for (var s = 0; s < 5; s++) {
        final raw = _buildHandPose(
          ext: entry.value.ext,
          spread: entry.value.spread,
          thumbOut: entry.value.thumbOut,
          tx: 0.4 + rng.nextDouble() * 0.2,
          ty: 0.6 + rng.nextDouble() * 0.2,
          scale: 0.20 + rng.nextDouble() * 0.12,
          jitter: 0.015,
          rng: rng,
        );
        final res = enrollment.validateSample(_frameFromPose(raw));
        expect(res.accepted, isTrue);
        samples.add(res.featureVector!);
      }
      final fin = enrollment.finalizeEnrollment(
        id: entry.key,
        name: entry.key,
        actionId: entry.value.action,
        sampleVectors: samples,
        existingGestures: enrolled,
        threshold: 0.92,
      );
      expect(fin.accepted, isTrue, reason: fin.spokenFeedback);
      enrolled.add(fin.record!);
    }

    // Evaluate 20 held-out perturbed samples per enrolled class (100 positive).
    var tp = 0;
    var fn = 0;
    var fpOnKnown = 0;
    for (final entry in classDefs.entries) {
      for (var i = 0; i < 20; i++) {
        final raw = _buildHandPose(
          ext: entry.value.ext,
          spread: entry.value.spread,
          thumbOut: entry.value.thumbOut,
          tx: 0.2 + rng.nextDouble() * 0.6,
          ty: 0.3 + rng.nextDouble() * 0.5,
          scale: 0.15 + rng.nextDouble() * 0.22,
          jitter: 0.025,
          rng: rng,
        );
        recognition.reset();
        final out = recognition.evaluateFrame(_frameFromPose(raw), enrolled);
        if (out.status == GestureMatchStatus.matched &&
            out.matchedGesture?.id == entry.key) {
          tp++;
        } else if (out.status == GestureMatchStatus.matched) {
          fpOnKnown++;
        } else {
          fn++;
        }
      }
    }

    // Evaluate 60 unseen unknown/idle poses (must be rejected).
    final unknownDefs = [
      (ext: [0.1, 1.0, 0.1, 0.1, 1.0], spread: 1.4, thumbOut: 0.0), // horns
      (ext: [0.9, 0.1, 0.1, 0.1, 1.0], spread: 1.5, thumbOut: 1.0), // shaka
      (ext: [0.1, 1.0, 1.0, 1.0, 0.1], spread: 1.1, thumbOut: 0.0), // three fingers
    ];
    var unknownRejected = 0;
    var fpOnUnknown = 0;
    for (final u in unknownDefs) {
      for (var i = 0; i < 20; i++) {
        final raw = _buildHandPose(
          ext: u.ext,
          spread: u.spread,
          thumbOut: u.thumbOut,
          tx: 0.3 + rng.nextDouble() * 0.4,
          ty: 0.5 + rng.nextDouble() * 0.3,
          scale: 0.2 + rng.nextDouble() * 0.12,
          jitter: 0.02,
          rng: rng,
        );
        recognition.reset();
        final out = recognition.evaluateFrame(_frameFromPose(raw), enrolled);
        if (out.status != GestureMatchStatus.matched) {
          unknownRejected++;
        } else {
          fpOnUnknown++;
        }
      }
    }

    final totalFp = fpOnKnown + fpOnUnknown;
    final precision = tp / (tp + totalFp);
    final recall = tp / (tp + fn + fpOnKnown);
    final unknownRejectRate = unknownRejected / 60.0;
    final far = fpOnUnknown / 60.0;
    final frr = fn / 100.0;

    // Emit factual evaluation summary to test logs for documentation.
    // ignore: avoid_print
    print(
      'GESTURE_EVAL: TP=$tp/100 FP=$totalFp FN=$fn '
      'Precision=${(precision * 100).toStringAsFixed(1)}% '
      'Recall=${(recall * 100).toStringAsFixed(1)}% '
      'UnknownReject=${(unknownRejectRate * 100).toStringAsFixed(1)}% '
      'FAR=${(far * 100).toStringAsFixed(1)}% FRR=${(frr * 100).toStringAsFixed(1)}%',
    );

    expect(precision, greaterThanOrEqualTo(0.95));
    expect(recall, greaterThanOrEqualTo(0.95));
    expect(unknownRejectRate, greaterThanOrEqualTo(0.95));
  });

  test('GestureEnrollmentEngine rejects noisy samples and colliding gestures', () {
    const enrollment = GestureEnrollmentEngine();
    final palm = _buildHandPose(ext: [1, 1, 1, 1, 1], spread: 1.4, thumbOut: 0.9);
    final fist = _buildHandPose(ext: [0.1, 0.1, 0.1, 0.1, 0.1], spread: 0.3);

    // Low hand presence rejected.
    expect(
      enrollment.validateSample(_frameFromPose(palm, presence: 0.2)).accepted,
      isFalse,
    );

    // Mixed inconsistent samples (3 palm + 2 fist) rejected.
    final vPalm = HandLandmarkFeatureExtractor.extract(palm);
    final vFist = HandLandmarkFeatureExtractor.extract(fist);
    final noisy = enrollment.finalizeEnrollment(
      id: 'g-noisy',
      name: 'Noisy',
      actionId: AssistiveActionId.describeScene,
      sampleVectors: [vPalm, vPalm, vPalm, vFist, vFist],
      existingGestures: const [],
    );
    expect(noisy.accepted, isFalse);

    // Enrol valid palm, then attempt duplicate palm -> collision rejected.
    final valid = enrollment.finalizeEnrollment(
      id: 'g-palm',
      name: 'Open Palm',
      actionId: AssistiveActionId.cancelActiveTask,
      sampleVectors: List.filled(5, vPalm),
      existingGestures: const [],
    );
    expect(valid.accepted, isTrue);

    final colliding = enrollment.finalizeEnrollment(
      id: 'g-palm-dup',
      name: 'Duplicate Palm',
      actionId: AssistiveActionId.readText,
      sampleVectors: List.filled(5, vPalm),
      existingGestures: [valid.record!],
    );
    expect(colliding.accepted, isFalse);
    expect(colliding.spokenFeedback, contains('too similar'));
  });

  test('GestureAutomationBloc routes validated gestures via TaskOrchestrator and enforces emergency opt-in safeguard', () async {
    final tempDir = Directory.systemTemp.createTempSync('openetra_gest_test_');
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: p.join(tempDir.path, 'openetra.db'),
    );
    addTearDown(() async {
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final router = AssistiveActionRouter();
    final triggered = <(AssistiveActionId, String)>[];
    for (final id in [
      AssistiveActionId.describeScene,
      AssistiveActionId.startEmergencyAssistance,
    ]) {
      router.register(
        spec: AssistiveActionSpec(
          id: id,
          displayName: id.name,
          accessibleDescription: id.name,
          backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        ),
        handler: (ctx) async {
          triggered.add((id, ctx.sourceTrigger));
        },
      );
    }

    final perms = PermissionCoordinator(
      gateway: DefaultInMemoryPermissionGateway({
        OpenetraPermission.camera: PermissionGrantState.granted,
      }),
    );
    var fakeNow = DateTime(2026, 11, 23, 14, 0, 0);
    final orchestrator = TaskOrchestrator(
      router: router,
      availabilityService: CapabilityAvailabilityService(permissions: perms),
      clock: () => fakeNow,
    );
    final bloc = GestureAutomationBloc(
      gateway: FakeGestureGateway(),
      taskOrchestrator: orchestrator,
      database: db,
      recognitionEngine: GestureRecognitionEngine(clock: () => fakeNow),
    );
    addTearDown(() async {
      await bloc.close();
      await perms.dispose();
    });

    bloc.add(const LoadGestureConfig());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.isEnabled, isFalse);

    // Emergency gesture enrolment blocked until explicit opt-in is enabled.
    bloc.add(const StartGestureEnrollment(
      name: 'SOS Fist',
      actionId: AssistiveActionId.startEmergencyAssistance,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.isEnrolling, isFalse);

    // Enrol Peace sign for Describe Scene (5 samples).
    final peaceFrame = _frameFromPose(
      _buildHandPose(ext: [0.1, 1.0, 1.0, 0.1, 0.1], spread: 1.6),
    );
    bloc.add(const StartGestureEnrollment(
      name: 'Peace Sign',
      actionId: AssistiveActionId.describeScene,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 5; i++) {
      bloc.add(CaptureEnrollmentSample(syntheticFrame: peaceFrame));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(bloc.state.gestures.length, 1);

    // Enable gestures & start foreground listening.
    bloc.add(const SetGestureAutomationEnabled(true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(const StartForegroundGestureListening());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Temporal voting requires 3 consecutive frames before dispatching once.
    bloc.add(ProcessGestureLandmarkFrame(peaceFrame));
    bloc.add(ProcessGestureLandmarkFrame(peaceFrame));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(triggered, isEmpty);

    bloc.add(ProcessGestureLandmarkFrame(peaceFrame));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(triggered.length, 1);
    expect(triggered.single, (
      AssistiveActionId.describeScene,
      'custom_gesture',
    ));

    // Cooldown suppresses immediate re-trigger within 2000 ms.
    for (var i = 0; i < 3; i++) {
      bloc.add(ProcessGestureLandmarkFrame(peaceFrame));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(triggered.length, 1);

    // Advance clock past cooldown -> fires again cleanly.
    fakeNow = fakeNow.add(const Duration(seconds: 3));
    for (var i = 0; i < 3; i++) {
      bloc.add(ProcessGestureLandmarkFrame(peaceFrame));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(triggered.length, 2);

    // Explicit opt-in allows enrolling emergency gesture; disabling opt-in blocks execution.
    final fistFrame = _frameFromPose(
      _buildHandPose(ext: [0.1, 0.1, 0.1, 0.1, 0.1], spread: 0.3),
    );
    bloc.add(const SetEmergencyGestureOptIn(true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(const StartGestureEnrollment(
      name: 'Emergency Fist',
      actionId: AssistiveActionId.startEmergencyAssistance,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 5; i++) {
      bloc.add(CaptureEnrollmentSample(syntheticFrame: fistFrame));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(bloc.state.gestures.length, 2);

    // Disable opt-in -> matching fist must NOT trigger emergency action.
    bloc.add(const SetEmergencyGestureOptIn(false));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 3; i++) {
      bloc.add(ProcessGestureLandmarkFrame(fistFrame));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(
      triggered.where((e) => e.$1 == AssistiveActionId.startEmergencyAssistance),
      isEmpty,
    );

    // Re-enable opt-in -> fires emergency confirmation route cleanly.
    bloc.add(const SetEmergencyGestureOptIn(true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    fakeNow = fakeNow.add(const Duration(seconds: 5));
    for (var i = 0; i < 3; i++) {
      bloc.add(ProcessGestureLandmarkFrame(fistFrame));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(
      triggered.where((e) => e.$1 == AssistiveActionId.startEmergencyAssistance),
      hasLength(1),
    );
  });

  testWidgets('GestureAutomationScreen toggles opt-in and renders enrolment controls', (tester) async {
    final router = AssistiveActionRouter();
    final perms = PermissionCoordinator();
    final orchestrator = TaskOrchestrator(
      router: router,
      availabilityService: CapabilityAvailabilityService(permissions: perms),
    );
    final bloc = GestureAutomationBloc(
      gateway: FakeGestureGateway(),
      taskOrchestrator: orchestrator,
    );
    addTearDown(() async {
      await bloc.close();
      await perms.dispose();
    });

    await tester.pumpWidget(
      BlocProvider<GestureAutomationBloc>.value(
        value: bloc,
        child: const MaterialApp(home: GestureAutomationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom Hand Gestures: Disabled'), findsOneWidget);
    await tester.tap(find.text('Custom Hand Gestures: Disabled'));
    await tester.pumpAndSettle();
    expect(find.text('Custom Hand Gestures: Enabled'), findsOneWidget);
  });
}

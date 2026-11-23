import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/app.dart';
import 'package:openetra/core/audio/voice_intent_router.dart';
import 'package:openetra/core/camera/camera_controller_bridge.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/inference/specialist/native_specialist_providers.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/settings/presentation/settings_screen.dart';
import 'package:openetra/features/smart_reader/data/native_indic_ocr_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _StubVisionProvider implements VisionInferenceProvider {
  @override
  String get modelId => 'cactus-mirage-2bit';

  @override
  bool get isLoaded => true;

  @override
  Future<ModelPerformance> load({int threads = 0}) async {
    return ModelPerformance(
      modelId: modelId,
      measuredLatencyMs: 25,
      coldLoadMs: 10,
      inputWidth: 640,
      inputHeight: 480,
      recordedAt: DateTime(2026, 11, 23),
      deviceTier: 'test-host',
    );
  }

  @override
  Future<void> unload() async {}

  @override
  Future<VisionObservation> analyze(
    CapturedFrame frame, {
    required MirageQueryProfile profile,
    List<String>? keywords,
  }) async {
    return VisionObservation(
      provenance: ObservationProvenance(
        observationId: 'obs-v1-stub',
        timestamp: DateTime(2026, 11, 23),
        modelId: modelId,
        modelVersion: '4.1.4',
        confidence: 0.9,
        inputWidth: frame.width,
        inputHeight: frame.height,
        processingDurationMs: 25,
        sourceCapability: 'mirage',
        validationStatus: ValidationStatus.verified,
      ),
      imageQuality: ImageQualityMetrics.nominal,
      sceneMetadata: const {'setting': 'hallway'},
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'exit door',
          boundingBox: BoundingBox(x1: 350, y1: 120, x2: 650, y2: 880),
          confidence: 0.88,
        ),
        ObjectDetection(
          entityId: 2,
          name: 'keys',
          boundingBox: BoundingBox(x1: 200, y1: 500, x2: 340, y2: 650),
          confidence: 0.84,
        ),
      ],
    );
  }
}

class _StubCameraSource implements CameraSource {
  int stopCount = 0;

  @override
  Future<void> start({int minIntervalMs = 500}) async {}

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
      qualityMetrics: ImageQualityMetrics.nominal,
      rgbBytes: Uint8List(640 * 480 * 3),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  const ocrChannel = MethodChannel('com.openetra.app/indic_ocr');
  const specialistChannel = MethodChannel('com.openetra.app/specialist');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(ocrChannel, null);
    messenger.setMockMethodCallHandler(specialistChannel, null);
  });

  test('VoiceIntentRouter parses all 8 language switches and doorway follow-up cues', () {
    const router = VoiceIntentRouter();
    expect(router.parse('Switch language to Malayalam').type, VoiceIntentType.switchLanguage);
    expect(router.parse('Switch to Marathi').type, VoiceIntentType.switchLanguage);
    expect(router.parse('Change language to Bengali').type, VoiceIntentType.switchLanguage);
    expect(router.parse('Where is the exit door?').type, VoiceIntentType.followUpQuery);
    expect(router.parse('Any doorway nearby?').type, VoiceIntentType.followUpQuery);
    expect(router.parse('Any stairs ahead').type, VoiceIntentType.followUpQuery);
  });

  test('OpenetraCoordinator handles 8-locale switch, doorway cues, camera embedding save, and stopAll', () async {
    messenger.setMockMethodCallHandler(specialistChannel, (MethodCall call) async {
      if (call.method == 'computeCropEmbeddingRgb') {
        return {
          'embedding': List<double>.generate(96, (i) => i == 0 ? 1.0 : 0.0),
          'dimension': 96,
          'modelId': 'openetra-hsv-edge-embed96',
          'elapsedMs': 4,
        };
      }
      if (call.method == 'status') {
        return {
          'barcodeAvailable': true,
          'embeddingAvailable': true,
          'litertAvailable': true,
          'currencyModelLoaded': false,
          'depthModelLoaded': true,
        };
      }
      if (call.method == 'estimateCenterDepthRgb') {
        return {
          'available': true,
          'normalizedCenterDepth': 0.42,
          'isMetricCalibrated': false,
          'inferenceMs': 11,
        };
      }
      return null;
    });

    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final cam = _StubCameraSource();
    final deps = await OpenetraDependencies.bootstrap(
      database: db,
      visionProvider: _StubVisionProvider(),
      cameraSource: cam,
      enablePlatformTts: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final localeCases = {
      'switch to hindi': 'hi-IN',
      'switch to kannada': 'kn-IN',
      'switch to tamil': 'ta-IN',
      'switch to telugu': 'te-IN',
      'switch to malayalam': 'ml-IN',
      'switch to marathi': 'mr-IN',
      'switch to bengali': 'bn-IN',
      'switch to english': 'en-IN',
    };
    for (final entry in localeCases.entries) {
      await deps.coordinator.handleVoiceCommand(entry.key);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(deps.settingsBloc.state.preferences.preferredLanguage, entry.value);
    }

    await deps.coordinator.runDescribeSurroundings();
    await deps.coordinator.handleVoiceCommand('Where is the exit?');
    expect(
      deps.voiceAssistantBloc.state.lastResponse?.spokenText,
      contains('exit door'),
    );

    await deps.coordinator.registerPersonalObjectWithCamera('keys');
    final profiles = await db.listPersonalObjects();
    final keys = profiles.firstWhere((p) => p.name == 'keys');
    final vecs = await db.getObjectEmbeddings(keys.id);
    expect(vecs, hasLength(1));
    expect(vecs.single, hasLength(96));

    await deps.coordinator.stopAll();
    expect(deps.coordinator.isHazardLoopActive, isFalse);
    expect(cam.stopCount, greaterThanOrEqualTo(1));

    final depth = NativeDepthProvider();
    expect(await depth.isMetricCalibrated, isFalse);
    expect(await depth.isAvailable, isTrue);
    final centerVal = await depth.estimateNormalizedCenterDepth(await cam.captureFrame());
    expect(centerVal, closeTo(0.42, 1e-6));

    await db.close();
  });

  test('NativeIndicOcrProvider supports all 6 Indic scripts and Marathi mar fallback', () async {
    String? capturedTessLang;
    messenger.setMockMethodCallHandler(ocrChannel, (MethodCall call) async {
      if (call.method == 'checkInstalledPacks') {
        return {
          'devanagari': true,
          'kannada': true,
          'tamil': true,
          'telugu': true,
          'malayalam': true,
          'bengali': true,
        };
      }
      if (call.method == 'recognizeDevanagariMlKit') {
        return {'engine': 'mlkit-text-devanagari', 'inferenceMs': 15, 'fullText': '', 'lines': const []};
      }
      if (call.method == 'recognizeTesseract') {
        capturedTessLang = (call.arguments as Map)['langCode'] as String;
        return {
          'engine': 'tesseract-fast-$capturedTessLang',
          'inferenceMs': 20,
          'fullText': 'महाराष्ट्र 500',
          'lines': [
            {'text': 'महाराष्ट्र 500', 'bbox': [10, 10, 400, 100], 'confidence': 0.88},
          ],
        };
      }
      return null;
    });

    final ocr = NativeIndicOcrProvider();
    for (final script in const [
      DetectedScript.devanagari,
      DetectedScript.kannada,
      DetectedScript.tamil,
      DetectedScript.telugu,
      DetectedScript.malayalam,
      DetectedScript.bengali,
    ]) {
      expect(await ocr.isPackInstalled(script), isTrue);
    }

    final frame = CapturedFrame(
      width: 640,
      height: 480,
      capturedAt: DateTime(2026, 11, 23),
      qualityMetrics: ImageQualityMetrics.nominal,
      rgbBytes: Uint8List(640 * 480 * 3),
    );
    final mrRes = await ocr.recognize(
      frame,
      targetScript: DetectedScript.devanagari,
      targetLocale: 'mr-IN',
    );
    expect(capturedTessLang, 'mar');
    expect(mrRes.engineUsed, 'tesseract-fast-mar');

    await ocr.recognize(frame, targetScript: DetectedScript.tamil, targetLocale: 'ta-IN');
    expect(capturedTessLang, 'tam');
    await ocr.recognize(frame, targetScript: DetectedScript.telugu, targetLocale: 'te-IN');
    expect(capturedTessLang, 'tel');
    await ocr.recognize(frame, targetScript: DetectedScript.malayalam, targetLocale: 'ml-IN');
    expect(capturedTessLang, 'mal');
    await ocr.recognize(frame, targetScript: DetectedScript.bengali, targetLocale: 'bn-IN');
    expect(capturedTessLang, 'ben');
  });

  testWidgets('SettingsScreen confirms Delete All Personal Data before wiping SQLite', (tester) async {
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
      await db.upsertPersonalObject(
        PersonalObjectProfile(
          id: 'p-1',
          name: 'House Keys',
          category: 'essentials',
          createdAt: DateTime(2026, 11, 23),
          updatedAt: DateTime(2026, 11, 23),
        ),
      );
      deps = await OpenetraDependencies.bootstrap(
        database: db,
        visionProvider: _StubVisionProvider(),
        cameraSource: _StubCameraSource(),
        enablePlatformTts: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: deps.audioBloc),
          BlocProvider.value(value: deps.resourceBloc),
          BlocProvider.value(value: deps.settingsBloc),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final deleteFinder = find.text('Delete All Personal Data');
    await tester.scrollUntilVisible(deleteFinder, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(deleteFinder);
    await tester.pumpAndSettle();
    await tester.tap(deleteFinder);
    await tester.pumpAndSettle();

    expect(find.text('Delete All Personal Data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    late int countAfterCancel;
    await tester.runAsync(() async {
      countAfterCancel = (await db.listPersonalObjects()).length;
    });
    expect(countAfterCancel, 1);

    await tester.tap(deleteFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();

    late int countAfterConfirm;
    await tester.runAsync(() async {
      countAfterConfirm = (await db.listPersonalObjects()).length;
    });
    expect(countAfterConfirm, 0);

    await tester.runAsync(() => db.close());
  });
}

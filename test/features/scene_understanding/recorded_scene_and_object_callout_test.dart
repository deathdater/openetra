import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/app.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/scene_understanding/domain/recorded_scene_memory.dart';
import 'package:openetra/features/scene_understanding/domain/registered_object_scene_matcher.dart';
import 'package:openetra/features/scene_understanding/presentation/scene_memory_screen.dart';
import 'package:openetra/features/settings/bloc/settings_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _StubEmbeddingProvider implements EmbeddingProvider {
  _StubEmbeddingProvider(this.vector);
  final List<double> vector;

  @override
  String get modelId => 'stub-embed';

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<double>?> computeEmbedding(
    CapturedFrame frame,
    BoundingBox crop,
  ) async =>
      vector;
}

class _StubVisionProvider implements VisionInferenceProvider {
  _StubVisionProvider(this._observations);
  final List<VisionObservation> _observations;
  final List<List<String>?> capturedKeywords = [];
  int _idx = 0;

  @override
  String get modelId => 'stub-mirage';

  @override
  bool get isLoaded => true;

  @override
  Future<ModelPerformance> load({int threads = 0}) async => ModelPerformance(
        modelId: 'stub-mirage',
        measuredLatencyMs: 25,
        coldLoadMs: 10,
        inputWidth: 64,
        inputHeight: 64,
        deviceTier: 'test',
        recordedAt: DateTime(2026, 11, 23, 18, 0, 0),
      );

  @override
  Future<void> unload() async {}

  @override
  Future<VisionObservation> analyze(
    CapturedFrame frame, {
    required MirageQueryProfile profile,
    List<String>? keywords,
  }) async {
    capturedKeywords.add(keywords);
    final obs = _observations[_idx % _observations.length];
    _idx++;
    return obs;
  }
}

CapturedFrame _sampleFrame(String id) => CapturedFrame(
      width: 64,
      height: 64,
      capturedAt: DateTime(2026, 11, 23, 18, 0, 0),
      qualityMetrics: ImageQualityMetrics.nominal,
      rgbBytes: Uint8List(64 * 64 * 3),
    );

VisionObservation _sampleObservation({
  required String id,
  required String setting,
  required List<ObjectDetection> objects,
  List<PerceivedTextSpan> textSpans = const [],
}) {
  return VisionObservation(
    sceneMetadata: {'setting': setting, 'lighting': 'well lit'},
    objects: objects,
    textSpans: textSpans,
    imageQuality: ImageQualityMetrics.nominal,
    provenance: ObservationProvenance(
      observationId: id,
      timestamp: DateTime(2026, 11, 23, 18, 0, 0),
      modelId: 'stub-mirage',
      modelVersion: '1.0',
      confidence: 0.9,
      inputWidth: 64,
      inputHeight: 64,
      processingDurationMs: 25,
      sourceCapability: 'scene',
      validationStatus: ValidationStatus.verified,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('SQLite v4 recorded_scenes CRUD and deleteAllUserData wipe work offline', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final tables = await db.listTableNames();
    expect(tables, contains('recorded_scenes'));

    final now = DateTime(2026, 11, 23, 18, 0, 0);
    final rec = RecordedSceneRecord(
      id: 'scene-1',
      title: 'Living Room',
      environment: 'living room',
      lighting: 'well lit',
      items: const [
        RecordedSceneItem(name: 'chair', zone: 'ahead', confidence: 0.9),
        RecordedSceneItem(name: 'table', zone: 'left', confidence: 0.85),
      ],
      readableTexts: const ['Welcome'],
      recognizedRegisteredObjects: const [
        RecognizedRegisteredMatch(
          objectId: 'obj-1',
          objectName: 'wallet',
          zone: 'left',
          certainty: 0.92,
          matchedByEmbedding: true,
        ),
      ],
      customNote: 'Spare keys are in the top drawer.',
      frameCount: 4,
      createdAt: now,
      updatedAt: now,
    );

    await db.upsertRecordedScene(rec);
    var loaded = await db.listRecordedScenes();
    expect(loaded.length, 1);
    expect(loaded.first.title, 'Living Room');
    expect(loaded.first.recognizedRegisteredObjects.first.objectName, 'wallet');
    expect(loaded.first.customNote, 'Spare keys are in the top drawer.');

    await db.updateRecordedSceneNote(
      'scene-1',
      title: 'Front Hall',
      customNote: 'Wallet is on the side table.',
    );
    loaded = await db.listRecordedScenes();
    expect(loaded.first.title, 'Front Hall');
    expect(loaded.first.customNote, 'Wallet is on the side table.');

    await db.deleteAllUserData();
    loaded = await db.listRecordedScenes();
    expect(loaded, isEmpty);

    await db.close();
  });

  test('RecordedSceneAggregator fuses multi-frame observations and speaks breakdown + custom note in English, Hindi, Kannada, and Tamil', () {
    const aggregator = RecordedSceneAggregator();
    final obs1 = _sampleObservation(
      id: 'o1',
      setting: 'office',
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'desk',
          confidence: 0.90,
          boundingBox: BoundingBox(x1: 350, y1: 450, x2: 650, y2: 750),
        ),
        ObjectDetection(
          entityId: 2,
          name: 'chair',
          confidence: 0.78,
          boundingBox: BoundingBox(x1: 50, y1: 400, x2: 260, y2: 800),
        ),
      ],
      textSpans: const [
        PerceivedTextSpan(
          text: 'Quiet Zone',
          confidence: 0.88,
          boundingBox: BoundingBox(x1: 400, y1: 150, x2: 600, y2: 240),
        ),
      ],
    );
    final obs2 = _sampleObservation(
      id: 'o2',
      setting: 'office',
      objects: const [
        ObjectDetection(
          entityId: 3,
          name: 'desk',
          confidence: 0.95,
          boundingBox: BoundingBox(x1: 350, y1: 450, x2: 650, y2: 750),
        ),
        ObjectDetection(
          entityId: 4,
          name: 'door',
          confidence: 0.84,
          boundingBox: BoundingBox(x1: 760, y1: 200, x2: 960, y2: 900),
        ),
      ],
    );

    final record = aggregator.aggregate(
      id: 'agg-1',
      title: 'My Office',
      observations: [obs1, obs2],
      registeredMatches: const [
        RecognizedRegisteredMatch(
          objectId: 'reg-1',
          objectName: 'my bottle',
          zone: 'ahead',
          certainty: 0.91,
          matchedByEmbedding: true,
        ),
      ],
      customNote: 'Charger is behind the desk.',
    );

    expect(record.frameCount, 2);
    expect(record.environment, 'office');
    // Deduplicated desk keeping highest confidence 0.95
    expect(record.items.where((i) => i.name == 'desk').length, 1);
    expect(record.items.firstWhere((i) => i.name == 'desk').confidence, 0.95);

    final en = record.buildSpokenBreakdown('en-IN');
    expect(en, contains('My Office'));
    expect(en, contains('my bottle'));
    expect(en, contains('Charger is behind the desk.'));

    final hi = record.buildSpokenBreakdown('hi-IN');
    expect(hi, contains('कार्यालय'));
    expect(hi, contains('my bottle'));
    expect(hi, contains('आपका सहेजा गया नोट'));
    expect(hi, contains('Charger is behind the desk.'));

    final kn = record.buildSpokenBreakdown('kn-IN');
    expect(kn, contains('ಕಚೇರಿ'));
    expect(kn, contains('my bottle'));
    expect(kn, contains('ಟಿಪ್ಪಣಿ'));

    final ta = record.buildSpokenBreakdown('ta-IN');
    expect(ta, contains('அலுவலகம்'));
    expect(ta, contains('my bottle'));
    expect(ta, contains('குறிப்பு'));
  });

  test('RegisteredObjectSceneMatcher verifies visual embeddings (>=0.80) and high-confidence labels (>=0.72), rejecting low-certainty false positives', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final now = DateTime(2026, 11, 23, 18, 0, 0);

    // Profile 1: with saved 4-dim normalized embedding
    await db.upsertPersonalObject(
      PersonalObjectProfile(
        id: 'p-wallet',
        name: 'wallet',
        category: 'personal',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.saveObjectEmbedding(
      id: 'emb-1',
      objectId: 'p-wallet',
      modelId: 'stub-embed',
      vector: Float32List.fromList([1.0, 0.0, 0.0, 0.0]),
    );

    // Profile 2: label-only profile
    await db.upsertPersonalObject(
      PersonalObjectProfile(
        id: 'p-keys',
        name: 'keys',
        category: 'personal',
        createdAt: now,
        updatedAt: now,
      ),
    );

    const matcher = RegisteredObjectSceneMatcher();
    final obs = _sampleObservation(
      id: 'obs-match',
      setting: 'bedroom',
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'pouch',
          confidence: 0.65,
          boundingBox: BoundingBox(x1: 400, y1: 400, x2: 600, y2: 600),
        ),
        ObjectDetection(
          entityId: 2,
          name: 'keys',
          confidence: 0.82,
          boundingBox: BoundingBox(x1: 750, y1: 450, x2: 920, y2: 620),
        ),
      ],
    );

    // Matching visual vector -> matches both wallet (embedding) and keys (label >= 0.72)
    final matches = await matcher.matchInObservation(
      observation: obs,
      database: db,
      frame: _sampleFrame('f1'),
      embeddingProvider: _StubEmbeddingProvider([0.98, 0.1, 0.0, 0.0]),
    );
    expect(matches.map((m) => m.objectName), containsAll(['wallet', 'keys']));
    expect(
      matches.firstWhere((m) => m.objectName == 'wallet').matchedByEmbedding,
      isTrue,
    );

    // Verify last_seen_records updated
    final profiles = await db.listPersonalObjects();
    expect(
      profiles.firstWhere((p) => p.id == 'p-wallet').lastSeenSetting,
      'bedroom',
    );

    // Orthogonal visual vector & low-confidence label -> 0 matches
    final lowObs = _sampleObservation(
      id: 'obs-low',
      setting: 'bedroom',
      objects: const [
        ObjectDetection(
          entityId: 3,
          name: 'pouch',
          confidence: 0.65,
          boundingBox: BoundingBox(x1: 400, y1: 400, x2: 600, y2: 600),
        ),
        ObjectDetection(
          entityId: 4,
          name: 'keys',
          confidence: 0.50,
          boundingBox: BoundingBox(x1: 750, y1: 450, x2: 920, y2: 620),
        ),
      ],
    );
    final noMatches = await matcher.matchInObservation(
      observation: lowObs,
      database: db,
      frame: _sampleFrame('f2'),
      embeddingProvider: _StubEmbeddingProvider([0.0, 1.0, 0.0, 0.0]),
    );
    expect(noMatches, isEmpty);

    await db.close();
  });

  test('OpenetraCoordinator calls out registered items in live/continuous scenes and records multi-frame scene memories', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final now = DateTime(2026, 11, 23, 18, 0, 0);
    await db.upsertPersonalObject(
      PersonalObjectProfile(
        id: 'reg-keys',
        name: 'keys',
        category: 'personal',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final stubVision = _StubVisionProvider([
      _sampleObservation(
        id: 'v1',
        setting: 'kitchen',
        objects: const [
          ObjectDetection(
            entityId: 1,
            name: 'table',
            confidence: 0.88,
            boundingBox: BoundingBox(x1: 350, y1: 450, x2: 650, y2: 750),
          ),
          ObjectDetection(
            entityId: 2,
            name: 'keys',
            confidence: 0.85,
            boundingBox: BoundingBox(x1: 50, y1: 450, x2: 240, y2: 600),
          ),
        ],
      ),
    ]);

    final deps = await OpenetraDependencies.bootstrap(
      database: db,
      visionProvider: stubVision,
      enablePlatformTts: false,
    );

    // Live / continuous scene description calls out registered 'keys' in English
    await deps.coordinator.runDescribeSurroundings(
      overrideFrame: _sampleFrame('live-1'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final spokenEn = deps.voiceAssistantBloc.state.lastResponse?.spokenText ?? '';
    expect(spokenEn, contains('Your registered keys'));

    // Switch language to Hindi -> registered item callout is spoken in Hindi
    deps.settingsBloc.add(const UpdatePreferredLanguage('hi-IN'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await deps.coordinator.runDescribeSurroundings(
      overrideFrame: _sampleFrame('live-2'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final spokenHi = deps.voiceAssistantBloc.state.lastResponse?.spokenText ?? '';
    expect(spokenHi, contains('आपकी सहेजी गई वस्तु keys'));

    // Record multi-frame scene clip and verify persistence + Hindi spoken breakdown
    final saved = await deps.coordinator.recordAndSaveSceneClip(
      title: 'रसोई',
      customNote: 'चाबी बाईं तरफ है',
      overrideFrames: [_sampleFrame('r1'), _sampleFrame('r2')],
    );
    expect(saved.frameCount, 2);
    expect(saved.recognizedRegisteredObjects.first.objectName, 'keys');
    final allSaved = await deps.coordinator.listRecordedScenes();
    expect(allSaved.length, 1);

    final spokenRec = deps.voiceAssistantBloc.state.lastResponse?.spokenText ?? '';
    expect(spokenRec, contains('चाबी बाईं तरफ है'));

    await db.close();
  });

  testWidgets('SceneMemoryScreen displays saved scenes and lets user modify spoken note', (tester) async {
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
      final now = DateTime(2026, 11, 23, 18, 0, 0);
      await db.upsertRecordedScene(
        RecordedSceneRecord(
          id: 'ui-scene-1',
          title: 'Study Desk',
          environment: 'office',
          items: const [
            RecordedSceneItem(name: 'laptop', zone: 'ahead', confidence: 0.91),
          ],
          readableTexts: const [],
          recognizedRegisteredObjects: const [],
          customNote: 'Original note',
          frameCount: 4,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SceneMemoryScreen(coordinator: deps.coordinator),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();

    expect(find.text('Study Desk'), findsOneWidget);
    expect(find.text('Note: Original note'), findsOneWidget);

    await tester.ensureVisible(find.text('Modify Note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modify Note'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.last, 'Keys near window');
    await tester.tap(find.text('Save & Speak'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();

    expect(find.text('Note: Keys near window'), findsOneWidget);

    await tester.runAsync(() => db.close());
  });

  test('runFindRegisteredObjects scans all actual registered items (never hardcoded wallet) and strictly rejects absent/unrelated objects in live & continuous scenes', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final stubVision = _StubVisionProvider([
      _sampleObservation(
        id: 'v-flask',
        setting: 'living room',
        objects: const [
          ObjectDetection(
            entityId: 1,
            name: 'bottle',
            confidence: 0.80,
            boundingBox: BoundingBox(x1: 360, y1: 420, x2: 620, y2: 740),
          ),
          ObjectDetection(
            entityId: 2,
            name: 'glasses',
            confidence: 0.78,
            boundingBox: BoundingBox(x1: 720, y1: 450, x2: 920, y2: 650),
          ),
        ],
      ),
      _sampleObservation(
        id: 'v-absent',
        setting: 'hallway',
        objects: const [
          ObjectDetection(
            entityId: 3,
            name: 'chair',
            confidence: 0.92,
            boundingBox: BoundingBox(x1: 300, y1: 400, x2: 650, y2: 800),
          ),
          ObjectDetection(
            entityId: 4,
            name: 'door',
            confidence: 0.90,
            boundingBox: BoundingBox(x1: 700, y1: 200, x2: 950, y2: 900),
          ),
        ],
      ),
    ]);

    final deps = await OpenetraDependencies.bootstrap(
      database: db,
      visionProvider: stubVision,
      enablePlatformTts: false,
    );

    // 1. With zero registered objects, reports honestly without searching for 'wallet'
    await deps.coordinator.runFindRegisteredObjects(
      overrideFrame: _sampleFrame('empty-1'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final emptyMsg = deps.voiceAssistantBloc.state.lastResponse?.spokenText ?? '';
    expect(emptyMsg, contains('No personal objects are registered yet'));
    expect(emptyMsg.toLowerCase(), isNot(contains('wallet')));

    // 2. Register 'my water flask' and 'reading specs' (NOT wallet!)
    final now = DateTime(2026, 11, 23, 22, 30, 0);
    await db.upsertPersonalObject(
      PersonalObjectProfile(
        id: 'reg-flask',
        name: 'my water flask',
        category: 'personal',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.upsertPersonalObject(
      PersonalObjectProfile(
        id: 'reg-specs',
        name: 'reading specs',
        category: 'personal',
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 3. Find Registered Object (no argument) scans all registered items via synonyms
    await deps.coordinator.runFindRegisteredObjects(
      overrideFrame: _sampleFrame('find-all-1'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(stubVision.capturedKeywords.last, containsAll(['my water flask', 'reading specs']));
    final foundMsg = deps.voiceAssistantBloc.state.lastResponse?.spokenText ?? '';
    expect(foundMsg, contains('my water flask'));
    expect(foundMsg, contains('reading specs'));

    // 4. Scene WITHOUT registered items (only chair & door) MUST NOT falsely report them,
    // and general/continuous scene perception must keep keywords null to avoid VLM hallucination.
    await deps.coordinator.runDescribeSurroundings(
      overrideFrame: _sampleFrame('cont-absent'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(stubVision.capturedKeywords.last, isNull);
    final absentMsg = deps.voiceAssistantBloc.state.lastResponse?.spokenText ?? '';
    expect(absentMsg, isNot(contains('my water flask')));
    expect(absentMsg, isNot(contains('reading specs')));

    // 5. Even with an identical visual embedding vector, unrelated objects (chair/door)
    // must NEVER match a registered object!
    await db.saveObjectEmbedding(
      id: 'emb-flask',
      objectId: 'reg-flask',
      modelId: 'stub-embed',
      vector: Float32List.fromList([1.0, 0.0, 0.0, 0.0]),
    );
    const matcher = RegisteredObjectSceneMatcher();
    final falseMatches = await matcher.matchInObservation(
      observation: _sampleObservation(
        id: 'obs-chair-only',
        setting: 'hallway',
        objects: const [
          ObjectDetection(
            entityId: 9,
            name: 'chair',
            confidence: 0.95,
            boundingBox: BoundingBox(x1: 300, y1: 400, x2: 650, y2: 800),
          ),
        ],
      ),
      database: db,
      frame: _sampleFrame('f-chair'),
      embeddingProvider: _StubEmbeddingProvider([1.0, 0.0, 0.0, 0.0]),
    );
    expect(falseMatches, isEmpty);

    await db.close();
  });
}

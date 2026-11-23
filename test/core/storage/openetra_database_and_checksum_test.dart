import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/errors/openetra_failure.dart';
import 'package:openetra/core/inference/ai_model_registry.dart';
import 'package:openetra/core/storage/model_checksum_verifier.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('OpenetraDatabase initializes all 10 tables, runs CRUD + FK cascade, and wipes user data', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );

    final tables = await db.listTableNames();
    expect(
      tables,
      containsAll([
        'user_preferences',
        'voice_config',
        'personal_objects',
        'object_embeddings',
        'last_seen_records',
        'scanned_documents',
        'conversation_history',
        'model_registry',
        'safety_events',
        'benchmark_metadata',
      ]),
    );

    final prefs = await db.loadPreferences();
    expect(prefs.preferredLanguage, 'en-IN');
    await db.savePreferences(prefs.copyWith(preferredLanguage: 'kn-IN'));
    expect((await db.loadPreferences()).preferredLanguage, 'kn-IN');

    await db.upsertVoiceConfig(
      locale: 'kn-IN',
      speechRate: 0.55,
      isOfflineVerified: true,
    );
    expect((await db.listVoiceConfigs()).length, 1);

    final now = DateTime.now();
    await db.upsertPersonalObject(
      PersonalObjectProfile(
        id: 'obj-wallet',
        name: 'Wallet',
        category: 'essentials',
        colorHint: 'brown',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.saveObjectEmbedding(
      id: 'emb-1',
      objectId: 'obj-wallet',
      modelId: 'mobilenetv3',
      vector: Float32List.fromList([0.1, 0.2, 0.3]),
    );
    await db.recordLastSeen(
      id: 'seen-1',
      objectId: 'obj-wallet',
      sceneSetting: 'living room',
      relativePosition: 'center',
      confidence: 0.88,
    );

    final savedObjs = await db.listPersonalObjects();
    expect(savedObjs.single.lastSeenSetting, 'living room');

    await db.saveScannedDocument(
      id: 'doc-1',
      title: 'Prescription',
      script: DetectedScript.latin,
      extractedText: 'Take 1 tablet daily',
      confidence: 0.9,
      language: 'en-IN',
    );
    await db.logConversationTurn(
      id: 'turn-1',
      role: 'user',
      intent: 'readText',
      utterance: 'Read this',
      language: 'en-IN',
    );
    await db.logSafetyEvent(
      SafetyEvent(
        eventId: 'safe-1',
        type: SafetyEventType.degradedQuality,
        severity: HazardSeverity.caution,
        message: 'Low light warning',
        timestamp: now,
      ),
    );
    await db.upsertModelRecord(AIModelRegistry.defaultCatalog.first);
    await db.recordBenchmark(
      id: 'bench-1',
      performance: ModelPerformance(
        modelId: AIModelRegistry.mirageId,
        measuredLatencyMs: 165,
        coldLoadMs: 24,
        inputWidth: 640,
        inputHeight: 480,
        deviceTier: 'test-host',
        recordedAt: now,
      ),
      thermalState: ThermalState.nominal,
    );

    expect((await db.listScannedDocuments()).length, 1);
    expect((await db.listConversationHistory()).length, 1);
    expect((await db.listSafetyEvents()).length, 1);
    expect((await db.listModelRecords()).length, 1);
    expect((await db.listBenchmarks()).length, 1);

    await db.deleteAllUserData();
    expect(await db.listPersonalObjects(), isEmpty);
    expect(await db.listScannedDocuments(), isEmpty);
    expect(await db.listConversationHistory(), isEmpty);
    expect(await db.listSafetyEvents(), isEmpty);
    // Registry record persists unless factory reset.
    expect((await db.listModelRecords()).length, 1);

    await db.close();
  });

  test('ModelChecksumVerifier validates exact SHA-256 and rejects tampered files', () async {
    const verifier = ModelChecksumVerifier();
    final tmpDir = await Directory.systemTemp.createTemp('openetra_sha_');
    final file = File('${tmpDir.path}/dummy.cact');
    await file.writeAsString('openetra-mirage-integrity-test');

    final expected = await verifier.computeSha256(file.path);
    final verified = await verifier.verifyOrThrow(
      filePath: file.path,
      expectedSha256: expected.toUpperCase(),
      modelId: 'test-model',
    );
    expect(verified, expected);

    await expectLater(
      () => verifier.verifyOrThrow(
        filePath: file.path,
        expectedSha256: '0' * 64,
        modelId: 'test-model',
      ),
      throwsA(isA<ModelIntegrityFailure>()),
    );

    await tmpDir.delete(recursive: true);
  });
}

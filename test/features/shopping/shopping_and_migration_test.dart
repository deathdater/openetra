import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/shopping/data/sqlite_product_catalog.dart';
import 'package:openetra/features/shopping/domain/shopping_assistant_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

VisionObservation _productObs({
  List<PerceivedTextSpan> texts = const [],
  List<ObjectDetection> objects = const [],
}) {
  return VisionObservation(
    provenance: ObservationProvenance(
      observationId: 'obs-shop',
      timestamp: DateTime(2026, 11, 23),
      modelId: 'cactus-mirage-2bit',
      modelVersion: '4.1.4',
      confidence: 0.85,
      inputWidth: 640,
      inputHeight: 480,
      processingDurationMs: 110,
      sourceCapability: 'mirage',
      validationStatus: ValidationStatus.verified,
    ),
    imageQuality: ImageQualityMetrics.nominal,
    objects: objects,
    textSpans: texts,
  );
}

void main() {
  sqfliteFfiInit();

  test('SQLite v1->v2 migration preserves user rows, seeds 5 EAN-890 products, and retains builtin staples on wipe', () async {
    final tmpDir = Directory.systemTemp.createTempSync('openetra_v1_v2_');
    addTearDown(() {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });
    final dbPath = p.join(tmpDir.path, 'legacy_v1.db');

    // 1. Create a schema v1 database directly and populate user rows.
    final v1 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
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
          await db.insert('user_preferences', {
            'id': 1,
            'preferred_language': 'hi-IN',
            'operating_mode': 'balanced',
            'high_contrast': 1,
            'verbose_descriptions': 0,
            'onboarding_completed': 1,
            'safety_disclaimer_accepted': 1,
            'speech_rate': 0.55,
          });
          await db.insert('personal_objects', {
            'id': 'obj-keys-1',
            'name': 'Keys',
            'category': 'essentials',
            'color_hint': 'silver',
            'description': 'House bunch',
            'created_at_ms': 1700000000000,
            'updated_at_ms': 1700000000000,
          });
        },
      ),
    );
    await v1.close();

    // 2. Reopen via OpenetraDatabase (schema v2 upgrade).
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: dbPath,
    );

    final tables = await db.listTableNames();
    expect(tables, contains('local_products'));

    final prefs = await db.loadPreferences();
    expect(prefs.preferredLanguage, 'hi-IN');
    final objects = await db.listPersonalObjects();
    expect(objects.map((o) => o.name), contains('Keys'));

    final seeded = await db.listLocalProducts();
    expect(seeded.length, 5);
    expect(
      seeded.map((e) => e.barcode),
      containsAll([
        '8901058851234',
        '8901063092723',
        '8901725133719',
        '8901491101837',
        '8901030865442',
      ]),
    );

    await db.upsertLocalProduct(
      product: const LocalProductMatch(
        barcode: '8909999000011',
        productName: 'Filter Coffee',
        brand: 'Cothas',
        netQuantity: '200 g',
        category: 'beverages',
      ),
    );
    expect(
      (await db.lookupLocalProduct('8909999000011'))?.productName,
      'Filter Coffee',
    );

    // 3. Wipe user data -> user product & keys deleted, builtin_sample items kept.
    await db.deleteAllUserData();
    expect(await db.listPersonalObjects(), isEmpty);
    expect(await db.lookupLocalProduct('8909999000011'), isNull);
    expect((await db.listLocalProducts()).length, 5);
    expect(await db.lookupLocalProduct('8901058851234'), isNotNull);

    await db.close();
  });

  test('ShoppingAssistantService handles seeded barcode, unknown barcode, OCR, and visual fallback', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final service = ShoppingAssistantService(
      catalogLookup: SqliteProductCatalogLookup(db),
    );

    final hit = await service.identifyProduct(
      observation: _productObs(),
      detectedBarcode: '8901058851234',
    );
    expect(hit, contains('Maggi'));
    expect(hit, contains('Masala 2-Minute Noodles'));
    expect(hit, contains('70 g'));

    final unknown = await service.identifyProduct(
      observation: _productObs(),
      detectedBarcode: '8900000000000',
    );
    expect(unknown, contains('Barcode 8900000000000 detected'));
    expect(unknown, contains('no offline catalog entry exists locally'));

    final ocrFallback = await service.identifyProduct(
      observation: _productObs(
        texts: const [
          PerceivedTextSpan(
            text: 'Tata Salt 1kg',
            boundingBox: BoundingBox(x1: 100, y1: 100, x2: 500, y2: 200),
            confidence: 0.9,
          ),
        ],
      ),
    );
    expect(ocrFallback, 'Package text observed: Tata Salt 1kg.');

    final visualFallback = await service.identifyProduct(
      observation: _productObs(
        objects: const [
          ObjectDetection(
            entityId: 1,
            name: 'bottle',
            boundingBox: BoundingBox(x1: 300, y1: 200, x2: 600, y2: 800),
            confidence: 0.78,
          ),
        ],
      ),
    );
    expect(visualFallback, contains('Visual item looks like bottle'));
    expect(visualFallback, contains('78%'));

    await db.close();
  });
}

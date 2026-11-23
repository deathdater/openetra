import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/entities/entities.dart';
import '../errors/openetra_failure.dart';

/// User preferences snapshot stored offline in SQLite.
class UserPreferencesRecord {
  const UserPreferencesRecord({
    this.preferredLanguage = 'en-IN',
    this.operatingMode = OperatingMode.balanced,
    this.highContrast = true,
    this.verboseDescriptions = false,
    this.onboardingCompleted = false,
    this.safetyDisclaimerAccepted = false,
    this.speechRate = 0.52,
  });

  final String preferredLanguage;
  final OperatingMode operatingMode;
  final bool highContrast;
  final bool verboseDescriptions;
  final bool onboardingCompleted;
  final bool safetyDisclaimerAccepted;
  final double speechRate;

  UserPreferencesRecord copyWith({
    String? preferredLanguage,
    OperatingMode? operatingMode,
    bool? highContrast,
    bool? verboseDescriptions,
    bool? onboardingCompleted,
    bool? safetyDisclaimerAccepted,
    double? speechRate,
  }) {
    return UserPreferencesRecord(
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      operatingMode: operatingMode ?? this.operatingMode,
      highContrast: highContrast ?? this.highContrast,
      verboseDescriptions: verboseDescriptions ?? this.verboseDescriptions,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      safetyDisclaimerAccepted:
          safetyDisclaimerAccepted ?? this.safetyDisclaimerAccepted,
      speechRate: speechRate ?? this.speechRate,
    );
  }
}

/// Offline SQLite persistence layer covering all 10 required Openetra tables.
class OpenetraDatabase {
  OpenetraDatabase._(this._db);

  final Database _db;
  static const int schemaVersion = 1;

  /// Opens or creates the local database. Pass [factory] (e.g. sqflite_common_ffi)
  /// and [dbPath] (`inMemoryDatabasePath`) for deterministic host unit tests.
  static Future<OpenetraDatabase> open({
    DatabaseFactory? factory,
    String? dbPath,
  }) async {
    try {
      final dbFactory = factory ?? databaseFactory;
      final resolvedPath = dbPath ??
          p.join(await dbFactory.getDatabasesPath(), 'openetra.db');
      final db = await dbFactory.openDatabase(
        resolvedPath,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (database) async {
            await database.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (database, version) async {
            await _createSchema(database);
          },
        ),
      );
      return OpenetraDatabase._(db);
    } catch (e) {
      throw StorageFailure('Failed to open local SQLite database', cause: e);
    }
  }

  static Future<void> _createSchema(Database db) async {
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
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY (object_id) REFERENCES personal_objects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE last_seen_records (
        id TEXT PRIMARY KEY,
        object_id TEXT NOT NULL,
        scene_setting TEXT,
        relative_position TEXT,
        confidence REAL NOT NULL,
        seen_at_ms INTEGER NOT NULL,
        FOREIGN KEY (object_id) REFERENCES personal_objects(id) ON DELETE CASCADE
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
  }

  Future<List<String>> listTableNames() async {
    final rows = await _db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<UserPreferencesRecord> loadPreferences() async {
    final rows = await _db.query('user_preferences', where: 'id = 1');
    if (rows.isEmpty) {
      const defaults = UserPreferencesRecord();
      await savePreferences(defaults);
      return defaults;
    }
    final row = rows.first;
    final modeName = row['operating_mode'] as String;
    final mode = OperatingMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => OperatingMode.balanced,
    );
    return UserPreferencesRecord(
      preferredLanguage: row['preferred_language'] as String,
      operatingMode: mode,
      highContrast: (row['high_contrast'] as int) == 1,
      verboseDescriptions: (row['verbose_descriptions'] as int) == 1,
      onboardingCompleted: (row['onboarding_completed'] as int) == 1,
      safetyDisclaimerAccepted: (row['safety_disclaimer_accepted'] as int) == 1,
      speechRate: (row['speech_rate'] as num).toDouble(),
    );
  }

  Future<void> savePreferences(UserPreferencesRecord prefs) async {
    await _db.insert(
      'user_preferences',
      {
        'id': 1,
        'preferred_language': prefs.preferredLanguage,
        'operating_mode': prefs.operatingMode.name,
        'high_contrast': prefs.highContrast ? 1 : 0,
        'verbose_descriptions': prefs.verboseDescriptions ? 1 : 0,
        'onboarding_completed': prefs.onboardingCompleted ? 1 : 0,
        'safety_disclaimer_accepted': prefs.safetyDisclaimerAccepted ? 1 : 0,
        'speech_rate': prefs.speechRate,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertVoiceConfig({
    required String locale,
    required double speechRate,
    double pitch = 1.0,
    String? preferredVoiceName,
    required bool isOfflineVerified,
    bool bargeInEnabled = true,
  }) async {
    await _db.insert(
      'voice_config',
      {
        'locale': locale,
        'speech_rate': speechRate,
        'pitch': pitch,
        'preferred_voice_name': preferredVoiceName,
        'is_offline_verified': isOfflineVerified ? 1 : 0,
        'barge_in_enabled': bargeInEnabled ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listVoiceConfigs() =>
      _db.query('voice_config', orderBy: 'locale ASC');

  Future<void> upsertPersonalObject(PersonalObjectProfile profile) async {
    await _db.insert(
      'personal_objects',
      {
        'id': profile.id,
        'name': profile.name,
        'category': profile.category,
        'color_hint': profile.colorHint,
        'description': profile.description,
        'created_at_ms': profile.createdAt.millisecondsSinceEpoch,
        'updated_at_ms': profile.updatedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveObjectEmbedding({
    required String id,
    required String objectId,
    required String modelId,
    required Float32List vector,
  }) async {
    await _db.insert(
      'object_embeddings',
      {
        'id': id,
        'object_id': objectId,
        'model_id': modelId,
        'embedding_blob': vector.buffer.asUint8List(),
        'dimension': vector.length,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> recordLastSeen({
    required String id,
    required String objectId,
    required String sceneSetting,
    required String relativePosition,
    required double confidence,
    DateTime? seenAt,
  }) async {
    await _db.insert(
      'last_seen_records',
      {
        'id': id,
        'object_id': objectId,
        'scene_setting': sceneSetting,
        'relative_position': relativePosition,
        'confidence': confidence,
        'seen_at_ms': (seenAt ?? DateTime.now()).millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PersonalObjectProfile>> listPersonalObjects() async {
    final rows = await _db.rawQuery('''
      SELECT po.*,
             ls.scene_setting,
             ls.relative_position,
             ls.seen_at_ms
      FROM personal_objects po
      LEFT JOIN last_seen_records ls
        ON ls.object_id = po.id
       AND ls.seen_at_ms = (
         SELECT MAX(seen_at_ms) FROM last_seen_records WHERE object_id = po.id
       )
      ORDER BY po.updated_at_ms DESC
    ''');
    return rows.map((r) {
      final seenMs = r['seen_at_ms'] as int?;
      return PersonalObjectProfile(
        id: r['id'] as String,
        name: r['name'] as String,
        category: r['category'] as String,
        colorHint: r['color_hint'] as String?,
        description: r['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at_ms'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at_ms'] as int),
        lastSeenSetting: r['scene_setting'] as String?,
        lastSeenAt: seenMs != null
            ? DateTime.fromMillisecondsSinceEpoch(seenMs)
            : null,
      );
    }).toList();
  }

  Future<void> deletePersonalObject(String id) async {
    await _db.delete('personal_objects', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveScannedDocument({
    required String id,
    required String title,
    required DetectedScript script,
    required String extractedText,
    required double confidence,
    required String language,
  }) async {
    await _db.insert(
      'scanned_documents',
      {
        'id': id,
        'title': title,
        'detected_script': script.name,
        'extracted_text': extractedText,
        'confidence': confidence,
        'language': language,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listScannedDocuments() =>
      _db.query('scanned_documents', orderBy: 'created_at_ms DESC', limit: 50);

  Future<void> logConversationTurn({
    required String id,
    required String role,
    required String intent,
    required String utterance,
    required String language,
  }) async {
    await _db.insert(
      'conversation_history',
      {
        'id': id,
        'role': role,
        'intent': intent,
        'utterance': utterance,
        'language': language,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listConversationHistory({int limit = 40}) =>
      _db.query('conversation_history',
          orderBy: 'created_at_ms DESC', limit: limit);

  Future<void> upsertModelRecord(
    ModelMetadata model, {
    String? actualSha256,
    DateTime? verifiedAt,
  }) async {
    await _db.insert(
      'model_registry',
      {
        'model_id': model.modelId,
        'version': model.version,
        'task': model.supportedTasks.map((e) => e.name).join(','),
        'runtime': model.runtime.name,
        'file_path': model.localPath,
        'expected_sha256': model.expectedSha256,
        'actual_sha256': actualSha256,
        'verified_at_ms': verifiedAt?.millisecondsSinceEpoch,
        'status': model.status.name,
        'size_bytes': model.sizeBytes,
        'licence': model.licence,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listModelRecords() =>
      _db.query('model_registry', orderBy: 'model_id ASC');

  Future<void> logSafetyEvent(SafetyEvent event) async {
    await _db.insert(
      'safety_events',
      {
        'id': event.eventId,
        'event_type': event.type.name,
        'severity': event.severity.name,
        'message': event.message,
        'degraded_reason': event.degradedReason,
        'hazard_category': event.hazardCategory?.name,
        'created_at_ms': event.timestamp.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SafetyEvent>> listSafetyEvents({int limit = 50}) async {
    final rows = await _db.query('safety_events',
        orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map((r) {
      return SafetyEvent(
        eventId: r['id'] as String,
        type: SafetyEventType.values.firstWhere(
          (e) => e.name == r['event_type'],
          orElse: () => SafetyEventType.degradedQuality,
        ),
        severity: HazardSeverity.values.firstWhere(
          (s) => s.name == r['severity'],
          orElse: () => HazardSeverity.info,
        ),
        message: r['message'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(r['created_at_ms'] as int),
        degradedReason: r['degraded_reason'] as String?,
        hazardCategory: r['hazard_category'] == null
            ? null
            : HazardCategory.values.firstWhere(
                (c) => c.name == r['hazard_category'],
                orElse: () => HazardCategory.groundLevel,
              ),
      );
    }).toList();
  }

  Future<void> recordBenchmark({
    required String id,
    required ModelPerformance performance,
    required ThermalState thermalState,
  }) async {
    await _db.insert(
      'benchmark_metadata',
      {
        'id': id,
        'model_id': performance.modelId,
        'device_tier': performance.deviceTier,
        'input_width': performance.inputWidth,
        'input_height': performance.inputHeight,
        'cold_load_ms': performance.coldLoadMs,
        'inference_ms': performance.measuredLatencyMs,
        'thermal_state': thermalState.name,
        'recorded_at_ms': performance.recordedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listBenchmarks({int limit = 50}) =>
      _db.query('benchmark_metadata',
          orderBy: 'recorded_at_ms DESC', limit: limit);

  /// User-controlled atomic deletion of personal data, history, scanned docs, and safety logs.
  Future<void> deleteAllUserData() async {
    await _db.transaction((txn) async {
      await txn.delete('object_embeddings');
      await txn.delete('last_seen_records');
      await txn.delete('personal_objects');
      await txn.delete('scanned_documents');
      await txn.delete('conversation_history');
      await txn.delete('safety_events');
    });
  }

  Future<void> close() => _db.close();
}

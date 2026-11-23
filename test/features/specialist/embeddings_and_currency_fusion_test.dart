import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/inference/specialist/native_specialist_providers.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/currency/domain/currency_recognition_service.dart';
import 'package:openetra/features/object_memory/bloc/object_memory_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _CropStubEmbeddingProvider implements EmbeddingProvider {
  _CropStubEmbeddingProvider(this._resolver);

  final List<double>? Function(BoundingBox crop) _resolver;

  @override
  String get modelId => 'stub-embed-4d';

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<double>?> computeEmbedding(CapturedFrame frame, BoundingBox crop) async =>
      _resolver(crop);
}

CapturedFrame _dummyFrame() {
  return CapturedFrame(
    width: 640,
    height: 480,
    capturedAt: DateTime(2026, 11, 23),
    qualityMetrics: ImageQualityMetrics.nominal,
    rgbBytes: Uint8List(12),
  );
}

VisionObservation _baseObs({
  List<ObjectDetection> objects = const [],
  List<PerceivedTextSpan> texts = const [],
  Map<String, dynamic> formResult = const {},
}) {
  return VisionObservation(
    provenance: ObservationProvenance(
      observationId: 'obs-spec',
      timestamp: DateTime(2026, 11, 23),
      modelId: 'cactus-mirage-2bit',
      modelVersion: '4.1.4',
      confidence: 0.85,
      inputWidth: 640,
      inputHeight: 480,
      processingDurationMs: 120,
      sourceCapability: 'mirage',
      validationStatus: ValidationStatus.verified,
    ),
    imageQuality: ImageQualityMetrics.nominal,
    objects: objects,
    textSpans: texts,
    formResult: formResult,
  );
}

void main() {
  sqfliteFfiInit();

  test('cosineSimilarity handles identical, orthogonal, opposite, and invalid inputs', () {
    expect(cosineSimilarity([1, 0, 0], [1, 0, 0]), closeTo(1.0, 1e-6));
    expect(cosineSimilarity([1, 0, 0], [0, 1, 0]), closeTo(0.0, 1e-6));
    expect(cosineSimilarity([1, 2, -1], [-1, -2, 1]), closeTo(-1.0, 1e-6));
    expect(cosineSimilarity(const [], [1, 0]), 0.0);
    expect(cosineSimilarity([1, 0], [1, 0, 0]), 0.0);
  });

  test('ObjectMemoryBloc saves visual embedding and disambiguates multi-match finds at >=0.80 cosine', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final frame = _dummyFrame();
    final embedder = _CropStubEmbeddingProvider((crop) {
      // Sample crop or right candidate returns [1, 0, 0, 0]; left candidate returns [0, 1, 0, 0]
      if (crop.x1 >= 600) return const [0.99, 0.14, 0.0, 0.0];
      if (crop.x1 == 400) return const [1.0, 0.0, 0.0, 0.0];
      return const [0.0, 1.0, 0.0, 0.0];
    });
    final bloc = ObjectMemoryBloc(database: db, embeddingProvider: embedder);

    bloc.add(
      RegisterPersonalObject(
        name: 'bottle',
        sampleFrame: frame,
        sampleCrop: const BoundingBox(x1: 400, y1: 300, x2: 520, y2: 700),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(bloc.state.lastSearchResult, contains('visual appearance embedding offline'));
    final bottleProfile = bloc.state.profiles.firstWhere((p) => p.name == 'bottle');
    final stored = await db.getObjectEmbeddings(bottleProfile.id);
    expect(stored.length, 1);
    expect(stored.single.length, 4);

    final twoBottles = _baseObs(
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'bottle',
          boundingBox: BoundingBox(x1: 120, y1: 450, x2: 240, y2: 750),
          confidence: 0.80,
        ),
        ObjectDetection(
          entityId: 1,
          name: 'bottle',
          boundingBox: BoundingBox(x1: 700, y1: 450, x2: 840, y2: 750),
          confidence: 0.82,
        ),
      ],
    );
    bloc.add(FindPersonalObject('bottle', observation: twoBottles, frame: frame));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.lastSearchResult, contains('Found bottle in the right'));
    expect(bloc.state.lastSearchResult, contains('visual appearance similarity 99%'));

    // Low similarity (< 0.80) among multiple matches must still request disambiguation.
    final lowSimEmbedder = _CropStubEmbeddingProvider((crop) {
      if (crop.x1 == 250) return const [0.0, 0.0, 1.0, 0.0];
      return const [0.5, 0.0, 0.5, 0.0]; // cosine = 0.707 < 0.80
    });
    final mugBloc = ObjectMemoryBloc(database: db, embeddingProvider: lowSimEmbedder);
    mugBloc.add(
      RegisterPersonalObject(
        name: 'mug',
        sampleFrame: frame,
        sampleCrop: const BoundingBox(x1: 250, y1: 250, x2: 350, y2: 450),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    mugBloc.add(
      FindPersonalObject(
        'mug',
        frame: frame,
        observation: _baseObs(
          objects: const [
            ObjectDetection(
              entityId: 2,
              name: 'mug',
              boundingBox: BoundingBox(x1: 100, y1: 400, x2: 200, y2: 600),
              confidence: 0.75,
            ),
            ObjectDetection(
              entityId: 2,
              name: 'mug',
              boundingBox: BoundingBox(x1: 680, y1: 400, x2: 780, y2: 600),
              confidence: 0.74,
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(mugBloc.state.lastSearchResult, contains('2 possible matches for mug'));

    await mugBloc.close();
    await bloc.close();
    await db.close();
  });

  test('CurrencyRecognitionService fuses Mirage form output with OCR numerals and keeps counterfeit disclaimer', () async {
    const service = CurrencyRecognitionService();
    final frame = _dummyFrame();
    final formObs500 = _baseObs(
      formResult: const {
        'denomination': {
          'value': '500',
          'probabilities': {'500': 0.86, '200': 0.05, '-': 0.09},
        },
      },
    );

    final agreedEn = await service.identify(
      frame: frame,
      formObservation: formObs500,
      mirageObservation: _baseObs(
        texts: const [
          PerceivedTextSpan(
            text: '500',
            boundingBox: BoundingBox(x1: 200, y1: 200, x2: 350, y2: 290),
            confidence: 0.90,
          ),
        ],
      ),
      locale: 'en-IN',
    );
    expect(agreedEn.denomination, InrDenomination.inr500);
    expect(agreedEn.isUncertain, isFalse);
    expect(agreedEn.spokenAdvisory, contains('confirmed by printed number 500'));
    expect(
      agreedEn.spokenAdvisory,
      contains('cannot verify whether a currency note is genuine or counterfeit'),
    );

    final agreedHi = await service.identify(
      frame: frame,
      formObservation: formObs500,
      mirageObservation: _baseObs(
        texts: const [
          PerceivedTextSpan(
            text: '₹500',
            boundingBox: BoundingBox(x1: 200, y1: 200, x2: 350, y2: 290),
            confidence: 0.90,
          ),
        ],
      ),
      locale: 'hi-IN',
    );
    expect(agreedHi.denomination, InrDenomination.inr500);
    expect(agreedHi.isUncertain, isFalse);
    expect(agreedHi.spokenAdvisory, allOf(contains('500 रुपये'), contains('असली है या नकली')));

    final conflict = await service.identify(
      frame: frame,
      formObservation: formObs500,
      mirageObservation: _baseObs(
        texts: const [
          PerceivedTextSpan(
            text: '100',
            boundingBox: BoundingBox(x1: 200, y1: 200, x2: 350, y2: 290),
            confidence: 0.88,
          ),
        ],
      ),
    );
    expect(conflict.denomination, InrDenomination.uncertain);
    expect(conflict.isUncertain, isTrue);
    expect(conflict.spokenAdvisory, contains('Uncertain result'));
    expect(conflict.spokenAdvisory, contains('100'));

    final formOnly = await service.identify(
      frame: frame,
      formObservation: formObs500,
      mirageObservation: _baseObs(),
    );
    expect(formOnly.denomination, InrDenomination.inr500);
    expect(formOnly.isUncertain, isTrue);
  });
}

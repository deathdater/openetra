import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/currency/domain/currency_recognition_service.dart';
import 'package:openetra/features/object_memory/bloc/object_memory_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _StubCurrencyClassifier implements CurrencyClassifierProvider {
  _StubCurrencyClassifier(this.scores);
  final Map<InrDenomination, double> scores;

  @override
  Future<bool> get isAvailable async => true;

  @override
  String get modelId => 'inr-currency-mobilenetv3-int8';

  @override
  Future<Map<InrDenomination, double>> classifyNote(CapturedFrame frame) async =>
      scores;
}

VisionObservation _obsWithTextAndObjects({
  List<ObjectDetection> objects = const [],
  List<PerceivedTextSpan> texts = const [],
  String? setting,
}) {
  return VisionObservation(
    provenance: ObservationProvenance(
      observationId: 'obs-de',
      timestamp: DateTime(2026, 11, 23),
      modelId: 'cactus-mirage-2bit',
      modelVersion: '4.1.4',
      confidence: 0.8,
      inputWidth: 640,
      inputHeight: 480,
      processingDurationMs: 120,
      sourceCapability: 'mirage',
      validationStatus: ValidationStatus.verified,
    ),
    imageQuality: ImageQualityMetrics.nominal,
    sceneMetadata: setting != null ? {'setting': setting} : const {},
    objects: objects,
    textSpans: texts,
  );
}

void main() {
  sqfliteFfiInit();

  test('Workflow D disambiguates multiple matches and persists last-seen for unique match', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final bloc = ObjectMemoryBloc(database: db);

    bloc.add(const RegisterPersonalObject(name: 'wallet'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final multiObs = _obsWithTextAndObjects(
      setting: 'office',
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'wallet',
          boundingBox: BoundingBox(x1: 120, y1: 600, x2: 240, y2: 720),
          confidence: 0.72,
        ),
        ObjectDetection(
          entityId: 1,
          name: 'wallet',
          boundingBox: BoundingBox(x1: 720, y1: 600, x2: 860, y2: 720),
          confidence: 0.69,
        ),
      ],
    );

    bloc.add(FindPersonalObject('wallet', observation: multiObs));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.lastSearchResult, contains('2 possible matches'));
    expect(bloc.state.lastSearchResult, contains('left'));
    expect(bloc.state.lastSearchResult, contains('right'));

    final singleObs = _obsWithTextAndObjects(
      setting: 'kitchen table',
      objects: const [
        ObjectDetection(
          entityId: 1,
          name: 'wallet',
          boundingBox: BoundingBox(x1: 420, y1: 500, x2: 560, y2: 650),
          confidence: 0.84,
        ),
      ],
    );
    bloc.add(FindPersonalObject('wallet', observation: singleObs));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.lastSearchResult, contains('Found wallet in the center'));
    expect(bloc.state.profiles.single.lastSeenSetting, 'kitchen table');

    await bloc.close();
    await db.close();
  });

  test('Workflow E reports denomination, handles OCR disagreement uncertainty, and always refuses counterfeit claims', () async {
    final frame = CapturedFrame(
      width: 640,
      height: 480,
      capturedAt: DateTime(2026, 11, 23),
      qualityMetrics: ImageQualityMetrics.nominal,
    );

    final agreedService = CurrencyRecognitionService(
      classifier: _StubCurrencyClassifier({InrDenomination.inr500: 0.91}),
    );
    final resAgreed = await agreedService.identify(
      frame: frame,
      mirageObservation: _obsWithTextAndObjects(
        texts: const [
          PerceivedTextSpan(
            text: '500',
            boundingBox: BoundingBox(x1: 200, y1: 200, x2: 320, y2: 280),
            confidence: 0.88,
          ),
        ],
      ),
    );
    expect(resAgreed.denomination, InrDenomination.inr500);
    expect(resAgreed.isUncertain, isFalse);
    expect(resAgreed.spokenAdvisory, contains('500 rupees'));
    expect(resAgreed.spokenAdvisory, contains('cannot verify whether a currency note is genuine or counterfeit'));

    // Classifier vs OCR disagreement forces uncertain warning.
    final resConflict = await agreedService.identify(
      frame: frame,
      mirageObservation: _obsWithTextAndObjects(
        texts: const [
          PerceivedTextSpan(
            text: '100',
            boundingBox: BoundingBox(x1: 200, y1: 200, x2: 320, y2: 280),
            confidence: 0.86,
          ),
        ],
      ),
    );
    expect(resConflict.isUncertain, isTrue);
    expect(resConflict.spokenAdvisory, contains('Uncertain result'));

    // OCR-only fallback without specialist classifier marks provisional/uncertain.
    const ocrOnlyService = CurrencyRecognitionService();
    final resOcrOnly = await ocrOnlyService.identify(
      frame: frame,
      mirageObservation: _obsWithTextAndObjects(
        texts: const [
          PerceivedTextSpan(
            text: '₹200',
            boundingBox: BoundingBox(x1: 200, y1: 200, x2: 320, y2: 280),
            confidence: 0.80,
          ),
        ],
      ),
    );
    expect(resOcrOnly.denomination, InrDenomination.inr200);
    expect(resOcrOnly.isUncertain, isTrue);
    expect(resOcrOnly.spokenAdvisory, contains('without dedicated banknote classifier'));
  });
}

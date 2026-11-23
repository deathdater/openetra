import 'dart:typed_data';
import '../domain/entities/entities.dart';

/// Camera or test-fixture RGB24 frame passed into inference providers.
class CapturedFrame {
  const CapturedFrame({
    required this.width,
    required this.height,
    required this.capturedAt,
    required this.qualityMetrics,
    this.rgbBytes,
    this.imageFilePath,
    this.cameraPitchDegrees,
  });

  final int width;
  final int height;
  final DateTime capturedAt;
  final ImageQualityMetrics qualityMetrics;
  final Uint8List? rgbBytes;
  final String? imageFilePath;
  final double? cameraPitchDegrees;
}

/// Selective Mirage request profile minimizing latency and power per operating mode.
class MirageQueryProfile {
  const MirageQueryProfile({
    required this.sections,
    this.fields = const ['bbox', 'score', 'position', 'description'],
    this.conf = 0.30,
    this.textConf = 0.45,
    this.maxObjects = 24,
    this.maxTextLines = 16,
    this.maxTokens = 384,
    this.maskFormat,
    this.formSchema,
    this.language = 'en',
  });

  final List<String> sections;
  final List<String> fields;
  final double conf;
  final double textConf;
  final int maxObjects;
  final int maxTextLines;
  final int maxTokens;
  final MaskFormat? maskFormat;
  final Map<String, dynamic>? formSchema;
  final String language;

  /// Valid Mirage sections (empirically verified against Cactus 4.1.4).
  static const allowedSections = {
    'scene',
    'objects',
    'regions',
    'text',
    'relations',
    'events',
    'reasoning',
  };

  /// Valid Mirage object fields (note: "attributes" is NOT valid; use "description").
  static const allowedFields = {
    'bbox',
    'score',
    'mask',
    'position',
    'description',
  };

  Map<String, dynamic> toOptionsJson() {
    if (formSchema != null) {
      return {'form': formSchema};
    }
    final validSections = sections.where(allowedSections.contains).toList();
    final validFields = fields.where(allowedFields.contains).toList();
    final map = <String, dynamic>{
      'sections': validSections,
      if (validSections.contains('objects')) 'fields': validFields,
      'conf': conf,
      'text_conf': textConf,
      'max_objects': maxObjects,
      'max_text_lines': maxTextLines,
      'max_tokens': maxTokens,
    };
    if (maskFormat != null && validFields.contains('mask')) {
      map['mask_format'] = maskFormat!.name;
    }
    return map;
  }

  static const MirageQueryProfile sceneBalanced = MirageQueryProfile(
    sections: ['scene', 'objects', 'relations', 'events', 'text'],
    fields: ['bbox', 'score', 'position', 'description'],
    maxObjects: 24,
    maxTokens: 384,
  );

  static const MirageQueryProfile sceneEco = MirageQueryProfile(
    sections: ['scene', 'objects'],
    fields: ['bbox', 'score', 'position'],
    maxObjects: 12,
    maxTokens: 200,
  );

  static const MirageQueryProfile hazardScan = MirageQueryProfile(
    sections: ['objects', 'regions', 'text'],
    fields: ['bbox', 'score', 'position', 'description'],
    conf: 0.25,
    maxObjects: 20,
    maxTokens: 320,
  );

  static const MirageQueryProfile latinOcr = MirageQueryProfile(
    sections: ['text'],
    fields: ['bbox', 'score'],
    textConf: 0.35,
    maxTextLines: 32,
    maxTokens: 384,
  );

  static const MirageQueryProfile objectSearch = MirageQueryProfile(
    sections: ['objects', 'scene'],
    fields: ['bbox', 'score', 'position', 'description'],
    conf: 0.25,
    maxObjects: 25,
    maxTokens: 280,
  );
}

/// Primary visual perception provider contract (Mirage or replaceable engine).
abstract class VisionInferenceProvider {
  String get modelId;
  bool get isLoaded;

  Future<ModelPerformance> load({int threads = 0});
  Future<void> unload();
  Future<VisionObservation> analyze(
    CapturedFrame frame, {
    required MirageQueryProfile profile,
    List<String>? keywords,
  });
}

/// Replaceable OCR provider (Mirage Latin, PaddleOCR PP-OCRv5 Indic, Tesseract).
abstract class OcrProvider {
  String get providerId;
  List<DetectedScript> get supportedScripts;
  Future<bool> isPackInstalled(DetectedScript script);
  Future<TextRecognitionResult> recognize(
    CapturedFrame frame, {
    required DetectedScript targetScript,
    required String targetLocale,
  });
}

/// Replaceable offline ASR provider (e.g. IndicConformer via sherpa-onnx).
abstract class AsrProvider {
  String get providerId;
  List<String> get supportedLocales;
  Future<bool> isLocalePackAvailable(String locale);
  Future<SpeechRecognitionResult> transcribePcm16k(
    List<double> samples, {
    required String locale,
  });
}

/// Replaceable offline TTS provider with explicit offline voice check.
abstract class TtsProvider {
  Future<bool> isOfflineVoiceAvailable(String locale);
  Future<List<String>> listOfflineLocales();
  Future<void> speak(
    String text, {
    required String locale,
    required double speechRate,
  });
  Future<void> stop();
}

/// Replaceable specialist Indian currency note classifier.
abstract class CurrencyClassifierProvider {
  String get modelId;
  Future<bool> get isAvailable;
  Future<Map<InrDenomination, double>> classifyNote(CapturedFrame frame);
}

/// Replaceable specialist monocular depth estimator.
abstract class DepthProvider {
  String get modelId;
  Future<bool> get isAvailable;
  Future<bool> get isMetricCalibrated;
  Future<double?> estimateNormalizedCenterDepth(CapturedFrame frame);
}

/// Replaceable visual embedding provider for personal object matching.
abstract class EmbeddingProvider {
  String get modelId;
  Future<bool> get isAvailable;
  Future<List<double>?> computeEmbedding(CapturedFrame frame, BoundingBox crop);
}

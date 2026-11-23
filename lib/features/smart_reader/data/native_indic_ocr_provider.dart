import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/entities/entities.dart';
import '../../../core/inference/model_provider.dart';
import '../../../core/errors/openetra_failure.dart';
import '../domain/script_detector.dart';

/// Native Android Indic OCR provider bridging to bundled ML Kit Devanagari OCR
/// (16.0.1) and Tesseract 4.9.0 (`hin.traineddata`, `kan.traineddata`, and
/// optional language packs) via MethodChannel `com.openetra.app/indic_ocr`.
class NativeIndicOcrProvider implements OcrProvider {
  NativeIndicOcrProvider({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.openetra.app/indic_ocr');

  final MethodChannel _channel;
  static const _uuid = Uuid();

  @override
  String get providerId => 'openetra-indic-ocr';

  @override
  List<DetectedScript> get supportedScripts => const [
        DetectedScript.devanagari,
        DetectedScript.kannada,
        DetectedScript.tamil,
        DetectedScript.telugu,
        DetectedScript.malayalam,
        DetectedScript.bengali,
      ];

  @override
  Future<bool> isPackInstalled(DetectedScript script) async {
    try {
      final packs = await _channel.invokeMapMethod<String, bool>('checkInstalledPacks');
      if (packs == null) return false;
      return packs[script.name] ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<TextRecognitionResult> recognize(
    CapturedFrame frame, {
    required DetectedScript targetScript,
    required String targetLocale,
  }) async {
    final rgb = frame.rgbBytes;
    if (rgb == null || frame.width <= 0 || frame.height <= 0) {
      throw const InferenceFailure('Indic OCR requires RGB frame bytes and positive dimensions');
    }

    final sw = Stopwatch()..start();
    Map<String, dynamic>? raw;
    try {
      if (targetScript == DetectedScript.devanagari) {
        raw = await _channel.invokeMapMethod<String, dynamic>(
          'recognizeDevanagariMlKit',
          {'rgbBytes': rgb, 'width': frame.width, 'height': frame.height},
        );
        final mlText = (raw?['fullText'] as String?)?.trim() ?? '';
        if (mlText.isEmpty) {
          raw = await _channel.invokeMapMethod<String, dynamic>(
            'recognizeTesseract',
            {
              'rgbBytes': rgb,
              'width': frame.width,
              'height': frame.height,
              'langCode': 'hin',
            },
          );
        }
      } else {
        final langCode = _tessLangForScript(targetScript);
        raw = await _channel.invokeMapMethod<String, dynamic>(
          'recognizeTesseract',
          {
            'rgbBytes': rgb,
            'width': frame.width,
            'height': frame.height,
            'langCode': langCode,
          },
        );
      }
    } on PlatformException catch (e) {
      throw InferenceFailure(e.message ?? 'Indic OCR failed', cause: e);
    } on MissingPluginException catch (e) {
      throw ModelNotLoadedFailure('Indic OCR bridge unavailable on host', cause: e);
    }
    sw.stop();

    final rawLines = (raw?['lines'] as List?) ?? const [];
    const detector = ScriptDetector();
    final lines = <TextLineObservation>[];
    for (final item in rawLines) {
      if (item is! Map) continue;
      final text = (item['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final bboxList = item['bbox'] is List ? item['bbox'] as List : const [];
      final conf = ((item['confidence'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0);
      final detected = detector.detectFromText(text);
      lines.add(
        TextLineObservation(
          text: text,
          boundingBox: BoundingBox.fromList(bboxList),
          confidence: conf,
          script: detected == DetectedScript.unknown ? targetScript : detected,
        ),
      );
    }

    final engine = (raw?['engine'] as String?) ?? providerId;
    final fullText = ((raw?['fullText'] as String?) ?? '').trim().isNotEmpty
        ? (raw!['fullText'] as String).trim()
        : lines.map((l) => l.text).join(' ');
    final avgConf = lines.isEmpty
        ? 0.0
        : lines.map((l) => l.confidence).reduce((a, b) => a + b) / lines.length;
    final infMs = (raw?['inferenceMs'] as num?)?.toInt() ?? sw.elapsedMilliseconds;

    return TextRecognitionResult(
      provenance: ObservationProvenance(
        observationId: _uuid.v4(),
        timestamp: DateTime.now(),
        modelId: engine,
        modelVersion: 'bundled',
        confidence: avgConf,
        inputWidth: frame.width,
        inputHeight: frame.height,
        processingDurationMs: infMs,
        sourceCapability: 'indic_ocr',
        validationStatus: lines.isEmpty
            ? ValidationStatus.uncertain
            : ValidationStatus.verified,
      ),
      detectedScript: targetScript,
      orderedLines: lines,
      fullText: fullText,
      targetLocale: targetLocale,
      engineUsed: engine,
      packAvailable: true,
    );
  }

  static String _tessLangForScript(DetectedScript script) {
    return switch (script) {
      DetectedScript.devanagari => 'hin',
      DetectedScript.kannada => 'kan',
      DetectedScript.tamil => 'tam',
      DetectedScript.telugu => 'tel',
      DetectedScript.malayalam => 'mal',
      DetectedScript.bengali => 'ben',
      _ => 'eng',
    };
  }
}

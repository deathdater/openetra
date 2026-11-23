import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/audio/native_offline_asr_provider.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/errors/openetra_failure.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/features/smart_reader/data/native_indic_ocr_provider.dart';

CapturedFrame _rgbFrame() {
  return CapturedFrame(
    width: 640,
    height: 480,
    capturedAt: DateTime(2026, 11, 23),
    qualityMetrics: ImageQualityMetrics.nominal,
    rgbBytes: Uint8List(640 * 480 * 3),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ocrChannel = MethodChannel('com.openetra.app/indic_ocr');
  const speechChannel = MethodChannel('com.openetra.app/speech');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(ocrChannel, null);
    messenger.setMockMethodCallHandler(speechChannel, null);
  });

  group('NativeIndicOcrProvider channel contract', () {
    test('checks installed packs and routes Devanagari ML Kit -> Tesseract fallback + Kannada Tesseract', () async {
      final calls = <String>[];
      var mlKitReturnsEmpty = false;

      messenger.setMockMethodCallHandler(ocrChannel, (MethodCall call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'checkInstalledPacks':
            return {
              'devanagari': true,
              'kannada': true,
              'tamil': false,
            };
          case 'recognizeDevanagariMlKit':
            if (mlKitReturnsEmpty) {
              return {'engine': 'mlkit-text-devanagari', 'inferenceMs': 18, 'fullText': '', 'lines': const []};
            }
            return {
              'engine': 'mlkit-text-devanagari',
              'inferenceMs': 35,
              'fullText': 'नमस्ते निकास',
              'lines': [
                {
                  'text': 'नमस्ते निकास',
                  'bbox': [100, 120, 620, 210],
                  'confidence': 0.92,
                },
              ],
            };
          case 'recognizeTesseract':
            final lang = (call.arguments as Map)['langCode'] as String;
            if (lang == 'hin') {
              return {
                'engine': 'tesseract-fast-hin',
                'inferenceMs': 140,
                'fullText': 'सावधान निकास',
                'lines': [
                  {'text': 'सावधान निकास', 'bbox': [50, 60, 500, 150], 'confidence': 0.81},
                ],
              };
            }
            return {
              'engine': 'tesseract-fast-$lang',
              'inferenceMs': 160,
              'fullText': 'ಬೆಂಗಳೂರು 500',
              'lines': [
                {'text': 'ಬೆಂಗಳೂರು 500', 'bbox': [80, 90, 600, 200], 'confidence': 0.84},
              ],
            };
          default:
            return null;
        }
      });

      final provider = NativeIndicOcrProvider();
      expect(await provider.isPackInstalled(DetectedScript.devanagari), isTrue);
      expect(await provider.isPackInstalled(DetectedScript.kannada), isTrue);
      expect(await provider.isPackInstalled(DetectedScript.tamil), isFalse);

      final mlRes = await provider.recognize(
        _rgbFrame(),
        targetScript: DetectedScript.devanagari,
        targetLocale: 'hi-IN',
      );
      expect(mlRes.engineUsed, 'mlkit-text-devanagari');
      expect(mlRes.fullText, 'नमस्ते निकास');
      expect(mlRes.orderedLines.single.boundingBox, const BoundingBox(x1: 100, y1: 120, x2: 620, y2: 210));

      mlKitReturnsEmpty = true;
      final tessHiRes = await provider.recognize(
        _rgbFrame(),
        targetScript: DetectedScript.devanagari,
        targetLocale: 'hi-IN',
      );
      expect(tessHiRes.engineUsed, 'tesseract-fast-hin');
      expect(tessHiRes.fullText, 'सावधान निकास');

      final tessKnRes = await provider.recognize(
        _rgbFrame(),
        targetScript: DetectedScript.kannada,
        targetLocale: 'kn-IN',
      );
      expect(tessKnRes.engineUsed, 'tesseract-fast-kan');
      expect(tessKnRes.detectedScript, DetectedScript.kannada);
      expect(tessKnRes.orderedLines.single.text, 'ಬೆಂಗಳೂರು 500');
      expect(tessKnRes.orderedLines.single.confidence, closeTo(0.84, 1e-6));
      expect(calls, containsAllInOrder(['recognizeDevanagariMlKit', 'recognizeDevanagariMlKit', 'recognizeTesseract', 'recognizeTesseract']));
    });
  });

  group('NativeOfflineAsrProvider channel contract', () {
    test('handles VAD, speech segmentation, pack availability, intent parsing, and PlatformException mapping', () async {
      messenger.setMockMethodCallHandler(speechChannel, (MethodCall call) async {
        switch (call.method) {
          case 'initVad':
            return {'vadInitialized': true};
          case 'detectSpeechSegments':
            return {'speechDetected': true, 'segmentCount': 1, 'speechSampleCount': 8192, 'vadMs': 12};
          case 'status':
            final loc = (call.arguments as Map)['locale'] as String;
            return {
              'vadReady': true,
              'asrPackLoaded': loc == 'hi-IN',
              'osOnDeviceSpeechAvailable': loc == 'en-IN',
            };
          case 'transcribePcm16k':
            return {
              'transcript': 'describe surroundings',
              'engine': 'sherpa-onnx-indicconformer',
              'inferenceMs': 95,
            };
          case 'recordAndRecognizeOffline':
            throw PlatformException(code: 'MIC_PERMISSION', message: 'Microphone denied');
          case 'loadAsrPack':
            throw PlatformException(code: 'INTEGRITY_ERROR', message: 'Checksum mismatch');
          default:
            return null;
        }
      });

      final asr = NativeOfflineAsrProvider();
      expect(await asr.initVad(), isTrue);

      final segs = await asr.detectSpeechSegments(const [0.0, 0.2, -0.3]);
      expect(segs['speechDetected'], isTrue);
      expect(segs['segmentCount'], 1);

      expect(await asr.isLocalePackAvailable('hi-IN'), isTrue);
      expect(await asr.isLocalePackAvailable('en-IN'), isTrue);
      expect(await asr.isLocalePackAvailable('kn-IN'), isFalse);

      final parsed = await asr.transcribePcm16k(List<double>.filled(1600, 0.0), locale: 'en-IN');
      expect(parsed.transcript, 'describe surroundings');
      expect(parsed.intent.type, VoiceIntentType.describeSurroundings);
      expect(parsed.isOfflineEngine, isTrue);

      await expectLater(
        () => asr.recordAndRecognizeOffline(locale: 'en-IN'),
        throwsA(isA<PermissionFailure>()),
      );

      await expectLater(
        () => asr.loadPack(
          locale: 'hi-IN',
          modelPath: '/tmp/m.onnx',
          tokensPath: '/tmp/tokens.txt',
          expectedSha256: 'deadbeef',
        ),
        throwsA(isA<ModelIntegrityFailure>()),
      );
    });
  });
}

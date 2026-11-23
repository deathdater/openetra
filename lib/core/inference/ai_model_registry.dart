import '../domain/entities/entities.dart';

/// Central model catalog containing verified pins, sizes, licences, and compatibility.
class AIModelRegistry {
  AIModelRegistry({List<ModelMetadata>? initialModels}) {
    for (final m in initialModels ?? defaultCatalog) {
      _models[m.modelId] = m;
    }
  }

  final Map<String, ModelMetadata> _models = {};

  static const String mirageId = 'cactus-mirage-2bit';
  static const String mirageRevision = '76c1e9e53381aca8fc3843c636216c96ff220122';
  static const String mirageSha256 =
      '4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237';
  static const int mirageSizeBytes = 21611043;

  static const String tessHinSha256 =
      '4c73ffc59d497c186b19d1e90f5d721d678ea6b2e277b719bee4e2af12271825';
  static const String tessMarSha256 =
      '0ba3f2d116972e72fe9e176bc84c38e81dfb6670f4ed1f7f6c8e16a27da7cb61';
  static const String tessKanSha256 =
      'bd31e6b6ae93271e3bcf5383d306d8eefbb91542937cd6d735a5930c970e61d8';
  static const String tessTamSha256 =
      'd02fbec24be4b07e32e80d0ccfc3b6b67a3c5d61c9d0a7c8532677990912c6ec';
  static const String tessTelSha256 =
      'd10691fddd5b67802e1c12800ebb321d3b8bcd8d24a2ac3ff206f93188c04ab5';
  static const String tessMalSha256 =
      'bd05cbf1b197e7810d2903419aedb06f9ef77bfedf50b358673c1d18d707cdb4';
  static const String tessBenSha256 =
      '31163084c279aaebd376216f0c3d5c17ad4b5fee8db49dae79c20000b5de5964';
  static const String sileroVadSha256 =
      'c36d490aff5ab924ca6c7aeec4d8f6bd3d22db6fa17611b9c5b17eae58ac3a20';
  static const String handLandmarkId = 'mediapipe-hand-landmarks-fp16';
  static const String handLandmarkSha256 =
      '6acda74af3fbf40e68265c20c7394b2bad81a16a481dcd79ad7a081887c3d6b9';
  static const int handLandmarkSizeBytes = 5478949;

  static final List<ModelMetadata> defaultCatalog = [
    const ModelMetadata(
      modelId: mirageId,
      displayName: 'Cactus Mirage (2-bit VLM)',
      version: '4.1.4 / 76c1e9e5',
      supportedTasks: [ModelTask.scenePerception, ModelTask.latinOcr],
      languages: ['en', 'de', 'fr', 'es', 'it', 'nl', 'pl'],
      inputSpec: 'Packed RGB24 uint8 image',
      outputSpec: 'Structured JSON (scene, objects, text, relations, events, form)',
      runtime: ModelRuntime.cactusNative,
      sizeBytes: mirageSizeBytes,
      ramRequirementMb: 96,
      quantization: 'Cactus 2-bit (4-bit emb/mHC, fp16 HConvGLU)',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: mirageSha256,
      status: ModelStatus.notInstalled,
      provenanceUrl: 'https://huggingface.co/Cactus-Compute/mirage',
    ),
    const ModelMetadata(
      modelId: 'android-offline-tts',
      displayName: 'Android System Offline TTS Voices',
      version: 'OS-Verified',
      supportedTasks: [ModelTask.offlineTts],
      languages: ['en-IN', 'hi-IN', 'kn-IN', 'ta-IN', 'te-IN', 'ml-IN', 'mr-IN', 'bn-IN'],
      inputSpec: 'UTF-8 text + locale',
      outputSpec: 'Device audio speech',
      runtime: ModelRuntime.androidSystemTts,
      sizeBytes: 0,
      ramRequirementMb: 32,
      quantization: 'System',
      licence: 'Android Platform',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: '0000000000000000000000000000000000000000000000000000000000000000',
      status: ModelStatus.verifiedReady,
    ),
    const ModelMetadata(
      modelId: 'mlkit-text-devanagari',
      displayName: 'Google ML Kit Devanagari OCR (Bundled Offline)',
      version: '16.0.1',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['hi', 'mr'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Devanagari Unicode text + bboxes',
      runtime: ModelRuntime.mlKitOffline,
      sizeBytes: 4200000,
      ramRequirementMb: 48,
      quantization: 'TFLite Bundled',
      licence: 'Google ML Kit Terms',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: '0000000000000000000000000000000000000000000000000000000000000000',
      status: ModelStatus.verifiedReady,
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-hin',
      displayName: 'Tesseract Fast Hindi (tessdata_fast Bundled)',
      version: '4.9.0 / tessdata_fast',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['hi'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Devanagari Unicode text + line bboxes',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 1122751,
      ramRequirementMb: 36,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: tessHinSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-mar',
      displayName: 'Tesseract Fast Marathi (tessdata_fast Bundled)',
      version: '4.9.0 / tessdata_fast',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['mr'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Devanagari Marathi Unicode text + line bboxes',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 2118233,
      ramRequirementMb: 40,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: tessMarSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-kan',
      displayName: 'Tesseract Fast Kannada (tessdata_fast Bundled)',
      version: '4.9.0 / tessdata_fast',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['kn'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Kannada Unicode text + line bboxes',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 3608331,
      ramRequirementMb: 48,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: tessKanSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-tam',
      displayName: 'Tesseract Fast Tamil (tessdata_fast Bundled)',
      version: '4.9.0 / tessdata_fast',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['ta'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Tamil Unicode text + line bboxes',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 3237963,
      ramRequirementMb: 48,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: tessTamSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-tel',
      displayName: 'Tesseract Fast Telugu (tessdata_fast Bundled)',
      version: '4.9.0 / tessdata_fast',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['te'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Telugu Unicode text + line bboxes',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 2769654,
      ramRequirementMb: 46,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: tessTelSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-mal',
      displayName: 'Tesseract Fast Malayalam (tessdata_fast Bundled)',
      version: '4.9.0 / tessdata_fast',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['ml'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Malayalam Unicode text + line bboxes',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 5275996,
      ramRequirementMb: 56,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: tessMalSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-ben',
      displayName: 'Tesseract Fast Bengali (tessdata_fast Bundled)',
      version: '4.9.0 / tessdata_fast',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['bn'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'Bengali Unicode text + line bboxes',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 855841,
      ramRequirementMb: 34,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: tessBenSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'silero-vad-int8',
      displayName: 'Silero VAD INT8 (sherpa-onnx Bundled)',
      version: 'v2.0.3',
      supportedTasks: [ModelTask.vad],
      languages: ['universal'],
      inputSpec: '16 kHz mono float32 PCM (512-sample chunks)',
      outputSpec: 'Voice speech boundaries',
      runtime: ModelRuntime.sherpaOnnx,
      sizeBytes: 213000,
      ramRequirementMb: 12,
      quantization: 'INT8 ONNX',
      licence: 'MIT',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: sileroVadSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl: 'https://github.com/k2-fsa/sherpa-onnx',
    ),
    const ModelMetadata(
      modelId: 'indicconformer-sherpa-hi-int8',
      displayName: 'AI4Bharat IndicConformer Hindi INT8 Pack (Optional)',
      version: 'dc0fe4b4f11c',
      supportedTasks: [ModelTask.indianAsr],
      languages: ['hi-IN'],
      inputSpec: '16kHz mono float32 PCM',
      outputSpec: 'Devanagari transcript',
      runtime: ModelRuntime.sherpaOnnx,
      sizeBytes: 197600000,
      ramRequirementMb: 260,
      quantization: 'INT8 ONNX',
      licence: 'Apache-2.0 / MIT',
      hardwareCompatibility: ['arm64-v8a'],
      expectedSha256: '915c71e04dd7e537000000000000000000000000000000000000000000000000',
      status: ModelStatus.notInstalled,
      provenanceUrl: 'https://huggingface.co/NiranjanYadavIN/indicconformer-sherpa-onnx',
    ),
    const ModelMetadata(
      modelId: 'indicconformer-sherpa-kn-int8',
      displayName: 'AI4Bharat IndicConformer Kannada INT8 Pack (Optional)',
      version: 'dc0fe4b4f11c',
      supportedTasks: [ModelTask.indianAsr],
      languages: ['kn-IN'],
      inputSpec: '16kHz mono float32 PCM',
      outputSpec: 'Kannada transcript',
      runtime: ModelRuntime.sherpaOnnx,
      sizeBytes: 197600000,
      ramRequirementMb: 260,
      quantization: 'INT8 ONNX',
      licence: 'Apache-2.0 / MIT',
      hardwareCompatibility: ['arm64-v8a'],
      expectedSha256: 'b226ce7e4ea35b0d000000000000000000000000000000000000000000000000',
      status: ModelStatus.notInstalled,
      provenanceUrl: 'https://huggingface.co/NiranjanYadavIN/indicconformer-sherpa-onnx',
    ),
    const ModelMetadata(
      modelId: 'mlkit-barcode-bundled',
      displayName: 'Google ML Kit Barcode Scanner (Bundled Offline)',
      version: '17.3.0',
      supportedTasks: [ModelTask.barcodeLookup],
      languages: ['universal'],
      inputSpec: 'ARGB8888 Bitmap',
      outputSpec: 'EAN-13/UPC/Code-128/QR value',
      runtime: ModelRuntime.mlKitOffline,
      sizeBytes: 2200000,
      ramRequirementMb: 32,
      quantization: 'Bundled',
      licence: 'Google ML Kit Terms',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: '0000000000000000000000000000000000000000000000000000000000000000',
      status: ModelStatus.verifiedReady,
    ),
    const ModelMetadata(
      modelId: 'openetra-hsv-edge-embed96',
      displayName: 'Openetra Visual Crop Descriptor (96-dim Native)',
      version: '1.0.0',
      supportedTasks: [ModelTask.objectEmbedding],
      languages: ['universal'],
      inputSpec: 'RGB24 cropped bbox',
      outputSpec: 'L2-normalized 96-dim float32 embedding',
      runtime: ModelRuntime.liteRtTflite,
      sizeBytes: 0,
      ramRequirementMb: 4,
      quantization: 'Float32',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: '0000000000000000000000000000000000000000000000000000000000000000',
      status: ModelStatus.verifiedReady,
    ),
    const ModelMetadata(
      modelId: 'inr-currency-mobilenetv3-int8',
      displayName: 'INR Note Classifier (LiteRT 1.4.2 Slot)',
      version: 'pack-slot-phase6',
      supportedTasks: [ModelTask.currencyClassification],
      languages: ['en', 'hi', 'kn'],
      inputSpec: '224x224 RGB banknote crop',
      outputSpec: 'INR denomination probabilities',
      runtime: ModelRuntime.liteRtTflite,
      sizeBytes: 3200000,
      ramRequirementMb: 40,
      quantization: 'INT8 TFLite',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: 'pending-pack-pin-phase6-inr-00000000000000000000000000000000000',
      status: ModelStatus.notInstalled,
    ),
    const ModelMetadata(
      modelId: handLandmarkId,
      displayName: 'MediaPipe Hand Landmarks Detector (LiteRT fp16)',
      version: 'hand_landmarker/float16/1',
      supportedTasks: [ModelTask.handGesture],
      languages: ['universal'],
      inputSpec: '224x224x3 float32 RGB [0..1]',
      outputSpec: '21 3D hand landmarks + presence + handedness',
      runtime: ModelRuntime.liteRtTflite,
      sizeBytes: handLandmarkSizeBytes,
      ramRequirementMb: 24,
      quantization: 'Float16 TFLite (LiteRT 1.4.2 XNNPACK)',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: handLandmarkSha256,
      status: ModelStatus.verifiedReady,
      provenanceUrl:
          'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task',
    ),
  ];

  List<ModelMetadata> get allModels => _models.values.toList(growable: false);

  ModelMetadata? getById(String modelId) => _models[modelId];

  List<ModelMetadata> modelsForTask(ModelTask task) => _models.values
      .where((m) => m.supportedTasks.contains(task))
      .toList(growable: false);

  void updateModel(ModelMetadata updated) {
    _models[updated.modelId] = updated;
  }

  void recordPerformance(ModelPerformance perf) {
    _recentBenchmarks.insert(0, perf);
    if (_recentBenchmarks.length > 100) {
      _recentBenchmarks.removeLast();
    }
  }

  final List<ModelPerformance> _recentBenchmarks = [];
  List<ModelPerformance> get recentBenchmarks =>
      List.unmodifiable(_recentBenchmarks);
}

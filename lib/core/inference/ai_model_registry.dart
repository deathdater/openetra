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
      modelId: 'ppocrv5-devanagari-mobile',
      displayName: 'PaddleOCR PP-OCRv5 Mobile Devanagari',
      version: 'paddle3.0.0',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['hi', 'mr'],
      inputSpec: 'Text crop RGB',
      outputSpec: 'Devanagari Unicode text',
      runtime: ModelRuntime.onnxRuntime,
      sizeBytes: 12000000,
      ramRequirementMb: 64,
      quantization: 'FP16/INT8 ONNX pack (Phase 5)',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: 'pending-pack-pin-phase5-devanagari-000000000000000000000000000000',
      status: ModelStatus.notInstalled,
      provenanceUrl: 'https://github.com/PaddlePaddle/PaddleOCR',
    ),
    const ModelMetadata(
      modelId: 'tesseract-fast-kan',
      displayName: 'Tesseract Fast Kannada (tessdata_fast)',
      version: 'tessdata_fast-4.1',
      supportedTasks: [ModelTask.indicOcr],
      languages: ['kn'],
      inputSpec: 'Line/block bitmap',
      outputSpec: 'Kannada Unicode text',
      runtime: ModelRuntime.tesseractNative,
      sizeBytes: 3607000,
      ramRequirementMb: 48,
      quantization: 'Integer LSTM',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a', 'armeabi-v7a'],
      expectedSha256: 'pending-pack-pin-phase5-kan-00000000000000000000000000000000000',
      status: ModelStatus.notInstalled,
      provenanceUrl: 'https://github.com/tesseract-ocr/tessdata_fast',
    ),
    const ModelMetadata(
      modelId: 'indicconformer-sherpa-int8',
      displayName: 'AI4Bharat IndicConformer INT8 (sherpa-onnx)',
      version: 'v1-int8-pack',
      supportedTasks: [ModelTask.indianAsr],
      languages: ['hi-IN', 'kn-IN', 'ta-IN', 'te-IN', 'ml-IN', 'mr-IN', 'bn-IN'],
      inputSpec: '16kHz mono float32 PCM',
      outputSpec: 'Transcript text',
      runtime: ModelRuntime.sherpaOnnx,
      sizeBytes: 188000000,
      ramRequirementMb: 260,
      quantization: 'INT8 ONNX',
      licence: 'MIT',
      hardwareCompatibility: ['arm64-v8a'],
      expectedSha256: 'pending-pack-pin-phase5-asr-00000000000000000000000000000000000',
      status: ModelStatus.notInstalled,
      provenanceUrl: 'https://ai4bharat.iitm.ac.in/areas/model/ASR/IndicConformer/',
    ),
    const ModelMetadata(
      modelId: 'inr-currency-mobilenetv3-int8',
      displayName: 'INR Note Classifier (MobileNetV3-Small INT8)',
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
      modelId: 'depth-anything-v2-small-int8',
      displayName: 'Depth Anything V2 Small (INT8)',
      version: 'v2-small-pack-slot',
      supportedTasks: [ModelTask.depthEstimation],
      languages: ['universal'],
      inputSpec: '518x518 RGB',
      outputSpec: 'Relative disparity map',
      runtime: ModelRuntime.liteRtTflite,
      sizeBytes: 25000000,
      ramRequirementMb: 180,
      quantization: 'INT8',
      licence: 'Apache-2.0',
      hardwareCompatibility: ['arm64-v8a'],
      expectedSha256: 'pending-pack-pin-phase6-depth-000000000000000000000000000000000',
      status: ModelStatus.notInstalled,
      provenanceUrl: 'https://github.com/DepthAnything/Depth-Anything-V2',
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

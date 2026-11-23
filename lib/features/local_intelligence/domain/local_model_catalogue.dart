import 'package:equatable/equatable.dart';

enum LocalModelInstallState {
  notInstalled,
  downloading,
  verifying,
  installedVerified,
  incompatible,
  error,
}

class DeviceHardwareProfile extends Equatable {
  const DeviceHardwareProfile({
    required this.androidApiLevel,
    required this.totalRamMb,
    required this.availableStorageMb,
    required this.supportedAbis,
    required this.liteRtLmRuntimeAvailable,
  });

  final int androidApiLevel;
  final int totalRamMb;
  final int availableStorageMb;
  final List<String> supportedAbis;
  final bool liteRtLmRuntimeAvailable;

  bool get isArm64 => supportedAbis.contains('arm64-v8a');

  static const DeviceHardwareProfile unknown = DeviceHardwareProfile(
    androidApiLevel: 0,
    totalRamMb: 0,
    availableStorageMb: 0,
    supportedAbis: [],
    liteRtLmRuntimeAvailable: false,
  );

  @override
  List<Object?> get props => [
        androidApiLevel,
        totalRamMb,
        availableStorageMb,
        supportedAbis,
        liteRtLmRuntimeAvailable,
      ];
}

class ModelCompatibilityResult extends Equatable {
  const ModelCompatibilityResult({
    required this.isCompatible,
    required this.reasons,
  });

  final bool isCompatible;
  final List<String> reasons;

  @override
  List<Object?> get props => [isCompatible, reasons];
}

/// Versioned manifest entry for an optional on-device LiteRT-LM model.
class LocalModelSpec extends Equatable {
  const LocalModelSpec({
    required this.modelId,
    required this.displayName,
    required this.version,
    required this.quantization,
    required this.packageSizeMb,
    required this.runtimeName,
    required this.minRamMb,
    required this.minAndroidApi,
    required this.requiresArm64,
    required this.licence,
    required this.requiresLicenceAcceptance,
    required this.supportedLanguages,
    required this.expectedFileExtension,
  });

  final String modelId;
  final String displayName;
  final String version;
  final String quantization;
  final int packageSizeMb;
  final String runtimeName;
  final int minRamMb;
  final int minAndroidApi;
  final bool requiresArm64;
  final String licence;
  final bool requiresLicenceAcceptance;
  final List<String> supportedLanguages;
  final String expectedFileExtension;

  ModelCompatibilityResult evaluateDevice(DeviceHardwareProfile device) {
    final reasons = <String>[];
    if (device.androidApiLevel > 0 && device.androidApiLevel < minAndroidApi) {
      reasons.add('Requires Android API $minAndroidApi+ (device is ${device.androidApiLevel}).');
    }
    if (requiresArm64 &&
        device.supportedAbis.isNotEmpty &&
        !device.isArm64) {
      reasons.add('Requires 64-bit arm64-v8a CPU architecture.');
    }
    if (device.totalRamMb > 0 && device.totalRamMb < minRamMb) {
      reasons.add('Requires at least ${(minRamMb / 1024).toStringAsFixed(1)} GB RAM (device has ${(device.totalRamMb / 1024).toStringAsFixed(1)} GB).');
    }
    final requiredFreeMb = (packageSizeMb * 1.4).round();
    if (device.availableStorageMb > 0 &&
        device.availableStorageMb < requiredFreeMb) {
      reasons.add('Needs ~$requiredFreeMb MB free storage (${device.availableStorageMb} MB available).');
    }
    return ModelCompatibilityResult(
      isCompatible: reasons.isEmpty,
      reasons: reasons,
    );
  }

  @override
  List<Object?> get props => [
        modelId,
        displayName,
        version,
        quantization,
        packageSizeMb,
        runtimeName,
        minRamMb,
        minAndroidApi,
        requiresArm64,
        licence,
        requiresLicenceAcceptance,
        supportedLanguages,
        expectedFileExtension,
      ];
}

/// Verified candidate catalogue for Openetra Local Intelligence (Beta).
class LocalModelCatalogue {
  const LocalModelCatalogue._();

  static const List<LocalModelSpec> verifiedModels = [
    LocalModelSpec(
      modelId: 'qwen3-0.6b-q4',
      displayName: 'Qwen3-0.6B (Compact)',
      version: '1.0.0',
      quantization: 'INT4 (.litertlm)',
      packageSizeMb: 450,
      runtimeName: 'LiteRT-LM',
      minRamMb: 3072,
      minAndroidApi: 26,
      requiresArm64: true,
      licence: 'Apache 2.0',
      requiresLicenceAcceptance: false,
      supportedLanguages: ['en', 'hi', 'bn', 'ta', 'te', 'mr', 'kn', 'ml'],
      expectedFileExtension: '.litertlm',
    ),
    LocalModelSpec(
      modelId: 'qwen3-1.7b-q4',
      displayName: 'Qwen3-1.7B (Balanced)',
      version: '1.0.0',
      quantization: 'INT4 (.litertlm)',
      packageSizeMb: 1024,
      runtimeName: 'LiteRT-LM',
      minRamMb: 4096,
      minAndroidApi: 26,
      requiresArm64: true,
      licence: 'Apache 2.0',
      requiresLicenceAcceptance: false,
      supportedLanguages: ['en', 'hi', 'bn', 'ta', 'te', 'mr', 'kn', 'ml'],
      expectedFileExtension: '.litertlm',
    ),
    LocalModelSpec(
      modelId: 'gemma-3n-e2b-it-q4',
      displayName: 'Gemma 3n E2B-IT (High-RAM)',
      version: '1.0.0',
      quantization: 'INT4 (.litertlm)',
      packageSizeMb: 2150,
      runtimeName: 'LiteRT-LM',
      minRamMb: 6144,
      minAndroidApi: 29,
      requiresArm64: true,
      licence: 'Gemma Terms of Use',
      requiresLicenceAcceptance: true,
      supportedLanguages: ['en', 'hi', 'bn', 'ta', 'te', 'mr', 'kn', 'ml'],
      expectedFileExtension: '.litertlm',
    ),
  ];

  static LocalModelSpec? byId(String? modelId) {
    if (modelId == null) return null;
    for (final m in verifiedModels) {
      if (m.modelId == modelId) return m;
    }
    return null;
  }
}

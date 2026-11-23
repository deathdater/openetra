import 'package:equatable/equatable.dart';
import 'hazard_entities.dart';
import 'provenance_and_quality.dart';
import 'scene_graph.dart';

enum OperatingMode {
  eco,
  balanced,
  reading,
  objectSearch,
  hazardAwareness,
  idle,
}

enum ThermalState {
  nominal,
  light,
  moderate,
  severe,
  critical,
}

/// Real-time device battery, thermal, memory, and inference-budget snapshot.
class DeviceResourceState extends Equatable {
  const DeviceResourceState({
    required this.operatingMode,
    required this.batteryPercent,
    required this.isCharging,
    required this.thermalState,
    required this.availableRamMb,
    required this.isLowMemory,
    required this.recommendedThreads,
    required this.inferenceIntervalMs,
    required this.isDegradedCapability,
    this.degradationMessage,
  });

  final OperatingMode operatingMode;
  final int batteryPercent;
  final bool isCharging;
  final ThermalState thermalState;
  final int availableRamMb;
  final bool isLowMemory;
  final int recommendedThreads;
  final int inferenceIntervalMs;
  final bool isDegradedCapability;
  final String? degradationMessage;

  static const DeviceResourceState nominalBalanced = DeviceResourceState(
    operatingMode: OperatingMode.balanced,
    batteryPercent: 85,
    isCharging: false,
    thermalState: ThermalState.nominal,
    availableRamMb: 3072,
    isLowMemory: false,
    recommendedThreads: 0,
    inferenceIntervalMs: 1200,
    isDegradedCapability: false,
  );

  @override
  List<Object?> get props => [
        operatingMode,
        batteryPercent,
        isCharging,
        thermalState,
        availableRamMb,
        isLowMemory,
        recommendedThreads,
        inferenceIntervalMs,
        isDegradedCapability,
        degradationMessage,
      ];
}

enum SafetyEventType {
  hazardAlert,
  degradedQuality,
  thermalThrottle,
  modelIntegrityViolation,
  policySanitizedOutput,
  offlineVoiceUnavailable,
}

/// Audit log record of a safety-relevant decision or system degradation.
class SafetyEvent extends Equatable {
  const SafetyEvent({
    required this.eventId,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.hazardCategory,
    this.degradedReason,
  });

  final String eventId;
  final SafetyEventType type;
  final HazardSeverity severity;
  final String message;
  final DateTime timestamp;
  final HazardCategory? hazardCategory;
  final String? degradedReason;

  @override
  List<Object?> get props => [
        eventId,
        type,
        severity,
        message,
        timestamp,
        hazardCategory,
        degradedReason,
      ];
}

/// Denomination candidate for Indian currency recognition (Workflow E).
enum InrDenomination {
  inr10(10, '10 rupees'),
  inr20(20, '20 rupees'),
  inr50(50, '50 rupees'),
  inr100(100, '100 rupees'),
  inr200(200, '200 rupees'),
  inr500(500, '500 rupees'),
  uncertain(0, 'uncertain denomination');

  const InrDenomination(this.value, this.spokenLabel);
  final int value;
  final String spokenLabel;
}

class CurrencyRecognitionResult extends Equatable {
  const CurrencyRecognitionResult({
    required this.provenance,
    required this.denomination,
    required this.classifierConfidence,
    required this.ocrMatchedValue,
    required this.isUncertain,
    required this.spokenAdvisory,
    required this.nonCounterfeitDisclaimer,
  });

  final ObservationProvenance provenance;
  final InrDenomination denomination;
  final double classifierConfidence;
  final int? ocrMatchedValue;
  final bool isUncertain;
  final String spokenAdvisory;
  final String nonCounterfeitDisclaimer;

  @override
  List<Object?> get props => [
        provenance,
        denomination,
        classifierConfidence,
        ocrMatchedValue,
        isUncertain,
        spokenAdvisory,
        nonCounterfeitDisclaimer,
      ];
}

/// Stored profile for a user's personal belonging (Workflow D).
class PersonalObjectProfile extends Equatable {
  const PersonalObjectProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.colorHint,
    this.description,
    this.lastSeenSetting,
    this.lastSeenPosition,
    this.lastSeenAt,
  });

  final String id;
  final String name;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? colorHint;
  final String? description;
  final String? lastSeenSetting;
  final RelativePosition? lastSeenPosition;
  final DateTime? lastSeenAt;

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        createdAt,
        updatedAt,
        colorHint,
        description,
        lastSeenSetting,
        lastSeenPosition,
        lastSeenAt,
      ];
}

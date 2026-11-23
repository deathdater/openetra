import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'assistive_action.dart';

/// Persisted user-enrolled hand gesture stored offline as normalized landmark
/// feature vectors (no raw camera video or images retained).
class CustomGestureRecord extends Equatable {
  const CustomGestureRecord({
    required this.id,
    required this.name,
    required this.actionId,
    this.actionArgument,
    required this.sampleCount,
    required this.templates,
    required this.threshold,
    required this.isValidated,
    this.isEmergencyOptIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AssistiveActionId actionId;
  final String? actionArgument;
  final int sampleCount;
  /// List of L2-normalized geometric hand landmark descriptors (`List<double>`).
  final List<List<double>> templates;
  final double threshold;
  final bool isValidated;
  final bool isEmergencyOptIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  String encodeTemplatesJson() => jsonEncode(templates);

  static List<List<double>> decodeTemplatesJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<List>()
        .map((row) => row.map((e) => (e as num).toDouble()).toList())
        .toList();
  }

  CustomGestureRecord copyWith({
    String? name,
    AssistiveActionId? actionId,
    String? actionArgument,
    int? sampleCount,
    List<List<double>>? templates,
    double? threshold,
    bool? isValidated,
    bool? isEmergencyOptIn,
    DateTime? updatedAt,
  }) {
    return CustomGestureRecord(
      id: id,
      name: name ?? this.name,
      actionId: actionId ?? this.actionId,
      actionArgument: actionArgument ?? this.actionArgument,
      sampleCount: sampleCount ?? this.sampleCount,
      templates: templates ?? this.templates,
      threshold: threshold ?? this.threshold,
      isValidated: isValidated ?? this.isValidated,
      isEmergencyOptIn: isEmergencyOptIn ?? this.isEmergencyOptIn,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        actionId,
        actionArgument,
        sampleCount,
        templates,
        threshold,
        isValidated,
        isEmergencyOptIn,
        createdAt,
        updatedAt,
      ];
}

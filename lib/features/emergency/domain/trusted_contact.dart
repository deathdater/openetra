import 'package:equatable/equatable.dart';

enum EmergencyActionMode {
  /// Default & recommended: opens Android phone dialer populated with trusted number.
  openDialer,
  /// Audio verification / practice flow without opening the dialer.
  dryRunVerificationOnly,
}

/// Trusted emergency contact persisted only in encrypted protected storage.
/// [toString] redacts the phone number so accidental log prints never expose PII.
class TrustedContact extends Equatable {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final bool isPrimary;

  String maskedPhone() {
    final trimmed = phoneNumber.trim();
    if (trimmed.length <= 4) return '****';
    final visibleTail = trimmed.substring(trimmed.length - 4);
    return '***$visibleTail';
  }

  TrustedContact copyWith({
    String? name,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
  }) {
    return TrustedContact(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phoneNumber': phoneNumber,
        if (relationship != null) 'relationship': relationship,
        'isPrimary': isPrimary,
      };

  static TrustedContact fromJson(Map<String, dynamic> raw) {
    return TrustedContact(
      id: (raw['id'] ?? '').toString(),
      name: (raw['name'] ?? '').toString(),
      phoneNumber: (raw['phoneNumber'] ?? '').toString(),
      relationship: raw['relationship']?.toString(),
      isPrimary: raw['isPrimary'] == true,
    );
  }

  @override
  String toString() =>
      'TrustedContact(id: $id, name: $name, phone: ${maskedPhone()}, isPrimary: $isPrimary)';

  @override
  List<Object?> get props => [id, name, phoneNumber, relationship, isPrimary];
}

class EmergencyCapabilities extends Equatable {
  const EmergencyCapabilities({
    required this.airplaneMode,
    required this.dialerAvailable,
    required this.telephonyAvailable,
  });

  final bool airplaneMode;
  final bool dialerAvailable;
  final bool telephonyAvailable;

  @override
  List<Object?> get props => [airplaneMode, dialerAvailable, telephonyAvailable];
}

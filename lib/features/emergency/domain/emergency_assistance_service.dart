import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/storage/openetra_database.dart';
import '../data/protected_contact_store.dart';
import '../domain/trusted_contact.dart';

class EmergencyOutcome {
  const EmergencyOutcome({
    required this.success,
    required this.spokenMessage,
    this.requiresUserConfiguration = false,
    this.dialerLaunched = false,
    this.isDryRun = false,
  });

  final bool success;
  final String spokenMessage;
  final bool requiresUserConfiguration;
  final bool dialerLaunched;
  final bool isDryRun;
}

/// Independent Emergency Assistance domain service requiring ZERO camera,
/// Mirage, OCR, gesture, or flashlight availability.
class EmergencyAssistanceService {
  EmergencyAssistanceService({
    required ProtectedContactStore store,
    OpenetraDatabase? database,
  })  : _store = store,
        _database = database;

  final ProtectedContactStore _store;
  final OpenetraDatabase? _database;
  static const _uuid = Uuid();

  static const String prefActionModeKey = 'emergency_action_mode';

  static String sanitizePhoneNumber(String raw) {
    final buf = StringBuffer();
    for (final code in raw.trim().runes) {
      final ch = String.fromCharCode(code);
      if (RegExp(r'[0-9]').hasMatch(ch) ||
          (ch == '+' && buf.isEmpty) ||
          ch == '*' ||
          ch == '#') {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static bool isValidPhoneNumber(String raw) {
    final clean = sanitizePhoneNumber(raw);
    final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 3 && digits.length <= 18;
  }

  Future<EmergencyActionMode> loadPreferredMode() async {
    final raw = await _database?.getAssistivePreference(prefActionModeKey);
    return EmergencyActionMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => EmergencyActionMode.openDialer,
    );
  }

  Future<void> savePreferredMode(EmergencyActionMode mode) async {
    await _database?.setAssistivePreference(prefActionModeKey, mode.name);
  }

  Future<List<TrustedContact>> loadContacts() => _store.loadContacts();

  Future<List<TrustedContact>> addOrUpdateContact({
    String? id,
    required String name,
    required String phoneNumber,
    String? relationship,
    bool makePrimary = false,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Contact name cannot be empty.');
    }
    if (!isValidPhoneNumber(phoneNumber)) {
      throw const FormatException('Please enter a valid phone number.');
    }
    final cleanNumber = sanitizePhoneNumber(phoneNumber);
    final current = List<TrustedContact>.from(await _store.loadContacts());
    final targetId = id ?? _uuid.v4();
    final setPrimary = makePrimary || current.isEmpty;

    final updatedList = <TrustedContact>[];
    bool replaced = false;
    for (final c in current) {
      if (c.id == targetId) {
        updatedList.add(
          c.copyWith(
            name: cleanName,
            phoneNumber: cleanNumber,
            relationship: relationship?.trim().isEmpty == true
                ? null
                : relationship?.trim(),
            isPrimary: setPrimary ? true : c.isPrimary,
          ),
        );
        replaced = true;
      } else {
        updatedList.add(setPrimary ? c.copyWith(isPrimary: false) : c);
      }
    }
    if (!replaced) {
      updatedList.add(
        TrustedContact(
          id: targetId,
          name: cleanName,
          phoneNumber: cleanNumber,
          relationship: relationship?.trim().isEmpty == true
              ? null
              : relationship?.trim(),
          isPrimary: setPrimary,
        ),
      );
    }
    if (!updatedList.any((c) => c.isPrimary) && updatedList.isNotEmpty) {
      updatedList[0] = updatedList[0].copyWith(isPrimary: true);
    }
    await _store.saveContacts(updatedList);
    return updatedList;
  }

  Future<List<TrustedContact>> setPrimaryContact(String contactId) async {
    final current = await _store.loadContacts();
    final updated = [
      for (final c in current) c.copyWith(isPrimary: c.id == contactId),
    ];
    await _store.saveContacts(updated);
    return updated;
  }

  Future<List<TrustedContact>> removeContact(String contactId) async {
    final updated =
        (await _store.loadContacts()).where((c) => c.id != contactId).toList();
    if (updated.isNotEmpty && !updated.any((c) => c.isPrimary)) {
      updated[0] = updated[0].copyWith(isPrimary: true);
    }
    await _store.saveContacts(updated);
    return updated;
  }

  Future<void> clearAllContacts() => _store.deleteAll();

  TrustedContact? selectPrimaryContact(List<TrustedContact> contacts) {
    if (contacts.isEmpty) return null;
    return contacts.firstWhere(
      (c) => c.isPrimary,
      orElse: () => contacts.first,
    );
  }

  Future<EmergencyCapabilities> checkCapabilities() => _store.checkCapabilities();

  Future<EmergencyOutcome> prepareConfirmationPrompt({bool isDryRun = false}) async {
    final contacts = await _store.loadContacts();
    final primary = selectPrimaryContact(contacts);
    if (primary == null) {
      return const EmergencyOutcome(
        success: false,
        requiresUserConfiguration: true,
        spokenMessage:
            'No trusted emergency contact is configured yet. Opening emergency contact setup so you can add a person first.',
      );
    }
    if (!isValidPhoneNumber(primary.phoneNumber)) {
      return EmergencyOutcome(
        success: false,
        requiresUserConfiguration: true,
        spokenMessage:
            'The phone number saved for ${primary.name} appears invalid. Please review emergency contacts.',
      );
    }
    final mode = isDryRun
        ? EmergencyActionMode.dryRunVerificationOnly
        : await loadPreferredMode();
    final caps = await _store.checkCapabilities();
    if (!isDryRun && mode == EmergencyActionMode.openDialer && !caps.dialerAvailable) {
      return const EmergencyOutcome(
        success: false,
        requiresUserConfiguration: true,
        spokenMessage:
            'No phone dialer application is available on this device. Openetra cannot place calls without a dialer.',
      );
    }
    final dryPrefix = isDryRun ? 'Test mode only (no real call will be placed): ' : '';
    final airplaneNote = caps.airplaneMode
        ? ' Note: Airplane mode is on, so cellular calling may be unavailable.'
        : '';
    return EmergencyOutcome(
      success: true,
      isDryRun: isDryRun || mode == EmergencyActionMode.dryRunVerificationOnly,
      spokenMessage:
          '${dryPrefix}Ready to open phone dialer for ${primary.name}, ending in ${primary.maskedPhone()}.$airplaneNote Confirm to proceed, or cancel now.',
    );
  }

  Future<EmergencyOutcome> executeConfirmedAction({bool isDryRun = false}) async {
    final contacts = await _store.loadContacts();
    final primary = selectPrimaryContact(contacts);
    if (primary == null || !isValidPhoneNumber(primary.phoneNumber)) {
      return const EmergencyOutcome(
        success: false,
        requiresUserConfiguration: true,
        spokenMessage:
            'No valid trusted emergency contact is configured. Add a trusted contact first.',
      );
    }

    final mode = await loadPreferredMode();
    if (isDryRun || mode == EmergencyActionMode.dryRunVerificationOnly) {
      return EmergencyOutcome(
        success: true,
        isDryRun: true,
        dialerLaunched: false,
        spokenMessage:
            'Emergency flow test succeeded for ${primary.name} (${primary.maskedPhone()}). No call was placed and no connection was attempted.',
      );
    }

    final caps = await _store.checkCapabilities();
    if (!caps.dialerAvailable) {
      return const EmergencyOutcome(
        success: false,
        requiresUserConfiguration: true,
        spokenMessage:
            'Phone dialer unavailable on this device. Openetra cannot connect calls automatically.',
      );
    }

    try {
      final ok = await _store.openDialer(primary.phoneNumber);
      if (!ok) {
        return const EmergencyOutcome(
          success: false,
          spokenMessage:
              'Unable to open the phone dialer right now. Check device permissions or cellular status.',
        );
      }
      final offlineWarn = (!caps.telephonyAvailable || caps.airplaneMode)
          ? ' Cellular network or airplane mode may prevent calling.'
          : '';
      return EmergencyOutcome(
        success: true,
        dialerLaunched: true,
        spokenMessage:
            'Phone dialer opened for ${primary.name} (${primary.maskedPhone()}). Confirm the call in your dialer.$offlineWarn',
      );
    } on PlatformException catch (e) {
      return EmergencyOutcome(
        success: false,
        spokenMessage:
            'Could not launch phone dialer (${e.message ?? e.code}). Please dial manually if needed.',
      );
    }
  }
}

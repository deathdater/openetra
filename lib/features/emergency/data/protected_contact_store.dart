import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/trusted_contact.dart';

/// Encrypted local storage + dialer capability gateway for Emergency Assistance.
abstract class ProtectedContactStore {
  Future<List<TrustedContact>> loadContacts();
  Future<void> saveContacts(List<TrustedContact> contacts);
  Future<void> deleteAll();
  Future<EmergencyCapabilities> checkCapabilities();
  Future<bool> openDialer(String phoneNumber);
}

/// Android Keystore AES-256-GCM storage & Intent.ACTION_DIAL launcher over
/// MethodChannel `com.openetra.app/emergency`.
class NativeEncryptedContactStore implements ProtectedContactStore {
  NativeEncryptedContactStore([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/emergency');

  final MethodChannel _channel;

  @override
  Future<List<TrustedContact>> loadContacts() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('loadContactsPayload');
      final raw = (res?['payload'] as String?) ?? '';
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => TrustedContact.fromJson(Map<String, dynamic>.from(m)))
          .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> saveContacts(List<TrustedContact> contacts) async {
    final jsonPayload = jsonEncode(contacts.map((c) => c.toJson()).toList());
    try {
      await _channel.invokeMethod<void>(
        'saveContactsPayload',
        {'payload': jsonPayload},
      );
    } on MissingPluginException {
      // Headless host test fallback.
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _channel.invokeMethod<void>('deleteContactsStorage');
    } on MissingPluginException {
      // Headless host test fallback.
    }
  }

  @override
  Future<EmergencyCapabilities> checkCapabilities() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('checkCallCapabilities');
      return EmergencyCapabilities(
        airplaneMode: (res?['airplaneMode'] as bool?) ?? false,
        dialerAvailable: (res?['dialerAvailable'] as bool?) ?? true,
        telephonyAvailable: (res?['telephonyAvailable'] as bool?) ?? true,
      );
    } on MissingPluginException {
      return const EmergencyCapabilities(
        airplaneMode: false,
        dialerAvailable: true,
        telephonyAvailable: true,
      );
    }
  }

  @override
  Future<bool> openDialer(String phoneNumber) async {
    final res = await _channel.invokeMapMethod<String, dynamic>(
      'openDialer',
      {'phoneNumber': phoneNumber},
    );
    return (res?['dialerOpened'] as bool?) ?? false;
  }
}

/// Deterministic in-memory store for host unit & widget tests (no platform channels).
class InMemoryProtectedContactStore implements ProtectedContactStore {
  List<TrustedContact> _items = [];
  EmergencyCapabilities capabilities = const EmergencyCapabilities(
    airplaneMode: false,
    dialerAvailable: true,
    telephonyAvailable: true,
  );
  int dialerLaunchCount = 0;
  String? lastDialedNumber;

  @override
  Future<List<TrustedContact>> loadContacts() async => List.unmodifiable(_items);

  @override
  Future<void> saveContacts(List<TrustedContact> contacts) async {
    _items = List<TrustedContact>.from(contacts);
  }

  @override
  Future<void> deleteAll() async {
    _items = [];
  }

  @override
  Future<EmergencyCapabilities> checkCapabilities() async => capabilities;

  @override
  Future<bool> openDialer(String phoneNumber) async {
    if (!capabilities.dialerAvailable) {
      throw PlatformException(
        code: 'DIALER_UNAVAILABLE',
        message: 'No dialer app available on device',
      );
    }
    dialerLaunchCount++;
    lastDialedNumber = phoneNumber;
    return true;
  }
}

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum OpenetraPermission {
  camera,
  microphone,
  notifications,
  overlay,
  internet,
}

enum PermissionGrantState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  revoked,
}

class PermissionStatusRecord extends Equatable {
  const PermissionStatusRecord({
    required this.permission,
    required this.state,
    required this.explanation,
  });

  final OpenetraPermission permission;
  final PermissionGrantState state;
  final String explanation;

  bool get isGranted => state == PermissionGrantState.granted;
  bool get isPermanentlyDenied =>
      state == PermissionGrantState.permanentlyDenied;
  bool get requiresSettings =>
      state == PermissionGrantState.permanentlyDenied ||
      state == PermissionGrantState.revoked;

  @override
  List<Object?> get props => [permission, state, explanation];
}

/// Abstract platform adapter allowing tests or native Android handlers to supply
/// permission checks and requests without bypassing Android dialogs.
abstract class PermissionGateway {
  Future<PermissionGrantState> check(OpenetraPermission permission);
  Future<PermissionGrantState> request(OpenetraPermission permission);
  Future<bool> openSystemSettings();
  Future<bool> openInternetSettings() async => openSystemSettings();
}

/// Live Android/iOS permission gateway backed by `permission_handler` and
/// Openetra's native Android connectivity/permission probe for optional internet.
/// Fails safely to `PermissionGrantState.unknown` on unsupported hosts (e.g. VM tests).
class PlatformPermissionGateway implements PermissionGateway {
  const PlatformPermissionGateway();

  static const MethodChannel _networkChannel =
      MethodChannel('com.openetra.app/local_intelligence');

  ph.Permission _toPlatform(OpenetraPermission p) {
    return switch (p) {
      OpenetraPermission.camera => ph.Permission.camera,
      OpenetraPermission.microphone => ph.Permission.microphone,
      OpenetraPermission.notifications => ph.Permission.notification,
      OpenetraPermission.overlay => ph.Permission.systemAlertWindow,
      OpenetraPermission.internet => ph.Permission.notification, // handled natively
    };
  }

  PermissionGrantState _mapStatus(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionGrantState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionGrantState.permanentlyDenied;
    }
    return PermissionGrantState.denied;
  }

  @override
  Future<PermissionGrantState> check(OpenetraPermission permission) async {
    if (permission == OpenetraPermission.internet) {
      try {
        final res = await _networkChannel
            .invokeMapMethod<String, dynamic>('checkInternetAccess');
        if (res == null) return PermissionGrantState.unknown;
        if (res['hasPermission'] == false) {
          return PermissionGrantState.permanentlyDenied;
        }
        return res['isConnected'] == true
            ? PermissionGrantState.granted
            : PermissionGrantState.denied;
      } on MissingPluginException {
        return PermissionGrantState.unknown;
      } catch (_) {
        return PermissionGrantState.unknown;
      }
    }
    try {
      final status = await _toPlatform(permission).status;
      return _mapStatus(status);
    } on MissingPluginException {
      return PermissionGrantState.unknown;
    } catch (_) {
      return PermissionGrantState.unknown;
    }
  }

  @override
  Future<PermissionGrantState> request(OpenetraPermission permission) async {
    if (permission == OpenetraPermission.internet) {
      await openInternetSettings();
      return check(OpenetraPermission.internet);
    }
    try {
      final status = await _toPlatform(permission).request();
      return _mapStatus(status);
    } on MissingPluginException {
      return PermissionGrantState.unknown;
    } catch (_) {
      return PermissionGrantState.denied;
    }
  }

  @override
  Future<bool> openSystemSettings() async {
    try {
      return await ph.openAppSettings();
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openInternetSettings() async {
    try {
      final res = await _networkChannel
          .invokeMapMethod<String, dynamic>('openInternetSettings');
      if (res?['opened'] == true) return true;
      return openSystemSettings();
    } on MissingPluginException {
      return false;
    } catch (_) {
      return openSystemSettings();
    }
  }
}

class DefaultInMemoryPermissionGateway implements PermissionGateway {
  DefaultInMemoryPermissionGateway([
    Map<OpenetraPermission, PermissionGrantState>? initial,
  ]) {
    if (initial != null) {
      _states.addAll(initial);
    }
  }

  final Map<OpenetraPermission, PermissionGrantState> _states = {
    OpenetraPermission.camera: PermissionGrantState.unknown,
    OpenetraPermission.microphone: PermissionGrantState.unknown,
    OpenetraPermission.notifications: PermissionGrantState.unknown,
    OpenetraPermission.overlay: PermissionGrantState.denied,
    OpenetraPermission.internet: PermissionGrantState.unknown,
  };

  void setStateForTest(OpenetraPermission p, PermissionGrantState state) {
    _states[p] = state;
  }

  @override
  Future<PermissionGrantState> check(OpenetraPermission permission) async =>
      _states[permission] ?? PermissionGrantState.unknown;

  @override
  Future<PermissionGrantState> request(OpenetraPermission permission) async =>
      _states[permission] ?? PermissionGrantState.denied;

  @override
  Future<bool> openSystemSettings() async => true;

  @override
  Future<bool> openInternetSettings() async => true;
}

/// Contextual permission tracking, user-friendly accessible explanations, and
/// revocation notifications across Camera, Microphone, Notifications, Overlay,
/// and optional Internet Access.
class PermissionCoordinator {
  PermissionCoordinator({PermissionGateway? gateway})
      : _gateway = gateway ?? DefaultInMemoryPermissionGateway();

  final PermissionGateway _gateway;
  final Map<OpenetraPermission, PermissionGrantState> _cached = {
    OpenetraPermission.camera: PermissionGrantState.unknown,
    OpenetraPermission.microphone: PermissionGrantState.unknown,
    OpenetraPermission.notifications: PermissionGrantState.unknown,
    OpenetraPermission.overlay: PermissionGrantState.unknown,
    OpenetraPermission.internet: PermissionGrantState.unknown,
  };

  final StreamController<PermissionStatusRecord> _revocationController =
      StreamController<PermissionStatusRecord>.broadcast();

  Stream<PermissionStatusRecord> get onPermissionChanged =>
      _revocationController.stream;

  /// Core runtime permissions checked on every app start and resume.
  static const List<OpenetraPermission> coreStartupPermissions = [
    OpenetraPermission.camera,
    OpenetraPermission.microphone,
    OpenetraPermission.notifications,
  ];

  /// Optional permissions surfaced informatively in permission checks without
  /// blocking offline core features, and enforced only when needed (e.g. model downloads).
  static const List<OpenetraPermission> optionalStartupPermissions = [
    OpenetraPermission.internet,
  ];

  static String displayNameFor(OpenetraPermission p) {
    return switch (p) {
      OpenetraPermission.camera => 'Camera',
      OpenetraPermission.microphone => 'Microphone',
      OpenetraPermission.notifications => 'Notifications',
      OpenetraPermission.overlay => 'Display Over Other Apps',
      OpenetraPermission.internet => 'Internet Access (Optional)',
    };
  }

  static String explanationFor(OpenetraPermission p) {
    return switch (p) {
      OpenetraPermission.camera =>
        'Camera access is needed only when you trigger visual description, text reading, object search, hazard scan, or an explicit gesture session.',
      OpenetraPermission.microphone =>
        'Microphone access is used only when you press Speak Voice Command to recognize commands offline.',
      OpenetraPermission.notifications =>
        'Notification permission displays an honest active status bar item when the optional floating companion service is enabled.',
      OpenetraPermission.overlay =>
        'Display over other apps allows the optional Floating Assistive Widget to remain reachable outside Openetra. Camera and mic never start covertly from the background.',
      OpenetraPermission.internet =>
        'Internet access is optional for core offline features, but mandatory when you choose to download optional on-device AI models.',
    };
  }

  PermissionGrantState currentState(OpenetraPermission p) =>
      _cached[p] ?? PermissionGrantState.unknown;

  Future<PermissionStatusRecord> refresh(OpenetraPermission p) async {
    final prev = _cached[p];
    var next = await _gateway.check(p);
    if (prev == PermissionGrantState.granted &&
        next == PermissionGrantState.denied) {
      next = PermissionGrantState.revoked;
    }
    _cached[p] = next;
    final rec = PermissionStatusRecord(
      permission: p,
      state: next,
      explanation: explanationFor(p),
    );
    if (prev != next) {
      _revocationController.add(rec);
    }
    return rec;
  }

  /// Checks all requested permissions and returns those that are missing
  /// (denied, permanentlyDenied, or revoked). Ignores `unknown` states on
  /// non-mobile hosts.
  Future<List<PermissionStatusRecord>> checkMissingPermissions({
    List<OpenetraPermission> permissions = coreStartupPermissions,
  }) async {
    final missing = <PermissionStatusRecord>[];
    for (final p in permissions) {
      final rec = await refresh(p);
      if (!rec.isGranted && rec.state != PermissionGrantState.unknown) {
        missing.add(rec);
      }
    }
    return missing;
  }

  Future<PermissionStatusRecord> ensureOrRequest(OpenetraPermission p) async {
    final current = await refresh(p);
    if (current.isGranted) return current;
    final requested = await _gateway.request(p);
    _cached[p] = requested;
    final rec = PermissionStatusRecord(
      permission: p,
      state: requested,
      explanation: explanationFor(p),
    );
    _revocationController.add(rec);
    return rec;
  }

  /// Requests each missing permission sequentially and returns the updated records.
  Future<List<PermissionStatusRecord>> requestMissingPermissions(
    List<PermissionStatusRecord> missing,
  ) async {
    final results = <PermissionStatusRecord>[];
    for (final item in missing) {
      results.add(await ensureOrRequest(item.permission));
    }
    return results;
  }

  Future<bool> openSystemSettings() => _gateway.openSystemSettings();

  Future<bool> openInternetSettings() => _gateway.openInternetSettings();

  Future<void> markRevoked(OpenetraPermission p) async {
    _cached[p] = PermissionGrantState.revoked;
    _revocationController.add(
      PermissionStatusRecord(
        permission: p,
        state: PermissionGrantState.revoked,
        explanation: explanationFor(p),
      ),
    );
  }

  Future<void> dispose() => _revocationController.close();
}

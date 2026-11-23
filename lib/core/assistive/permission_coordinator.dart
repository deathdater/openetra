import 'dart:async';
import 'package:equatable/equatable.dart';

enum OpenetraPermission {
  camera,
  microphone,
  notifications,
  overlay,
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

  @override
  List<Object?> get props => [permission, state, explanation];
}

/// Abstract platform adapter allowing tests or native Android handlers to supply
/// permission checks and requests without bypassing Android dialogs.
abstract class PermissionGateway {
  Future<PermissionGrantState> check(OpenetraPermission permission);
  Future<PermissionGrantState> request(OpenetraPermission permission);
}

class DefaultInMemoryPermissionGateway implements PermissionGateway {
  DefaultInMemoryPermissionGateway([Map<OpenetraPermission, PermissionGrantState>? initial]) {
    if (initial != null) {
      _states.addAll(initial);
    }
  }

  final Map<OpenetraPermission, PermissionGrantState> _states = {
    OpenetraPermission.camera: PermissionGrantState.unknown,
    OpenetraPermission.microphone: PermissionGrantState.unknown,
    OpenetraPermission.notifications: PermissionGrantState.unknown,
    OpenetraPermission.overlay: PermissionGrantState.denied,
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
}

/// Contextual permission tracking, user-friendly accessible explanations, and
/// revocation notifications across Camera, Microphone, Notifications, and Overlay.
class PermissionCoordinator {
  PermissionCoordinator({PermissionGateway? gateway})
      : _gateway = gateway ?? DefaultInMemoryPermissionGateway();

  final PermissionGateway _gateway;
  final Map<OpenetraPermission, PermissionGrantState> _cached = {
    OpenetraPermission.camera: PermissionGrantState.unknown,
    OpenetraPermission.microphone: PermissionGrantState.unknown,
    OpenetraPermission.notifications: PermissionGrantState.unknown,
    OpenetraPermission.overlay: PermissionGrantState.unknown,
  };

  final StreamController<PermissionStatusRecord> _revocationController =
      StreamController<PermissionStatusRecord>.broadcast();

  Stream<PermissionStatusRecord> get onPermissionChanged =>
      _revocationController.stream;

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
    };
  }

  PermissionGrantState currentState(OpenetraPermission p) =>
      _cached[p] ?? PermissionGrantState.unknown;

  Future<PermissionStatusRecord> refresh(OpenetraPermission p) async {
    final prev = _cached[p];
    var next = await _gateway.check(p);
    if (prev == PermissionGrantState.granted &&
        (next == PermissionGrantState.denied ||
            next == PermissionGrantState.permanentlyDenied)) {
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

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../camera/camera_controller_bridge.dart';
import '../inference/model_provider.dart';

/// Identifies which Openetra workflow currently owns the shared camera session.
enum CameraLeasePurpose {
  scene,
  hazard,
  reader,
  currency,
  objectSearch,
  shopping,
  gestureSession,
}

class CameraLease {
  CameraLease._({
    required this.leaseId,
    required this.purpose,
    required this.acquiredAt,
  });

  final String leaseId;
  final CameraLeasePurpose purpose;
  final DateTime acquiredAt;
}

/// Callback invoked whenever an already-authorized active camera frame yields a
/// fresh luminance reading, allowing optional auto-flashlight evaluation without
/// opening a second camera session.
typedef ActiveFrameLumaListener = void Function(double meanLuma);

/// Single coordinated owner wrapping the project's existing [CameraSource]
/// (`CameraControllerBridge` -> `CameraXCaptureManager`). Guarantees only one
/// logical owner holds the camera at a time and cleanly releases hardware access
/// on cancellation, error, or permission loss.
class CameraResourceManager {
  CameraResourceManager({
    required CameraSource cameraSource,
  }) : _cameraSource = cameraSource;

  final CameraSource _cameraSource;
  static const _uuid = Uuid();

  CameraLease? _activeLease;
  final Set<ActiveFrameLumaListener> _lumaListeners = {};
  Future<void> _serial = Future<void>.value();

  CameraLease? get activeLease => _activeLease;
  bool get hasActiveLease => _activeLease != null;

  void addLumaListener(ActiveFrameLumaListener listener) {
    _lumaListeners.add(listener);
  }

  void removeLumaListener(ActiveFrameLumaListener listener) {
    _lumaListeners.remove(listener);
  }

  /// Acquires an exclusive camera lease. If an existing lease holds another
  /// lower-priority purpose, callers can pass [preemptExisting] = true only for
  /// user-initiated switches; otherwise contention raises a clear [StateError].
  Future<CameraLease> acquireLease(
    CameraLeasePurpose purpose, {
    int minIntervalMs = 500,
    bool preemptExisting = false,
  }) {
    return _enqueue(() async {
      if (_activeLease != null && _activeLease!.purpose != purpose) {
        if (!preemptExisting) {
          throw StateError(
            'Camera is currently busy with ${_activeLease!.purpose.name}.',
          );
        }
        await _cameraSource.stop();
        _activeLease = null;
      }
      if (_activeLease == null) {
        await _cameraSource.start(minIntervalMs: minIntervalMs);
        _activeLease = CameraLease._(
          leaseId: _uuid.v4(),
          purpose: purpose,
          acquiredAt: DateTime.now(),
        );
      }
      return _activeLease!;
    });
  }

  /// Captures a frame under [lease], publishing frame `meanLuma` to subscribed
  /// active-frame listeners (e.g. automatic low-light flashlight policy).
  Future<CapturedFrame> captureFrame(CameraLease lease) async {
    if (_activeLease == null || _activeLease!.leaseId != lease.leaseId) {
      throw StateError('Camera lease ${lease.leaseId} is no longer active.');
    }
    final frame = await _cameraSource.captureFrame();
    final luma = frame.qualityMetrics.meanLuma;
    for (final listener in List<ActiveFrameLumaListener>.from(_lumaListeners)) {
      try {
        listener(luma);
      } catch (_) {}
    }
    return frame;
  }

  /// Releases [lease] and stops camera streaming if no active owner remains.
  Future<void> releaseLease(CameraLease? lease) {
    return _enqueue(() async {
      if (lease == null || _activeLease == null) return;
      if (_activeLease!.leaseId != lease.leaseId) return;
      _activeLease = null;
      await _cameraSource.stop();
    });
  }

  /// Emergency / lifecycle force-release guaranteeing no camera session leaks.
  Future<void> forceReleaseAll() {
    return _enqueue(() async {
      _activeLease = null;
      await _cameraSource.stop();
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final c = Completer<T>();
    _serial = _serial.then((_) async {
      try {
        c.complete(await action());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }
}

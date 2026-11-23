import 'package:flutter/services.dart';
import '../../../core/inference/model_provider.dart';
import '../domain/hand_landmark_features.dart';

abstract class GestureInferenceGateway {
  Future<bool> loadModel({int threads = 2});
  Future<void> unloadModel();
  Future<HandLandmarkFrame> extractLandmarks(CapturedFrame frame);
}

/// Bridges Flutter to `HandGesturePlugin.kt` (`com.openetra.app/gesture`).
class NativeGestureGateway implements GestureInferenceGateway {
  NativeGestureGateway([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/gesture');

  final MethodChannel _channel;

  @override
  Future<bool> loadModel({int threads = 2}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'loadModel',
        {'threads': threads},
      );
      return (res?['loaded'] as bool?) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod<void>('unloadModel');
    } on MissingPluginException {
      // Host test safe no-op.
    }
  }

  @override
  Future<HandLandmarkFrame> extractLandmarks(CapturedFrame frame) async {
    final bytes = frame.rgbBytes;
    if (bytes == null || frame.width <= 0 || frame.height <= 0) {
      return const HandLandmarkFrame(
        rawLandmarks63: [],
        handPresenceScore: 0.0,
        handednessScore: 0.0,
      );
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'extractLandmarksRgb',
        {
          'rgbBytes': bytes,
          'width': frame.width,
          'height': frame.height,
        },
      );
      if (res == null) {
        return const HandLandmarkFrame(
          rawLandmarks63: [],
          handPresenceScore: 0.0,
          handednessScore: 0.0,
        );
      }
      final landmarks = (res['landmarks'] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(growable: false);
      return HandLandmarkFrame(
        rawLandmarks63: landmarks,
        handPresenceScore: (res['handPresenceScore'] as num?)?.toDouble() ?? 0.0,
        handednessScore: (res['handednessScore'] as num?)?.toDouble() ?? 0.0,
        inferenceMs: (res['inferenceMs'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return const HandLandmarkFrame(
        rawLandmarks63: [],
        handPresenceScore: 0.0,
        handednessScore: 0.0,
      );
    }
  }
}

/// Deterministic test double for host evaluation and BLoC tests.
class FakeGestureGateway implements GestureInferenceGateway {
  bool loaded = false;
  HandLandmarkFrame nextFrame = const HandLandmarkFrame(
    rawLandmarks63: [],
    handPresenceScore: 0.0,
    handednessScore: 0.5,
  );
  final List<HandLandmarkFrame> queuedFrames = [];

  @override
  Future<bool> loadModel({int threads = 2}) async {
    loaded = true;
    return true;
  }

  @override
  Future<void> unloadModel() async {
    loaded = false;
  }

  @override
  Future<HandLandmarkFrame> extractLandmarks(CapturedFrame frame) async {
    if (queuedFrames.isNotEmpty) {
      return queuedFrames.removeAt(0);
    }
    return nextFrame;
  }
}

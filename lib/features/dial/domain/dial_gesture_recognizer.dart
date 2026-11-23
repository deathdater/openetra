import 'dart:ui';

enum DialGestureType {
  none,
  slideUp,
  slideDown,
  browseNext,
  browsePrevious,
}

/// Robust touch-gesture classifier for the Assistive Dial with minimum
/// distance, velocity, directional dominance (1.5x), system-edge guard (24 dp),
/// multi-touch rejection, and debounce protection.
class DialGestureAnalyzer {
  DialGestureAnalyzer({
    this.minVerticalDistanceDp = 52.0,
    this.minHorizontalDistanceDp = 36.0,
    this.minVelocityDpPerSec = 180.0,
    this.axisDominanceRatio = 1.5,
    this.systemEdgeGuardDp = 24.0,
    this.debounceDuration = const Duration(milliseconds: 250),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final double minVerticalDistanceDp;
  final double minHorizontalDistanceDp;
  final double minVelocityDpPerSec;
  final double axisDominanceRatio;
  final double systemEdgeGuardDp;
  final Duration debounceDuration;
  final DateTime Function() _clock;

  DateTime? _lastAcceptedAt;

  void reset() {
    _lastAcceptedAt = null;
  }

  /// Evaluates a completed single-pointer gesture vector and returns the
  /// classified [DialGestureType] or [DialGestureType.none] if rejected.
  DialGestureType classify({
    required Offset startPosition,
    required Offset endPosition,
    required Size viewportSize,
    required double velocityDpPerSec,
    int pointerCount = 1,
  }) {
    if (pointerCount != 1) return DialGestureType.none;

    // Guard against Android system back/home edge gestures.
    if (startPosition.dx < systemEdgeGuardDp ||
        startPosition.dx > viewportSize.width - systemEdgeGuardDp ||
        startPosition.dy < systemEdgeGuardDp ||
        startPosition.dy > viewportSize.height - systemEdgeGuardDp) {
      return DialGestureType.none;
    }

    final now = _clock();
    if (_lastAcceptedAt != null &&
        now.difference(_lastAcceptedAt!) < debounceDuration) {
      return DialGestureType.none;
    }

    final dx = endPosition.dx - startPosition.dx;
    final dy = endPosition.dy - startPosition.dy;
    final absDx = dx.abs();
    final absDy = dy.abs();

    // Vertical slide up / slide down (requires clear vertical dominance).
    if (absDy >= minVerticalDistanceDp &&
        absDy >= absDx * axisDominanceRatio &&
        velocityDpPerSec >= minVelocityDpPerSec) {
      _lastAcceptedAt = now;
      return dy < 0 ? DialGestureType.slideUp : DialGestureType.slideDown;
    }

    // Horizontal browse next / previous (never triggers execution).
    if (absDx >= minHorizontalDistanceDp &&
        absDx >= absDy * axisDominanceRatio) {
      _lastAcceptedAt = now;
      return dx > 0 ? DialGestureType.browseNext : DialGestureType.browsePrevious;
    }

    return DialGestureType.none;
  }
}

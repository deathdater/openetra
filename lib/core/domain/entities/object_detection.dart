import 'package:equatable/equatable.dart';

/// Normalized bounding box on a 0..1000 scale relative to image dimensions.
class BoundingBox extends Equatable {
  const BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final int x1;
  final int y1;
  final int x2;
  final int y2;

  int get width => (x2 - x1).clamp(0, 1000);
  int get height => (y2 - y1).clamp(0, 1000);
  double get centerX => (x1 + x2) / 2.0;
  double get centerY => (y1 + y2) / 2.0;
  double get areaRatio => (width * height) / 1000000.0;

  /// Computes Intersection over Union in [0.0, 1.0].
  double iou(BoundingBox other) {
    final ix1 = x1 > other.x1 ? x1 : other.x1;
    final iy1 = y1 > other.y1 ? y1 : other.y1;
    final ix2 = x2 < other.x2 ? x2 : other.x2;
    final iy2 = y2 < other.y2 ? y2 : other.y2;
    if (ix2 <= ix1 || iy2 <= iy1) return 0.0;
    final intersection = (ix2 - ix1) * (iy2 - iy1);
    final unionArea = (width * height) + (other.width * other.height) - intersection;
    if (unionArea <= 0) return 0.0;
    return intersection / unionArea;
  }

  factory BoundingBox.fromList(List<dynamic> coords) {
    if (coords.length < 4) {
      return const BoundingBox(x1: 0, y1: 0, x2: 0, y2: 0);
    }
    final rawX1 = (coords[0] as num).round().clamp(0, 1000);
    final rawY1 = (coords[1] as num).round().clamp(0, 1000);
    final rawX2 = (coords[2] as num).round().clamp(0, 1000);
    final rawY2 = (coords[3] as num).round().clamp(0, 1000);
    return BoundingBox(
      x1: rawX1 <= rawX2 ? rawX1 : rawX2,
      y1: rawY1 <= rawY2 ? rawY1 : rawY2,
      x2: rawX2 >= rawX1 ? rawX2 : rawX1,
      y2: rawY2 >= rawY1 ? rawY2 : rawY1,
    );
  }

  @override
  List<Object?> get props => [x1, y1, x2, y2];
}

enum MaskFormat {
  largest,
  merged,
  polygons,
  bitmap,
}

/// Optional segmentation mask attached to a detected object.
class SegmentationMask extends Equatable {
  const SegmentationMask({
    required this.format,
    this.polygons = const [],
    this.bitmapSize,
    this.bitmapRleCounts = const [],
  });

  final MaskFormat format;
  final List<List<int>> polygons;
  final List<int>? bitmapSize;
  final List<int> bitmapRleCounts;

  @override
  List<Object?> get props => [format, polygons, bitmapSize, bitmapRleCounts];
}

/// Visual attribute key-value metadata reported for an object (color, material, state, shape).
class ObjectAttribute extends Equatable {
  const ObjectAttribute({required this.key, required this.value});

  final String key;
  final String value;

  @override
  List<Object?> get props => [key, value];
}

/// Single object detection returned by Mirage or a specialist detector.
class ObjectDetection extends Equatable {
  const ObjectDetection({
    required this.entityId,
    required this.name,
    required this.boundingBox,
    required this.confidence,
    this.positionHint,
    this.attributes = const [],
    this.mask,
  });

  final int entityId;
  final String name;
  final BoundingBox boundingBox;
  final double confidence;
  final String? positionHint;
  final List<ObjectAttribute> attributes;
  final SegmentationMask? mask;

  @override
  List<Object?> get props => [
        entityId,
        name,
        boundingBox,
        confidence,
        positionHint,
        attributes,
        mask,
      ];
}

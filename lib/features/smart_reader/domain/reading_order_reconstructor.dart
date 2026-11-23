import '../../../core/domain/entities/entities.dart';

/// Reconstructs natural reading order (top-to-bottom visual rows, left-to-right
/// within each row) from raw OCR line bounding boxes.
class ReadingOrderReconstructor {
  const ReadingOrderReconstructor();

  List<TextLineObservation> sort(List<TextLineObservation> lines) {
    if (lines.length <= 1) return List<TextLineObservation>.from(lines);

    final sortedByY = List<TextLineObservation>.from(lines)
      ..sort((a, b) => a.boundingBox.y1.compareTo(b.boundingBox.y1));

    final rows = <List<TextLineObservation>>[];
    for (final line in sortedByY) {
      bool placed = false;
      for (final row in rows) {
        final anchor = row.first;
        if (_sharesVisualRow(anchor.boundingBox, line.boundingBox)) {
          row.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) {
        rows.add([line]);
      }
    }

    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.x1.compareTo(b.boundingBox.x1));
    }

    return rows.expand((r) => r).toList(growable: false);
  }

  static bool _sharesVisualRow(BoundingBox a, BoundingBox b) {
    final overlapTop = a.y1 > b.y1 ? a.y1 : b.y1;
    final overlapBot = a.y2 < b.y2 ? a.y2 : b.y2;
    final overlap = overlapBot - overlapTop;
    if (overlap <= 0) return false;
    final minHeight = a.height < b.height ? a.height : b.height;
    if (minHeight <= 0) return false;
    return overlap / minHeight >= 0.45;
  }
}

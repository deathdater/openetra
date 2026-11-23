import '../../../core/domain/entities/entities.dart';

class HazardMatch {
  const HazardMatch({
    required this.category,
    required this.classificationConfidence,
    required this.baseSeverity,
    required this.reason,
  });

  final HazardCategory category;
  final double classificationConfidence;
  final HazardSeverity baseSeverity;
  final String reason;
}

/// Rule-based taxonomy covering all 5 required hazard categories plus fire,
/// smoke, broken glass, and warning signs.
class HazardTaxonomy {
  const HazardTaxonomy();

  static const _groundTerms = <String>[
    'pothole',
    'open drain',
    'drain',
    'manhole',
    'uneven',
    'cable',
    'wire',
    'cord',
    'debris',
    'rubble',
    'puddle',
    'slippery',
    'wet floor',
    'stone',
    'brick',
    'garbage',
    'trash bag',
  ];

  static const _verticalTerms = <String>[
    'branch',
    'low branch',
    'overhang',
    'hanging wire',
    'overhead',
    'awning',
    'open cabinet',
    'cabinet door',
    'beam',
    'protruding',
  ];

  static const _elevationTerms = <String>[
    'stair',
    'stairs',
    'staircase',
    'step',
    'steps',
    'curb',
    'kerb',
    'drop-off',
    'dropoff',
    'ledge',
    'platform edge',
    'ramp',
    'speed bump',
    'escalator',
  ];

  static const _trafficTerms = <String>[
    'car',
    'bus',
    'truck',
    'lorry',
    'motorcycle',
    'motorbike',
    'scooter',
    'bicycle',
    'bike',
    'auto',
    'rickshaw',
    'auto-rickshaw',
    'van',
    'vehicle',
    'pedestrian',
    'intersection',
    'crosswalk',
    'traffic',
  ];

  static const _indoorTerms = <String>[
    'chair',
    'stool',
    'coffee table',
    'table',
    'sofa',
    'open drawer',
    'drawer',
    'glass door',
    'glass barrier',
    'glass wall',
    'spill',
    'bucket',
    'cart',
    'suitcase',
    'luggage',
  ];

  static const _criticalCueTerms = <String>[
    'fire',
    'flame',
    'smoke',
    'broken glass',
    'glass shards',
  ];

  static const _warningTextPatterns = <String>[
    'danger',
    'caution',
    'warning',
    'wet floor',
    'high voltage',
    'no entry',
    'work in progress',
    'under construction',
    'keep out',
    'stop',
  ];

  HazardMatch? classifyObject(ObjectDetection obj) {
    final name = obj.name.toLowerCase();
    final attrText = obj.attributes
        .map((a) => '${a.key} ${a.value}'.toLowerCase())
        .join(' ');
    final combined = '$name $attrText';

    if (_containsAny(combined, _criticalCueTerms)) {
      return HazardMatch(
        category: HazardCategory.fireSmokeGlassWarning,
        classificationConfidence: 0.90,
        baseSeverity: HazardSeverity.critical,
        reason: 'Critical cue (${obj.name})',
      );
    }

    if (_containsAny(combined, _trafficTerms)) {
      final isPedestrian = name == 'pedestrian' || name == 'person';
      return HazardMatch(
        category: HazardCategory.traffic,
        classificationConfidence: isPedestrian ? 0.65 : 0.88,
        baseSeverity:
            isPedestrian ? HazardSeverity.caution : HazardSeverity.warning,
        reason: 'Traffic participant (${obj.name})',
      );
    }

    if (_containsAny(combined, _elevationTerms)) {
      return HazardMatch(
        category: HazardCategory.elevationChange,
        classificationConfidence: 0.85,
        baseSeverity: HazardSeverity.warning,
        reason: 'Elevation change (${obj.name})',
      );
    }

    if (_containsAny(combined, _groundTerms)) {
      return HazardMatch(
        category: HazardCategory.groundLevel,
        classificationConfidence: 0.82,
        baseSeverity: HazardSeverity.warning,
        reason: 'Ground-level hazard (${obj.name})',
      );
    }

    if (_containsAny(combined, _verticalTerms) ||
        (name.contains('cabinet') && attrText.contains('open'))) {
      return HazardMatch(
        category: HazardCategory.verticalOverhead,
        classificationConfidence: 0.80,
        baseSeverity: HazardSeverity.warning,
        reason: 'Head-height / overhead obstruction (${obj.name})',
      );
    }

    if (_containsAny(combined, _indoorTerms) ||
        (name.contains('door') && attrText.contains('glass'))) {
      final isCenterFloor = obj.boundingBox.y2 > 620 &&
          obj.boundingBox.x2 > 260 &&
          obj.boundingBox.x1 < 740;
      if (isCenterFloor || attrText.contains('open') || attrText.contains('glass')) {
        return HazardMatch(
          category: HazardCategory.indoorObstruction,
          classificationConfidence: 0.72,
          baseSeverity: HazardSeverity.caution,
          reason: 'Pathway obstruction (${obj.name})',
        );
      }
    }

    return null;
  }

  HazardMatch? classifyWarningText(PerceivedTextSpan span) {
    final text = span.text.toLowerCase();
    for (final pattern in _warningTextPatterns) {
      if (text.contains(pattern)) {
        return HazardMatch(
          category: HazardCategory.fireSmokeGlassWarning,
          classificationConfidence: 0.84,
          baseSeverity: pattern == 'danger' || pattern == 'high voltage'
              ? HazardSeverity.warning
              : HazardSeverity.caution,
          reason: 'Visible warning text "${span.text}"',
        );
      }
    }
    return null;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

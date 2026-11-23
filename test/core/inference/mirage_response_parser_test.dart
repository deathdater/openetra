import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/errors/openetra_failure.dart';
import 'package:openetra/core/inference/mirage/mirage_response_parser.dart';

void main() {
  const parser = MirageResponseParser();

  test('parses real COCO 231049 Mirage JSON with scene, objects, text, masks, and relations', () {
    final json = File('test/fixtures/mirage/probe_full_231049.json').readAsStringSync();
    final obs = parser.parse(
      rawJson: json,
      inputWidth: 427,
      inputHeight: 640,
      processingDurationMs: 152,
      imageQuality: ImageQualityMetrics.nominal,
    );

    expect(obs.setting, 'suburban street');
    expect(obs.surface, 'pavement');
    expect(obs.objects.length, 8);
    expect(obs.objects.any((o) => o.name == 'stop sign' && o.confidence > 0.6), isTrue);
    expect(obs.objects.first.mask?.format, MaskFormat.largest);
    expect(obs.textSpans.length, 1);
    expect(obs.textSpans.first.text, 'ARRET');
    expect(obs.relationships.length, 2);
    expect(obs.relationships.first.subjectName, 'stop sign');
    expect(obs.relationships.first.predicate, 'attached_to');
    expect(obs.relationships.first.objectName, 'pole');
    expect(obs.provenance.validationStatus, ValidationStatus.verified);
  });

  test('parses real COCO 139 living room JSON preserving shared entity IDs', () {
    final json = File('test/fixtures/mirage/probe_139.json').readAsStringSync();
    final obs = parser.parse(
      rawJson: json,
      inputWidth: 640,
      inputHeight: 426,
      processingDurationMs: 220,
      imageQuality: ImageQualityMetrics.nominal,
    );

    expect(obs.setting, 'living room');
    final chairs = obs.objects.where((o) => o.name == 'chair').toList();
    expect(chairs.length, 11);
    expect(chairs.map((c) => c.entityId).toSet(), {6});
    expect(obs.relationships.any((r) => r.subjectName == 'rug' && r.objectName == 'dining table'), isTrue);
  });

  test('parses real form extraction and text-only outputs', () {
    final formJson = File('test/fixtures/mirage/probe_form.json').readAsStringSync();
    final formObs = parser.parse(
      rawJson: formJson,
      inputWidth: 427,
      inputHeight: 640,
      processingDurationMs: 54,
      imageQuality: ImageQualityMetrics.nominal,
      sourceCapability: 'mirage_form',
    );
    expect(formObs.formResult['sign']['value'], 'stop');
    expect(formObs.provenance.validationStatus, ValidationStatus.verified);

    final textJson = File('test/fixtures/mirage/probe_text.json').readAsStringSync();
    final textObs = parser.parse(
      rawJson: textJson,
      inputWidth: 427,
      inputHeight: 640,
      processingDurationMs: 136,
      imageQuality: ImageQualityMetrics.nominal,
    );
    expect(textObs.textSpans.single.text, 'ARRET');
  });

  test('handles null scene, bitmap/polygon masks, degraded quality, and bad JSON', () {
    const sample = '''
    {
      "scene": null,
      "objects": [
        {
          "id": 2,
          "name": "box",
          "bbox": [-10, 20, 1050, 500],
          "score": 0.7,
          "mask": {"size": [480, 640], "counts": [10, 20, 30]}
        },
        {
          "id": 3,
          "name": "bag",
          "bbox": [100, 100, 200, 200],
          "score": 0.6,
          "mask": [[100, 100, 200, 100, 200, 200]]
        }
      ]
    }
    ''';
    const degradedQuality = ImageQualityMetrics(
      meanLuma: 12.0,
      lumaStdDev: 8.0,
      laplacianVariance: 10.0,
      overexposedRatio: 0.0,
      underexposedRatio: 0.9,
    );

    final obs = parser.parse(
      rawJson: sample,
      inputWidth: 640,
      inputHeight: 480,
      processingDurationMs: 100,
      imageQuality: degradedQuality,
    );

    expect(obs.setting, isNull);
    expect(obs.objects[0].boundingBox, const BoundingBox(x1: 0, y1: 20, x2: 1000, y2: 500));
    expect(obs.objects[0].mask?.format, MaskFormat.bitmap);
    expect(obs.objects[1].mask?.format, MaskFormat.polygons);
    expect(obs.provenance.validationStatus, ValidationStatus.degraded);

    expect(
      () => parser.parse(
        rawJson: 'not valid json',
        inputWidth: 100,
        inputHeight: 100,
        processingDurationMs: 1,
        imageQuality: ImageQualityMetrics.nominal,
      ),
      throwsA(isA<InferenceFailure>()),
    );
  });
}

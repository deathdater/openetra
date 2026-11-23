import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../domain/entities/entities.dart';
import '../model_provider.dart';
import '../../../features/shopping/domain/shopping_assistant_service.dart';

/// Computes cosine similarity in [-1.0, 1.0] between two embeddings.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
  double dot = 0.0;
  double na = 0.0;
  double nb = 0.0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  final denom = math.sqrt(na) * math.sqrt(nb);
  if (denom <= 1e-9) return 0.0;
  return (dot / denom).clamp(-1.0, 1.0);
}

/// Offline ML Kit Barcode scanner via `com.openetra.app/specialist`.
class NativeBarcodeScannerProvider implements BarcodeScannerProvider {
  NativeBarcodeScannerProvider([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/specialist');

  final MethodChannel _channel;

  @override
  Future<String?> scanFirstBarcode(CapturedFrame frame) async {
    final rgb = frame.rgbBytes;
    if (rgb == null || frame.width <= 0 || frame.height <= 0) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'scanBarcodeRgb',
        {'rgbBytes': rgb, 'width': frame.width, 'height': frame.height},
      );
      final barcodes = (res?['barcodes'] as List?) ?? const [];
      for (final item in barcodes) {
        if (item is Map && item['rawValue'] != null) {
          final v = item['rawValue'].toString().trim();
          if (v.isNotEmpty) return v;
        }
      }
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// Visual crop descriptor provider (96-dim HSV + grid contrast + edge histogram)
/// via `com.openetra.app/specialist`.
class NativeEmbeddingProvider implements EmbeddingProvider {
  NativeEmbeddingProvider([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/specialist');

  final MethodChannel _channel;

  @override
  String get modelId => 'openetra-hsv-edge-embed96';

  @override
  Future<bool> get isAvailable async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('status');
      return (status?['embeddingAvailable'] as bool?) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<double>?> computeEmbedding(
    CapturedFrame frame,
    BoundingBox crop,
  ) async {
    final rgb = frame.rgbBytes;
    if (rgb == null || frame.width <= 0 || frame.height <= 0) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'computeCropEmbeddingRgb',
        {
          'rgbBytes': rgb,
          'width': frame.width,
          'height': frame.height,
          'x1': crop.x1,
          'y1': crop.y1,
          'x2': crop.x2,
          'y2': crop.y2,
        },
      );
      final raw = res?['embedding'] as List?;
      if (raw == null || raw.isEmpty) return null;
      return raw.map((e) => (e as num).toDouble()).toList(growable: false);
    } on MissingPluginException {
      return null;
    }
  }
}

/// LiteRT 2.4.0 banknote classifier bridge (activates when verified `.tflite`
/// currency model pack is installed).
class NativeCurrencyClassifierProvider implements CurrencyClassifierProvider {
  NativeCurrencyClassifierProvider([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/specialist');

  final MethodChannel _channel;

  @override
  String get modelId => 'inr-currency-mobilenetv3-int8';

  @override
  Future<bool> get isAvailable async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('status');
      return (status?['currencyModelLoaded'] as bool?) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Map<InrDenomination, double>> classifyNote(CapturedFrame frame) async {
    final rgb = frame.rgbBytes;
    if (rgb == null || frame.width <= 0 || frame.height <= 0) return const {};
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'classifyCurrencyRgb',
        {'rgbBytes': rgb, 'width': frame.width, 'height': frame.height},
      );
      if (res == null || (res['available'] as bool?) != true) return const {};
      final rawScores = (res['scores'] as Map?) ?? const {};
      final out = <InrDenomination, double>{};
      for (final entry in rawScores.entries) {
        final v = int.tryParse(entry.key.toString());
        if (v == null) continue;
        final denom = InrDenomination.values.firstWhere(
          (d) => d.value == v,
          orElse: () => InrDenomination.uncertain,
        );
        if (denom != InrDenomination.uncertain) {
          out[denom] = (entry.value as num).toDouble();
        }
      }
      return out;
    } on MissingPluginException {
      return const {};
    }
  }
}

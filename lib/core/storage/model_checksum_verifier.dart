import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../errors/openetra_failure.dart';

/// Streaming SHA-256 verifier for offline AI model integrity checks.
class ModelChecksumVerifier {
  const ModelChecksumVerifier();

  /// Computes lowercase hex SHA-256 digest using buffered chunk reading.
  Future<String> computeSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ModelNotLoadedFailure('Model file missing at $filePath');
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  /// Computes SHA-256 directly on an in-memory byte array.
  String computeBytesSha256(List<int> bytes) {
    return sha256.convert(bytes).toString().toLowerCase();
  }

  /// Verifies [filePath] against [expectedSha256] (case-insensitive).
  /// Throws [ModelIntegrityFailure] on mismatch.
  Future<String> verifyOrThrow({
    required String filePath,
    required String expectedSha256,
    String? modelId,
  }) async {
    final normalizedExpected = expectedSha256.trim().toLowerCase();
    if (normalizedExpected.length != 64) {
      throw ModelIntegrityFailure(
        'Invalid SHA-256 checksum pin for ${modelId ?? filePath}',
      );
    }
    final actual = await computeSha256(filePath);
    if (actual != normalizedExpected) {
      throw ModelIntegrityFailure(
        'Checksum mismatch for ${modelId ?? filePath}: '
        'expected $normalizedExpected, got $actual',
      );
    }
    return actual;
  }

  /// Verifies UTF-8 JSON manifest content hash if needed.
  String computeUtf8Sha256(String content) =>
      computeBytesSha256(utf8.encode(content));
}

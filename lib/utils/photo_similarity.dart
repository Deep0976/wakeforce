import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Compares two photos on-device using an average-hash (aHash) perceptual
/// fingerprint, so a wake-time photo can be checked against the reference
/// photo saved at alarm setup -- no network/cloud call needed.
class PhotoSimilarity {
  // A coarse 8x8 grid tolerates the camera angle/lighting shifting between
  // the setup photo and the wake-time retake -- a finer grid (e.g. 16x16)
  // encodes exact pixel position too precisely and rejects the same book
  // photographed from a slightly different angle.
  static const _hashSize = 8; // 8x8 = 64-bit hash
  // ~37% of bits was far too loose (accepted unrelated photos); ~14% turned
  // out too strict (rejected the same page re-shot under different lighting
  // at wake-time). ~22% is the middle ground: still rejects a genuinely
  // different photo while tolerating normal lighting/angle drift.
  static const defaultMaxDistance = 14;

  // Center-crop keep-fractions hashed for both photos, so a book shot
  // wider/narrower or from a different distance/angle than the reference
  // can still align on at least one crop pair -- a single whole-frame hash
  // treats any framing difference as a content difference, since aHash
  // bakes brightness into a fixed absolute grid position.
  static const _cropFractions = [1.0, 0.85, 0.7];

  /// Returns true if [referencePath] and [capturedPath] look like the same
  /// scene. Returns false (never throws) if either photo can't be decoded.
  static Future<bool> isSimilar(
    String referencePath,
    String capturedPath, {
    int maxDistance = defaultMaxDistance,
  }) async {
    final results = await Future.wait([
      compute(_computeHashes, referencePath),
      compute(_computeHashes, capturedPath),
    ]);
    final hashesA = results[0];
    final hashesB = results[1];
    if (hashesA == null || hashesB == null) return false;

    var best = _hashSize * _hashSize; // worst possible distance
    for (final a in hashesA) {
      for (final b in hashesB) {
        final d = _hammingDistance(a, b);
        if (d < best) best = d;
      }
    }
    return best <= maxDistance;
  }

  static List<BigInt>? _computeHashes(String path) {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return [for (final f in _cropFractions) _hashForCrop(decoded, f)];
  }

  static BigInt _hashForCrop(img.Image source, double keepFraction) {
    var cropped = source;
    if (keepFraction < 1.0) {
      final cropW = (source.width * keepFraction).round();
      final cropH = (source.height * keepFraction).round();
      cropped = img.copyCrop(
        source,
        x: ((source.width - cropW) / 2).round(),
        y: ((source.height - cropH) / 2).round(),
        width: cropW,
        height: cropH,
      );
    }
    final resized =
        img.copyResize(cropped, width: _hashSize, height: _hashSize);
    final gray = img.grayscale(resized);

    final values = <int>[];
    for (var y = 0; y < _hashSize; y++) {
      for (var x = 0; x < _hashSize; x++) {
        values.add(gray.getPixel(x, y).r.toInt());
      }
    }
    final avg = values.reduce((a, b) => a + b) / values.length;

    var hash = BigInt.zero;
    for (final v in values) {
      hash = (hash << 1) | (v >= avg ? BigInt.one : BigInt.zero);
    }
    return hash;
  }

  static int _hammingDistance(BigInt a, BigInt b) {
    var xor = a ^ b;
    var count = 0;
    while (xor > BigInt.zero) {
      if (xor & BigInt.one == BigInt.one) count++;
      xor >>= 1;
    }
    return count;
  }
}

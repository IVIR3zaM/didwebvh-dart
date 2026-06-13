import 'dart:convert';

import 'package:didwebvh_core/src/crypto/base58btc.dart';
import 'package:didwebvh_core/src/crypto/multihash.dart';

/// Computes the pre-rotation commitment hash for a future key: the
/// multihash+multibase of the UTF-8 bytes of the multikey string.
/// See spec §3.5 (pre-rotation).
///
/// Faithful port of the Java `PreRotationHashGenerator`.
abstract final class PreRotationHashGenerator {
  /// Computes the pre-rotation hash of [multikeyPublicKey].
  static String generateHash(String multikeyPublicKey) {
    final keyBytes = utf8.encode(multikeyPublicKey);
    final multihash = MultihashUtil.hashAndEncode(keyBytes);
    return Base58Btc.encode(multihash);
  }
}

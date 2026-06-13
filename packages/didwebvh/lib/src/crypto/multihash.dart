import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'package:didwebvh/src/core/exceptions.dart';

/// Multihash (varint prefix) + base58btc multibase helpers used for SCID and
/// entry-hash encoding in did:webvh. Currently hard-wired to `sha2-256`.
///
/// Faithful port of the Java `MultihashUtil`. (Dart lint requires
/// lowerCamelCase constant names, so `SHA2_256_CODE` becomes [sha2256Code].)
class MultihashUtil {
  MultihashUtil._();

  /// Multicodec code for `sha2-256` (`0x12`).
  static const int sha2256Code = 0x12;

  /// Digest length of `sha2-256` in bytes.
  static const int sha2256Length = 32;

  /// SHA2-256-hashes [data] and returns the multihash-encoded digest.
  static Uint8List hashAndEncode(List<int> data) {
    final digest = sha256(data);
    return encode(sha2256Code, digest);
  }

  /// Prefixes [digest] with the multihash header `<algorithmCode><length>`.
  static Uint8List encode(int algorithmCode, List<int> digest) {
    final multihash = Uint8List(2 + digest.length)
      ..[0] = algorithmCode
      ..[1] = digest.length
      ..setRange(2, 2 + digest.length, digest);
    return multihash;
  }

  /// Reads the algorithm code from a [multihash].
  static int extractAlgorithm(List<int> multihash) {
    if (multihash.length < 2) {
      throw ValidationException('Multihash too short');
    }
    return multihash[0] & 0xFF;
  }

  /// Reads the digest from a [multihash], validating the declared length.
  static Uint8List extractDigest(List<int> multihash) {
    if (multihash.length < 2) {
      throw ValidationException('Multihash too short');
    }
    final length = multihash[1] & 0xFF;
    if (multihash.length < 2 + length) {
      throw ValidationException(
        'Multihash digest length mismatch: declared $length but only '
        '${multihash.length - 2} bytes available',
      );
    }
    return Uint8List.fromList(multihash.sublist(2, 2 + length));
  }

  /// Computes the SHA2-256 digest of [data].
  static Uint8List sha256(List<int> data) {
    return Uint8List.fromList(crypto.sha256.convert(data).bytes);
  }
}

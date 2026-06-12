import 'dart:typed_data';

import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:didwebvh_core/src/crypto/base58btc.dart';

/// Encodes and decodes W3C Multikey public keys
/// (`z<base58btc(<varint-codec> || <raw-key>)>`). Only Ed25519 (codec
/// `0xed01`) is supported today — matching did:webvh v1.0.
///
/// Faithful port of the Java `MultikeyUtil`.
class MultikeyUtil {
  MultikeyUtil._();

  static const List<int> _ed25519Prefix = [0xed, 0x01];

  /// Key-type identifier for Ed25519.
  static const String ed25519KeyType = 'Ed25519';

  /// Encodes [publicKeyBytes] of type [keyType] as a multikey string.
  static String encode(String keyType, List<int> publicKeyBytes) {
    if (keyType != ed25519KeyType) {
      throw ValidationException('Unsupported key type: $keyType');
    }
    final prefixed = Uint8List.fromList([..._ed25519Prefix, ...publicKeyBytes]);
    return Base58Btc.encodeMultibase(prefixed);
  }

  /// Decodes the raw public-key bytes from a [multikey] string.
  static Uint8List decode(String multikey) {
    final decoded = Base58Btc.decodeMultibase(multikey);
    if (decoded.length < 2) {
      throw ValidationException('Multikey too short');
    }
    if (decoded[0] != _ed25519Prefix[0] || decoded[1] != _ed25519Prefix[1]) {
      throw ValidationException(_unknownPrefixMessage(decoded));
    }
    return Uint8List.fromList(decoded.sublist(2));
  }

  /// Returns the key type encoded in a [multikey] string.
  static String keyTypeFromMultikey(String multikey) {
    final decoded = Base58Btc.decodeMultibase(multikey);
    if (decoded.length >= 2 &&
        decoded[0] == _ed25519Prefix[0] &&
        decoded[1] == _ed25519Prefix[1]) {
      return ed25519KeyType;
    }
    throw ValidationException(_unknownPrefixMessage(decoded));
  }

  static String _unknownPrefixMessage(Uint8List decoded) {
    final b0 = (decoded[0] & 0xFF).toRadixString(16).padLeft(2, '0');
    final b1 = (decoded[1] & 0xFF).toRadixString(16).padLeft(2, '0');
    return 'Unknown multicodec prefix: 0x$b0$b1';
  }
}

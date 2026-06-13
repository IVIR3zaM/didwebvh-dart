import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:didwebvh_core/didwebvh_core.dart';

/// Signer backed by a local Ed25519 key pair held in memory.
///
/// Faithful port of Java `LocalKeySigner`. Keys can be generated, loaded from a
/// raw 32-byte seed, or deserialized from a JWK-like JSON object
/// (`{"kty":"OKP","crv":"Ed25519","x":"<base64url>","d":"<base64url>"}`).
///
/// Because `package:cryptography`'s Ed25519 derives the public key
/// asynchronously, [generate] and [fromPrivateKey] are async factories (a
/// direct consequence of the documented async [Signer] delta);
/// [LocalKeySigner.fromJson] is synchronous since the public key is already
/// present in the JWK.
final class LocalKeySigner implements Signer {
  LocalKeySigner._(this._privateKeyBytes, this._publicKeyBytes)
      : _multikey = MultikeyUtil.encode(
          MultikeyUtil.ed25519KeyType,
          _publicKeyBytes,
        );

  /// Loads from a JWK-like JSON string:
  /// `{"kty":"OKP","crv":"Ed25519","x":"<base64url>","d":"<base64url>"}`.
  factory LocalKeySigner.fromJson(String json) {
    final obj = jsonDecode(json) as Map<String, dynamic>;
    final privateBytes = _base64UrlDecode(obj['d'] as String);
    final publicBytes = _base64UrlDecode(obj['x'] as String);
    return LocalKeySigner._(privateBytes, publicBytes);
  }

  static final Ed25519 _algorithm = Ed25519();

  /// Raw 32-byte Ed25519 private key seed (Java's `privateKey.getEncoded()`).
  final Uint8List _privateKeyBytes;

  /// Raw 32-byte Ed25519 public key (Java's `publicKey.getEncoded()`).
  final Uint8List _publicKeyBytes;

  final String _multikey;

  /// Generates a new random Ed25519 key pair.
  static Future<LocalKeySigner> generate() async {
    final keyPair = await _algorithm.newKeyPair();
    final data = await keyPair.extract();
    final publicKey = await keyPair.extractPublicKey();
    return LocalKeySigner._(
      Uint8List.fromList(data.bytes),
      Uint8List.fromList(publicKey.bytes),
    );
  }

  /// Loads from a raw 32-byte Ed25519 private key [seed].
  static Future<LocalKeySigner> fromPrivateKey(List<int> seed) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return LocalKeySigner._(
      Uint8List.fromList(seed),
      Uint8List.fromList(publicKey.bytes),
    );
  }

  /// Serializes the key pair to a JWK-like JSON string.
  String toJson() {
    return jsonEncode(<String, String>{
      'kty': 'OKP',
      'crv': 'Ed25519',
      'x': _base64UrlEncode(_publicKeyBytes),
      'd': _base64UrlEncode(_privateKeyBytes),
    });
  }

  /// The multikey-encoded public key (e.g. `z6Mk...`).
  String get publicKeyMultikey => _multikey;

  @override
  String get keyType => MultikeyUtil.ed25519KeyType;

  @override
  String get verificationMethod => 'did:key:$_multikey#$_multikey';

  @override
  Future<Uint8List> sign(Uint8List data) async {
    try {
      final keyPair = await _algorithm.newKeyPairFromSeed(_privateKeyBytes);
      final signature = await _algorithm.sign(data, keyPair: keyPair);
      return Uint8List.fromList(signature.bytes);
    } on Object catch (e) {
      throw SigningException('Ed25519 signing failed: $e');
    }
  }

  static String _base64UrlEncode(List<int> data) {
    return base64Url.encode(data).replaceAll('=', '');
  }

  static Uint8List _base64UrlDecode(String encoded) {
    return Uint8List.fromList(base64Url.decode(base64Url.normalize(encoded)));
  }
}

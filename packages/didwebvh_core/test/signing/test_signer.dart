import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_core/src/crypto/multikey.dart';

/// An in-test [Signer] backed by a freshly generated Ed25519 key pair,
/// mirroring the anonymous BouncyCastle-backed signer in the Java proof tests.
class TestSigner implements Signer {
  TestSigner._(this._keyPair, this._verificationMethod);

  /// Generates a key pair and builds a `did:key:<mk>#<mk>` verification method.
  static Future<TestSigner> generate() async {
    final keyPair = await Ed25519().newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final multikey =
        MultikeyUtil.encode(MultikeyUtil.ed25519KeyType, pub.bytes);
    return TestSigner._(keyPair, 'did:key:$multikey#$multikey');
  }

  final SimpleKeyPair _keyPair;
  final String _verificationMethod;

  @override
  String get keyType => 'Ed25519';

  @override
  String get verificationMethod => _verificationMethod;

  @override
  Future<Uint8List> sign(Uint8List data) async {
    final signature = await Ed25519().sign(data, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }
}

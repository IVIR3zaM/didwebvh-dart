import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/crypto/base58btc.dart';
import 'package:didwebvh/src/crypto/multikey.dart';
import 'package:didwebvh/src/model/data_integrity_proof.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/signing/proof_generator.dart';

/// Verifies Data Integrity proofs (`eddsa-jcs-2022`) on log entries.
///
/// Faithful port of Java `ProofVerifier`. Java's two `verify` overloads
/// (`LogEntry` / `JsonObject`) become [verify] and [verifyDocument] here.
/// Verification is `async`: the pure-Dart `DartEd25519` in
/// `package:cryptography` exposes only an asynchronous `verify`, so unlike the
/// reference (BouncyCastle, synchronous) the result is a `Future<bool>`.
abstract final class ProofVerifier {
  /// Verifies the cryptographic signature in [proof] over [logEntry].
  ///
  /// The `proof` field is stripped internally before canonicalization.
  static Future<bool> verify(DataIntegrityProof proof, LogEntry logEntry) {
    return verifyDocument(proof, ProofGenerator.toJsonWithoutProof(logEntry));
  }

  /// Verifies [proof] over an arbitrary JSON [document]
  /// (JCS-canonicalized internally).
  static Future<bool> verifyDocument(
    DataIntegrityProof proof,
    Map<String, Object?> document,
  ) {
    final multikey = extractMultikey(proof.verificationMethod);
    final publicKeyBytes = MultikeyUtil.decode(multikey);

    final hashData = ProofGenerator.buildHashData(proof, document);
    final signatureBytes = Base58Btc.decodeMultibase(proof.proofValue!);

    final publicKey =
        SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    return DartEd25519().verify(
      hashData,
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
  }

  /// Checks whether [proof]'s signing key is in [activeUpdateKeys]
  /// (multikey format).
  static bool isAuthorized(
    DataIntegrityProof proof,
    List<String> activeUpdateKeys,
  ) {
    final multikey = extractMultikey(proof.verificationMethod);
    return activeUpdateKeys.contains(multikey);
  }

  /// Extracts the multikey from a `did:key:<multikey>#<multikey>` URI.
  static String extractMultikey(String? verificationMethod) {
    if (verificationMethod == null) {
      throw ValidationException('verificationMethod is null');
    }
    // did:key:z6Mk...#z6Mk...  ->  z6Mk...  (fragment part)
    final hashIdx = verificationMethod.indexOf('#');
    if (hashIdx >= 0) {
      return verificationMethod.substring(hashIdx + 1);
    }
    // Fallback: strip did:key: prefix
    const prefix = 'did:key:';
    if (verificationMethod.startsWith(prefix)) {
      return verificationMethod.substring(prefix.length);
    }
    throw ValidationException(
      'Cannot extract multikey from verificationMethod: $verificationMethod',
    );
  }
}

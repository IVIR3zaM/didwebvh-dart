import 'dart:typed_data';

import 'package:didwebvh/src/crypto/base58btc.dart';
import 'package:didwebvh/src/crypto/jcs.dart';
import 'package:didwebvh/src/crypto/multihash.dart';
import 'package:didwebvh/src/model/data_integrity_proof.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/signing/signer.dart';

/// Generates Data Integrity proofs for log entries using `eddsa-jcs-2022`.
///
/// Faithful port of Java `ProofGenerator`. [generate] is `async` because the
/// ported [Signer.sign] is async (the documented architectural delta); the
/// hash-construction step [buildHashData] stays synchronous, matching Java.
abstract final class ProofGenerator {
  /// Generates a Data Integrity proof over a [logEntry] using [signer].
  ///
  /// The `proof` field is stripped internally before canonicalization.
  static Future<DataIntegrityProof> generate(
    Signer signer,
    LogEntry logEntry,
  ) async {
    final proof = DataIntegrityProof.defaults()
      ..verificationMethod = signer.verificationMethod
      ..created = _formatInstant(DateTime.now());

    final doc = toJsonWithoutProof(logEntry);
    final hashData = buildHashData(proof, doc);
    final signature = await signer.sign(hashData);
    proof.proofValue = Base58Btc.encodeMultibase(signature);
    return proof;
  }

  /// Builds the `eddsa-jcs-2022` hash-to-sign:
  /// `SHA256(JCS(proofConfig)) || SHA256(JCS(document))`, where `proofConfig`
  /// is [proof] without `proofValue`.
  static Uint8List buildHashData(
    DataIntegrityProof proof,
    Map<String, Object?> document,
  ) {
    final proofConfig = proof.toJson(omitNull: true)..remove('proofValue');
    final proofHash =
        MultihashUtil.sha256(Jcs.canonicalizeValue(proofConfig));
    final docHash = MultihashUtil.sha256(Jcs.canonicalizeValue(document));
    final out = Uint8List(proofHash.length + docHash.length)
      ..setRange(0, proofHash.length, proofHash)
      ..setRange(proofHash.length, proofHash.length + docHash.length, docHash);
    return out;
  }

  /// Serializes a [logEntry] to a JSON map with the `proof` key removed.
  static Map<String, Object?> toJsonWithoutProof(LogEntry logEntry) {
    return logEntry.toJson(omitNull: true)..remove('proof');
  }

  /// Formats [instant] as `yyyy-MM-dd'T'HH:mm:ss'Z'` in UTC, matching Java's
  /// `DateTimeFormatter` used by the reference (seconds precision, `Z`).
  static String _formatInstant(DateTime instant) {
    final u = instant.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }
}

import 'dart:convert';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_core/src/crypto/base58btc.dart';
import 'package:didwebvh_core/src/crypto/entry_hash_generator.dart';

import '../signing/test_signer.dart';

/// Shared helpers for the validation tests, mirroring the static helpers in
/// Java's `LogChainValidatorTest` (reused by `WitnessValidatorTest`).

/// Creates a fresh in-test signer (Java `makeTestSigner`).
Future<Signer> makeTestSigner() => TestSigner.generate();

/// Extracts the multikey from a `did:key:<mk>#<mk>` verification method,
/// matching Java's `extractMultikey`.
String extractMultikey(String verificationMethod) {
  final hash = verificationMethod.indexOf('#');
  return hash >= 0
      ? verificationMethod.substring(hash + 1)
      : verificationMethod.substring('did:key:'.length);
}

/// Deep-copies a decoded JSON object (Java `JsonObject.deepCopy`).
Map<String, Object?> deepCopyState(Map<String, Object?> state) =>
    (jsonDecode(jsonEncode(state)) as Map).cast<String, Object?>();

/// An ISO-8601 instant string for "now" (Java `Instant.now().toString()`).
String nowIso() => DateTime.now().toUtc().toIso8601String();

/// Builds an update entry on top of [previous] (Java `buildUpdateEntry`).
Future<LogEntry> buildUpdateEntry(
  LogEntry previous,
  String did,
  Signer updateSigner, {
  Parameters? changedParams,
  Map<String, Object?>? newState,
  String? versionTime,
}) async {
  final newVersion = previous.versionNumber + 1;
  final state = newState ?? deepCopyState(previous.state!);
  final params = changedParams ?? Parameters();

  final preliminary = LogEntry()
    ..versionId = previous.versionId
    ..versionTime = versionTime ?? nowIso()
    ..parameters = params
    ..state = state;

  final entryHash = EntryHashGenerator.generate(
    preliminary.toJsonLine(),
    previous.versionId!,
  );
  preliminary.versionId = '$newVersion-$entryHash';

  final proof = await ProofGenerator.generate(updateSigner, preliminary);
  return preliminary..proof = [proof];
}

/// Builds a proof over an arbitrary JSON document (Java `signDocument`).
Future<DataIntegrityProof> signDocument(
  Signer s,
  Map<String, Object?> doc,
) async {
  final proof = DataIntegrityProof.defaults()
    ..verificationMethod = s.verificationMethod
    ..created = nowIso();
  final hashData = ProofGenerator.buildHashData(proof, doc);
  final signature = await s.sign(hashData);
  return proof..proofValue = Base58Btc.encodeMultibase(signature);
}

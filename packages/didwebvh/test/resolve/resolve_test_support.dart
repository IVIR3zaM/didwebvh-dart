import 'dart:convert';

import 'package:didwebvh/didwebvh.dart';

import '../validate/validation_test_helpers.dart';

/// Shared helpers for the resolve tests, mirroring Java `ResolveTestSupport`
/// (reuses the validation helpers for signers and `buildUpdateEntry`).

/// Builds a witness proof collection over `{"versionId": <versionId>}` signed
/// by [witnessSigner] (Java `ResolveTestSupport.witnessProofs`).
Future<WitnessProofCollection> witnessProofs(
  String versionId,
  Signer witnessSigner,
) async {
  final doc = <String, Object?>{'versionId': versionId};
  final proof = await signDocument(witnessSigner, doc);
  return WitnessProofCollection([
    WitnessProofEntry.of(versionId, [proof]),
  ]);
}

/// Serializes a witness proof collection to the bare `did-witness.json` array
/// form (Java `JsonSupport.compact().toJson(proofs.getEntries())`).
String proofsToJson(WitnessProofCollection proofs) => jsonEncode(
      [for (final e in proofs.entries) e.toJson(omitNull: true)],
    );

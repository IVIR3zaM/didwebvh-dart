import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:didwebvh/src/model/version_id.dart';
import 'package:didwebvh/src/signing/proof_verifier.dart';
import 'package:didwebvh/src/validate/witness_validation_result.dart';
import 'package:didwebvh/src/witness/witness_config.dart';
import 'package:didwebvh/src/witness/witness_entry.dart';
import 'package:didwebvh/src/witness/witness_proof_collection.dart';

/// Validates witness proofs for entries that require witnessing.
///
/// Faithful port of Java `WitnessValidator`. [validate] is `async`: the ported
/// [ProofVerifier.verifyDocument] returns a `Future<bool>` (the documented
/// async delta).
class WitnessValidator {
  /// Validate witness proofs for entries starting at [fromEntryIndex].
  ///
  /// Spec §3.7.8 (lines 1244-1247, 1286-1304): a witness proof at versionId V
  /// implicitly approves every prior log entry. The DID Controller is expected
  /// to prune `did-witness.json` so only the latest proof per witness remains,
  /// and resolvers MUST accept this. Proofs whose `versionId` is not present in
  /// the published log are ignored.
  ///
  /// For each log entry with active witnessing, this validator counts the
  /// distinct authorized witnesses that have signed at least one valid proof at
  /// a versionId in the published log whose version number is greater than or
  /// equal to the entry's. If that count meets the entry's threshold the entry
  /// is witnessed.
  Future<WitnessValidationResult> validate(
    List<LogEntry> entries,
    WitnessProofCollection? witnessProofs,
    int fromEntryIndex,
  ) async {
    if (witnessProofs == null) {
      return WitnessValidationResult.failure(
        -1,
        'witness proofs collection is null',
      );
    }

    final publishedVersionNumbers = _publishedVersionNumbers(entries);
    final verifiedProofs =
        await _verifyProofs(witnessProofs, publishedVersionNumbers);

    var activeParams = Parameters();
    for (var i = 0; i < fromEntryIndex && i < entries.length; i++) {
      final ep = entries[i].parameters;
      if (ep != null) {
        activeParams = activeParams.merge(ep);
      }
    }

    for (var i = fromEntryIndex; i < entries.length; i++) {
      final entry = entries[i];
      final entryParams = entry.parameters ?? Parameters();
      final priorConfig = activeParams.witness;
      activeParams = activeParams.merge(entryParams);
      final afterConfig = activeParams.witness;

      // Spec §3.7.5 (lines 884-889): a replacement witness list "becomes
      // active AFTER the new DID log has been published". So while witnesses
      // are already active, every entry — including one that changes the list
      // (e.g. two witnesses down to one) or sets it to {} — MUST be witnessed
      // by the list in effect BEFORE this entry; the replacement only governs
      // subsequent entries. This also stops an attacker from shrinking or
      // disabling oversight in a single forged entry and slipping it past the
      // resolver. The sole exception is the first activation, where there is
      // no prior list.
      final priorActive = priorConfig != null && priorConfig.isActive;
      final afterActive = afterConfig != null && afterConfig.isActive;
      WitnessConfig witnessConfig;
      if (priorActive) {
        witnessConfig = priorConfig;
      } else if (afterActive) {
        // First activation ({} -> active): the new list approves this entry.
        witnessConfig = afterConfig;
      } else {
        continue;
      }

      final entryVersion = VersionId.parse(entry.versionId).versionNumber;
      final authorized = witnessConfig.witnesses;

      final approvers = <String>{};
      for (final vp in verifiedProofs) {
        if (vp.versionNumber < entryVersion) {
          continue;
        }
        final matched = _matchAuthorizedWitness(vp.signerMultikey, authorized);
        if (matched != null) {
          approvers.add(matched);
        }
      }

      if (approvers.length < witnessConfig.threshold) {
        return WitnessValidationResult.failure(
          i,
          'insufficient witness proofs for entry ${entry.versionId}'
              ': need ${witnessConfig.threshold}, got ${approvers.length}',
        );
      }
    }

    return WitnessValidationResult.success();
  }

  /// Map from each entry's full versionId string to its parsed version number.
  static Map<String, int> _publishedVersionNumbers(List<LogEntry> entries) {
    final out = <String, int>{};
    for (final e in entries) {
      out[e.versionId!] = VersionId.parse(e.versionId).versionNumber;
    }
    return out;
  }

  /// Verify every proof in the witness file once and keep the ones that
  /// (a) are published, (b) verify against `{"versionId": "<vid>"}`. Returns
  /// one entry per verified proof with the signer's multikey already extracted.
  static Future<List<_VerifiedProof>> _verifyProofs(
    WitnessProofCollection witnessProofs,
    Map<String, int> publishedVersionNumbers,
  ) async {
    final out = <_VerifiedProof>[];
    for (final entry in witnessProofs.entries) {
      final versionNumber = publishedVersionNumbers[entry.versionId];
      if (versionNumber == null) {
        // Spec line 1294: ignore proofs for unpublished entries.
        continue;
      }
      final signedDoc = <String, Object?>{'versionId': entry.versionId};
      final proofs = entry.proof;
      if (proofs == null) {
        continue;
      }
      for (final proof in proofs) {
        if (!await ProofVerifier.verifyDocument(proof, signedDoc)) {
          continue;
        }
        final signerMultikey =
            ProofVerifier.extractMultikey(proof.verificationMethod);
        out.add(_VerifiedProof(versionNumber, signerMultikey));
      }
    }
    return out;
  }

  /// Return the canonical authorized-witness id matching [signerMultikey], or
  /// `null` if not authorized. Accepts the spec form `did:key:<multikey>` and
  /// the bare-multikey form some implementations emit; comparison is on the
  /// multikey portion.
  static String? _matchAuthorizedWitness(
    String signerMultikey,
    List<WitnessEntry> authorized,
  ) {
    for (final w in authorized) {
      if (signerMultikey == _stripDidKey(w.id)) {
        return w.id;
      }
    }
    return null;
  }

  static String? _stripDidKey(String? witnessId) {
    if (witnessId == null) {
      return null;
    }
    const prefix = 'did:key:';
    return witnessId.startsWith(prefix)
        ? witnessId.substring(prefix.length)
        : witnessId;
  }
}

/// Pre-verified proof entry indexed by its (published) version number and
/// signer.
class _VerifiedProof {
  _VerifiedProof(this.versionNumber, this.signerMultikey);

  final int versionNumber;
  final String signerMultikey;
}

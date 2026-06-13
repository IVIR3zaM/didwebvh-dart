import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:test/test.dart';

import 'interop_helpers.dart';

/// Port of Java `InteropNegativeCrossDidWitnessReplayTest`: a witness proof
/// from another DID, replayed verbatim, must be rejected because its versionId
/// is not present in this DID's published log (spec §3.7.8).
void main() {
  test('replayedCrossDidWitnessProofIsRejected', () async {
    final entries =
        parseJsonl(readInterop('negative-cross-did-witness-replay-ts/did.jsonl'));
    final proofs = parseProofs(
      readInterop('negative-cross-did-witness-replay-ts/did-witness.json'),
    );

    final result = await WitnessValidator().validate(entries, proofs, 0);

    expect(
      result.valid,
      isFalse,
      reason: 'replayed cross-DID witness proof must be rejected; '
          'got: ${result.failureReason}',
    );
  });
}

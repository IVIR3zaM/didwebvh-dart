import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

import 'interop_helpers.dart';

/// Port of Java `InteropRustWitnessProofsTest`: a single pruned proof at the
/// latest versionId covers all prior entries (witness-update), and witness ids
/// encoded as bare multikeys are accepted (witness-threshold).
void main() {
  for (final vector in const ['witness-update', 'witness-threshold']) {
    test('validatesRustWitnessProofs $vector', () async {
      final entries = parseJsonl(readInterop('$vector-rust/did.jsonl'));
      final proofs = parseProofs(readInterop('$vector-rust/did-witness.json'));

      final result = await WitnessValidator().validate(entries, proofs, 0);

      expect(
        result.valid,
        isTrue,
        reason: 'rust $vector witness proofs must verify; '
            'failure: ${result.failureReason}',
      );
    });
  }
}

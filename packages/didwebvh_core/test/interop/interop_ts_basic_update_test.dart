import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:test/test.dart';

import 'interop_helpers.dart';

/// Port of Java `InteropTsBasicUpdateTest`: the TS log always serialises
/// `nextKeyHashes: []`, `witness: {}` and `watchers: []`; the validator must
/// treat these as "feature not active", not reject them.
void main() {
  test('validatesTsBasicUpdateLog', () async {
    final jsonl = readInterop('basic-update-ts/did.jsonl');
    final entries = parseJsonl(jsonl);

    final result = await LogChainValidator().validate(entries, null);

    expect(
      result.valid,
      isTrue,
      reason: 'TS basic-update log must validate; '
          'failure: ${result.failureReason}',
    );
  });
}

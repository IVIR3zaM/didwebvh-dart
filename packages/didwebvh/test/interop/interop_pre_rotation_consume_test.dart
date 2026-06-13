import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

import 'interop_helpers.dart';

/// Port of Java `InteropPreRotationConsumeTest`: while Key Pre-Rotation is
/// active, each entry is signed by its own (previously committed) updateKeys.
void main() {
  for (final impl in const ['rust', 'java-eecc']) {
    test('validatesPreRotationConsumeLog $impl', () async {
      final jsonl = readInterop('pre-rotation-consume-$impl/did.jsonl');
      final entries = parseJsonl(jsonl);

      final result = await LogChainValidator().validate(entries, null);

      expect(
        result.valid,
        isTrue,
        reason: 'pre-rotation-consume $impl log must validate; '
            'failure: ${result.failureReason}',
      );
    });
  }
}

import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

import 'interop_helpers.dart';

/// Port of Java `InteropJavaEeccLogsTest`: java-eecc-produced logs must
/// validate once the empty `witness: {}` round-trip is correct (GitHub #2).
void main() {
  const vectors = [
    'basic-update',
    'deactivate',
    'key-rotation',
    'multi-update',
    'services',
    'witness-update',
  ];

  for (final vector in vectors) {
    test('validatesJavaEeccLog $vector', () async {
      final jsonl = readInterop('$vector-java-eecc/did.jsonl');
      final entries = parseJsonl(jsonl);

      final result = await LogChainValidator().validate(entries, null);

      expect(
        result.valid,
        isTrue,
        reason: 'java-eecc $vector log must validate; '
            'failure: ${result.failureReason}',
      );
    });
  }
}

import 'package:didwebvh_core/src/model/log_entry.dart';
import 'package:test/test.dart';

import '../support/test_vectors.dart';

/// Acceptance for iteration 3: the model must round-trip every shared log-entry
/// vector. Parsing a JSONL line, re-serializing it via [LogEntry.toJsonLine],
/// and re-parsing must yield an equal entry (stable, lossless de/serialization).
void main() {
  const logVectors = <String>[
    'test-vectors/first-log-entry-good.jsonl',
    'test-vectors/multi-entry-log.jsonl',
    'test-vectors/deactivated-did.jsonl',
    'test-vectors/migrated-did.jsonl',
    'test-vectors/pre-rotation-log.jsonl',
  ];

  for (final vector in logVectors) {
    test('round-trips every entry of $vector', () {
      final lines = TestVectors.readVector(vector)
          .split('\n')
          .where((line) => line.trim().isNotEmpty);
      var count = 0;
      for (final line in lines) {
        final entry = LogEntry.fromJsonLine(line);
        final reparsed = LogEntry.fromJsonLine(entry.toJsonLine());
        expect(reparsed, entry, reason: 'entry ${entry.versionId} of $vector');
        expect(entry.toJsonLine(), isNot(contains('\n')));
        count++;
      }
      expect(count, greaterThan(0));
    });
  }
}

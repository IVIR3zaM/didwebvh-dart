import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

import 'interop_helpers.dart';

/// Port of Java `InteropEmptyWitnessObjectTest`: an empty `witness: {}` object
/// in parameters must parse to an inactive config (no NPE / no exception).
void main() {
  test('parsesEmptyWitnessObjectWithoutNpe', () {
    final line = readInterop('basic-create-python/did.jsonl').trim();

    final entry = LogEntry.fromJsonLine(line);

    final witness = entry.parameters!.witness;
    expect(witness, isNotNull);
    expect(witness!.isActive, isFalse);
    expect(witness.witnesses, isEmpty);
    expect(witness.threshold, isZero);
  });
}

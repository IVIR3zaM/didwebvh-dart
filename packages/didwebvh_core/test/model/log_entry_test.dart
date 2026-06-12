import 'package:didwebvh_core/src/model/data_integrity_proof.dart';
import 'package:didwebvh_core/src/model/log_entry.dart';
import 'package:didwebvh_core/src/model/parameters.dart';
import 'package:test/test.dart';

void main() {
  group('LogEntry', () {
    test('toJsonLine is single line and round-trips', () {
      final state = <String, Object?>{'id': 'did:webvh:QmSCID:example.com'};

      final proof = DataIntegrityProof.defaults()
        ..verificationMethod = 'did:key:z6MkA#z6MkA'
        ..created = '2026-04-15T00:00:00Z'
        ..proofValue = 'zSig';

      final entry = LogEntry()
        ..versionId = '1-QmEntry'
        ..versionTime = '2026-04-15T00:00:00Z'
        ..parameters = (Parameters()..method = 'did:webvh:1.0')
        ..state = state
        ..proof = [proof];

      final line = entry.toJsonLine();
      expect(line, isNot(contains('\n')));
      final decoded = LogEntry.fromJsonLine(line);
      expect(decoded, entry);
      expect(decoded.versionNumber, 1);
      expect(decoded.entryHash, 'QmEntry');
    });

    test('handles empty parameters', () {
      final entry = LogEntry()
        ..versionId = '2-QmNext'
        ..parameters = Parameters()
        ..state = <String, Object?>{};
      final line = entry.toJsonLine();
      expect(line, contains('"parameters":{}'));
      expect(LogEntry.fromJsonLine(line), entry);
    });
  });
}

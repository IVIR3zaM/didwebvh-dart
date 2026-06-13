import 'package:didwebvh/src/crypto/scid_generator.dart';
import 'package:didwebvh/src/model/data_integrity_proof.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:test/test.dart';

import '../support/test_vectors.dart';

LogEntry _buildPreliminaryEntry() {
  final placeholder = ScidGenerator.placeholder();
  final params = Parameters()
    ..method = 'did:webvh:1.0'
    ..scid = placeholder
    ..updateKeys = ['z6MkTest'];
  return LogEntry()
    ..versionId = placeholder
    ..versionTime = '2024-01-01T00:00:00Z'
    ..parameters = params
    ..state = {'id': 'did:webvh:$placeholder:example.com'};
}

void main() {
  group('ScidGenerator', () {
    test('generate produces spec SCID length', () {
      final scid = ScidGenerator.generate(_buildPreliminaryEntry());
      expect(scid.length, 46);
    });

    test('generate is deterministic', () {
      final entry = _buildPreliminaryEntry();
      expect(
        ScidGenerator.generate(entry),
        ScidGenerator.generate(entry),
      );
    });

    test('verify round trip', () {
      final preliminary = _buildPreliminaryEntry();
      final scid = ScidGenerator.generate(preliminary);

      final placeholder = ScidGenerator.placeholder();
      final json = preliminary.toJsonLine().replaceAll(placeholder, scid);
      final entryWithScid = LogEntry.fromJsonLine(json);

      final fakeProof = DataIntegrityProof.defaults()
        ..proofValue = 'zFakeProof';
      entryWithScid.proof = [fakeProof];

      expect(ScidGenerator.verify(scid, entryWithScid), isTrue);
    });

    test('verify rejects tampered entry', () {
      final preliminary = _buildPreliminaryEntry();
      final scid = ScidGenerator.generate(preliminary);

      final placeholder = ScidGenerator.placeholder();
      final json = preliminary.toJsonLine().replaceAll(placeholder, scid);
      final tampered = json.replaceAll('example.com', 'evil.com');
      final tamperedEntry = LogEntry.fromJsonLine(tampered);

      expect(ScidGenerator.verify(scid, tamperedEntry), isFalse);
    });

    test('verifies the SCID of a vendored interop first log entry', () {
      final line = TestVectors.readVector(
        '${TestVectors.specRoot}/first-log-entry-good.jsonl',
      ).trim().split('\n').first;
      final entry = LogEntry.fromJsonLine(line);
      final scid = entry.parameters!.scid!;
      expect(ScidGenerator.verify(scid, entry), isTrue);
    });
  });
}

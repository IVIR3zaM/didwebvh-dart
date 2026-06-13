import 'package:didwebvh/src/crypto/entry_hash_generator.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:test/test.dart';

import '../support/test_vectors.dart';

void main() {
  group('EntryHashGenerator', () {
    test('generate produces base58btc result', () {
      const json = '{"versionId":"placeholder","versionTime":'
          '"2024-01-01T00:00:00Z","parameters":{},'
          '"state":{"id":"did:example:123"}}';
      final hash = EntryHashGenerator.generate(json, 'predecessor-id');
      // Spec 3.7.4: base58btc(multihash(JCS(entry))) — no multibase prefix.
      // A SHA-256 multihash encoded in base58btc starts with "Qm", 46 chars.
      expect(hash.length, 46);
      expect(hash.startsWith('Qm'), isTrue);
    });

    test('generate is deterministic', () {
      const json = '{"versionId":"v","versionTime":"2024-01-01T00:00:00Z",'
          '"parameters":{},"state":{}}';
      expect(
        EntryHashGenerator.generate(json, 'pred'),
        EntryHashGenerator.generate(json, 'pred'),
      );
    });

    test('different predecessor produces different hash', () {
      const json = '{"versionId":"v","versionTime":"2024-01-01T00:00:00Z",'
          '"parameters":{},"state":{}}';
      expect(
        EntryHashGenerator.generate(json, 'pred1'),
        isNot(EntryHashGenerator.generate(json, 'pred2')),
      );
    });

    test('verify matching entry', () {
      final entry = LogEntry()
        ..versionId = 'placeholder'
        ..versionTime = '2024-01-01T00:00:00Z'
        ..parameters = (Parameters()..method = 'did:webvh:1.0')
        ..state = {'id': 'did:example:123'};

      const predecessorId = 'some-scid';
      final hash = EntryHashGenerator.generate(
        entry.toJsonLine(),
        predecessorId,
      );

      entry.versionId = '1-$hash';
      expect(EntryHashGenerator.verify(entry, predecessorId), isTrue);
    });

    test('verify rejects tampered state', () {
      final entry = LogEntry()
        ..versionId = 'placeholder'
        ..versionTime = '2024-01-01T00:00:00Z'
        ..parameters = Parameters()
        ..state = {'id': 'did:example:123'};

      const predecessorId = 'some-scid';
      final hash = EntryHashGenerator.generate(
        entry.toJsonLine(),
        predecessorId,
      );

      entry
        ..versionId = '1-$hash'
        ..state = {'id': 'did:example:TAMPERED'};
      expect(EntryHashGenerator.verify(entry, predecessorId), isFalse);
    });

    test('verifies the entry-hash chain of a vendored interop log', () {
      final lines = TestVectors.readVector(
        '${TestVectors.specRoot}/multi-entry-log.jsonl',
      ).trim().split('\n');
      final entries = lines.map(LogEntry.fromJsonLine).toList();

      // The first entry's predecessor versionId is the SCID; thereafter it is
      // the previous entry's full versionId (spec §4.2).
      var predecessor = entries.first.parameters!.scid!;
      for (final entry in entries) {
        expect(
          EntryHashGenerator.verify(entry, predecessor),
          isTrue,
          reason: 'entry ${entry.versionId} should hash from $predecessor',
        );
        predecessor = entry.versionId!;
      }
    });
  });
}

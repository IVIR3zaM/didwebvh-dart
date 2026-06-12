import 'dart:io';

import 'package:test/test.dart';

import 'support/test_vectors.dart';

void main() {
  group('vendored test vectors', () {
    test('spec and interop files are present and loadable', () {
      // A representative file from each vendored root.
      final specLog = TestVectors.readVector(
        '${TestVectors.specRoot}/multi-entry-log.jsonl',
      );
      expect(specLog.trim(), isNotEmpty);
      expect(specLog, contains('versionId'));

      final interop = TestVectors.readVector(
        '${TestVectors.interopRoot}/basic-create-python/did.jsonl',
      );
      expect(interop.trim(), isNotEmpty);
      expect(interop, contains('versionId'));
    });

    test('missing vector throws a clear error', () {
      expect(
        () => TestVectors.readVector('test-vectors/does-not-exist.jsonl'),
        throwsStateError,
      );
    });

    test('all vendored vector files are present', () {
      // 26 files copied verbatim from the Java reference
      // (didwebvh-core/src/test/resources/{test-vectors,interop}).
      final files = TestVectors.vectorsDir()
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(files, hasLength(26));
    });
  });
}

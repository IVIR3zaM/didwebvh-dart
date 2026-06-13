import 'dart:convert';
import 'dart:io';

import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

/// Verifies that every Data Integrity proof in the vendored interop vectors
/// validates with the Dart `ProofVerifier`. These `did.jsonl` files were
/// produced by the Java/Python/Rust/TS implementations, so passing here proves
/// byte-exact cross-language interop of JCS + multihash + eddsa-jcs-2022.
void main() {
  final interopDir = Directory('test/vectors/interop');

  final vectorFiles = interopDir
      .listSync()
      .whereType<Directory>()
      .map((d) => File('${d.path}/did.jsonl'))
      .where((f) => f.existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  group('interop vector proofs verify', () {
    for (final file in vectorFiles) {
      final name = file.parent.path.split(Platform.pathSeparator).last;

      test(name, () async {
        final lines = file
            .readAsLinesSync()
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(lines, isNotEmpty, reason: 'no log entries in $name');

        for (final line in lines) {
          final raw = (jsonDecode(line) as Map).cast<String, Object?>();
          final proofs = raw['proof'] as List?;
          expect(proofs, isNotNull, reason: 'entry without proof in $name');

          // Byte-exact document: the original entry minus its proof field.
          final document = Map<String, Object?>.of(raw)..remove('proof');

          for (final item in proofs!) {
            final proof =
                DataIntegrityProof.fromJson((item as Map).cast());
            expect(
              await ProofVerifier.verifyDocument(proof, document),
              isTrue,
              reason: 'proof failed to verify in $name '
                  '(${raw['versionId']})',
            );
          }
        }
      });
    }
  });
}

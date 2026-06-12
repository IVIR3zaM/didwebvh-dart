import 'dart:io';

/// Shared loader for the vendored cross-language test vectors under
/// `test/vectors/`.
///
/// These files are copied **verbatim** from the Java reference
/// (`didwebvh-core/src/test/resources/`) and are the cross-language interop
/// contract; they are never edited to make a test pass. This helper mirrors the
/// Java `TestVectors.readResource` loader: it reads a vector file by its path
/// relative to the vectors root and returns its UTF-8 contents.
class TestVectors {
  TestVectors._();

  /// Spec test vectors (Java `RESOURCE_ROOT = "/test-vectors/"`).
  static const String specRoot = 'test-vectors';

  /// Vendored cross-implementation interop vectors.
  static const String interopRoot = 'interop';

  /// Locates the `test/vectors/` directory regardless of the working directory
  /// `dart test` is launched from (package root or repository root).
  static Directory vectorsDir() {
    for (final base in <String>[
      'test/vectors',
      'packages/didwebvh_core/test/vectors',
    ]) {
      final dir = Directory(base);
      if (dir.existsSync()) {
        return dir;
      }
    }
    throw StateError('Could not locate test/vectors directory');
  }

  /// Reads a vector file by its path relative to `test/vectors/`, e.g.
  /// `'test-vectors/multi-entry-log.jsonl'`.
  static String readVector(String relativePath) {
    final file = File('${vectorsDir().path}/$relativePath');
    if (!file.existsSync()) {
      throw StateError('Missing test vector: $relativePath');
    }
    return file.readAsStringSync();
  }
}

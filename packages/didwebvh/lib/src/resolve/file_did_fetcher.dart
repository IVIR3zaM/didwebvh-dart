import 'dart:io';

import 'package:didwebvh/src/core/exceptions.dart';

/// Reads did:webvh resolution artifacts from the local filesystem.
///
/// Faithful port of the Java `FileDidFetcher` (package-private). Reads are
/// synchronous, mirroring Java's `Files.readAllBytes`.
class FileDidFetcher {
  /// Reads the DID log from [filePath].
  String fetchDidLog(String? filePath) => _read(filePath, 'did log');

  /// Reads the witness proofs from [witnessPath].
  String fetchWitnessProofs(String? witnessPath) =>
      _read(witnessPath, 'witness proofs');

  String _read(String? path, String label) {
    if (path == null) {
      throw ResolutionException.withError(
        '$label path is required',
        'invalidDid',
      );
    }
    try {
      return File(path).readAsStringSync();
    } on FileSystemException catch (e) {
      throw ResolutionException.withError(
        'Unable to read $label: $path',
        'notFound',
        e,
      );
    }
  }
}

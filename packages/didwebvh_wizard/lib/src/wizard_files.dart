import 'dart:io';

import 'package:didwebvh_wizard/src/wizard_exception.dart';

/// Standard filenames used by the wizard alongside helpers to read/write them.
///
/// Faithful port of Java `WizardFiles`. Paths are plain strings (Dart has no
/// `java.nio.file.Path`); callers build them with `package:path`.
abstract final class WizardFiles {
  /// The DID log file name (`did.jsonl`).
  static const String didLog = 'did.jsonl';

  /// The controller secret-key file name (`did-secrets.json`).
  static const String didSecrets = 'did-secrets.json';

  /// The witness proofs file name (`did-witness.json`).
  static const String didWitness = 'did-witness.json';

  /// The pre-rotation next-key secret file name (`did-next-key.json`).
  static const String nextKeySecrets = 'did-next-key.json';

  /// The local witness key store directory name (`witnesses`).
  static const String witnessesDir = 'witnesses';

  /// Writes [contents] to [path] as UTF-8, replacing any existing file.
  static void write(String path, String contents) {
    try {
      File(path).writeAsStringSync(contents);
    } on Object catch (e) {
      throw WizardException('Failed to write $path: $e', e);
    }
  }

  /// Reads the UTF-8 contents of [path].
  static String read(String path) {
    try {
      return File(path).readAsStringSync();
    } on Object catch (e) {
      throw WizardException('Failed to read $path: $e', e);
    }
  }

  /// Appends [line] to [path], ensuring the existing contents end in a newline.
  static void appendLine(String path, String line) {
    var existing = '';
    if (File(path).existsSync()) {
      existing = read(path);
      if (existing.isNotEmpty && !existing.endsWith('\n')) {
        existing = '$existing\n';
      }
    }
    write(path, existing + line);
  }
}

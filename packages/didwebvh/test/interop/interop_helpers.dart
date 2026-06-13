import 'dart:convert';

import 'package:didwebvh/didwebvh.dart';

import '../support/test_vectors.dart';

/// Shared loaders for the vendored interop vectors, mirroring the
/// `parseJsonl` / `parseProofs` helpers in the Java interop tests.

/// Reads a file under `test/vectors/interop/`.
String readInterop(String relativePath) =>
    TestVectors.readVector('${TestVectors.interopRoot}/$relativePath');

/// Parses a JSONL log into a list of [LogEntry].
List<LogEntry> parseJsonl(String jsonl) {
  final out = <LogEntry>[];
  for (final line in jsonl.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      out.add(LogEntry.fromJsonLine(trimmed));
    }
  }
  return out;
}

/// Parses a `did-witness.json` (a bare array of witness-proof entries) into a
/// [WitnessProofCollection] (Java `parseProofs`).
WitnessProofCollection parseProofs(String json) {
  final arr = jsonDecode(json) as List;
  return WitnessProofCollection([
    for (final item in arr)
      WitnessProofEntry.fromJson((item as Map).cast<String, Object?>()),
  ]);
}

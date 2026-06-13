import 'dart:convert';

import 'package:didwebvh_core/src/crypto/base58btc.dart';
import 'package:didwebvh_core/src/crypto/jcs.dart';
import 'package:didwebvh_core/src/crypto/multihash.dart';
import 'package:didwebvh_core/src/model/log_entry.dart';

/// Computes the entry-hash portion of a did:webvh `versionId`
/// (`<versionNumber>-<entryHash>`) per spec §4.2: strip the proof, substitute
/// the predecessor `versionId`, JCS-canonicalize, then apply `sha2-256`
/// multihash with base58btc multibase encoding.
///
/// Faithful port of the Java `EntryHashGenerator`.
abstract final class EntryHashGenerator {
  /// Computes the entry hash for [entryJson] given its [predecessorVersionId].
  static String generate(String entryJson, String predecessorVersionId) {
    final entry = (jsonDecode(entryJson) as Map).cast<String, Object?>()
      ..remove('proof')
      ..['versionId'] = predecessorVersionId;
    final canonical = Jcs.canonicalizeValue(entry);
    final multihash = MultihashUtil.hashAndEncode(canonical);
    return Base58Btc.encode(multihash);
  }

  /// Verifies the entry hash of [entry] against its [predecessorVersionId].
  static bool verify(LogEntry entry, String predecessorVersionId) {
    final entryJson = entry.toJsonLine();
    final expectedHash = generate(entryJson, predecessorVersionId);
    return expectedHash == entry.entryHash;
  }
}

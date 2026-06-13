import 'package:didwebvh_core/src/crypto/base58btc.dart';
import 'package:didwebvh_core/src/crypto/jcs.dart';
import 'package:didwebvh_core/src/crypto/multihash.dart';
import 'package:didwebvh_core/src/model/log_entry.dart';
import 'package:didwebvh_core/src/model/parameters.dart';

/// Derives the SCID (Self-Certifying IDentifier) of a did:webvh DID from a
/// preliminary first log entry per spec §3.3: substitute the `{SCID}`
/// placeholder, JCS-canonicalize, then apply `sha2-256` multihash with
/// base58btc multibase encoding.
///
/// Faithful port of the Java `ScidGenerator`.
abstract final class ScidGenerator {
  static const String _scidPlaceholder = '{SCID}';

  /// Derives the SCID for a [preliminaryEntry] (with `{SCID}` placeholders).
  static String generate(LogEntry preliminaryEntry) {
    return _deriveScid(preliminaryEntry.toJsonLine());
  }

  /// Verifies that [scid] is the correct SCID for a [firstEntry].
  static bool verify(String scid, LogEntry firstEntry) {
    // Spec section 3.7.3 verification:
    // 1. Remove proof
    // 2. Replace versionId with "{SCID}"
    // 3. Replace scid in parameters with "{SCID}"
    // 4. String-replace all remaining SCID occurrences with "{SCID}"
    final params = firstEntry.parameters!;
    final resetParams = params.merge(Parameters()..scid = _scidPlaceholder);
    final withoutProof = LogEntry()
      ..versionId = _scidPlaceholder
      ..versionTime = firstEntry.versionTime
      ..parameters = resetParams
      ..state = firstEntry.state;
    final json = withoutProof.toJsonLine();
    final preliminary = json.replaceAll(scid, _scidPlaceholder);
    return scid == _deriveScid(preliminary);
  }

  /// Returns the `{SCID}` placeholder string.
  static String placeholder() => _scidPlaceholder;

  static String _deriveScid(String json) {
    final canonical = Jcs.canonicalize(json);
    final multihash = MultihashUtil.hashAndEncode(canonical);
    return Base58Btc.encode(multihash);
  }
}

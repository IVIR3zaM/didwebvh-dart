import 'package:didwebvh/src/model/log_entry.dart';

/// The result of a DID creation operation.
///
/// Faithful port of Java `CreateDidResult`.
class CreateDidResult {
  /// Creates a result wrapping the [did], first [logEntry], and [logLine].
  CreateDidResult(this.did, this.logEntry, this.logLine);

  /// The full DID string, e.g. `did:webvh:<SCID>:example.com`.
  final String did;

  /// The first log entry.
  final LogEntry logEntry;

  /// The compact JSONL line for `did.jsonl`.
  final String logLine;
}

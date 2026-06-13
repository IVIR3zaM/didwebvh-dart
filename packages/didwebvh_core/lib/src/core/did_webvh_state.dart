import 'dart:convert';

import 'package:didwebvh_core/src/model/log_entry.dart';
import 'package:didwebvh_core/src/model/parameters.dart';
import 'package:didwebvh_core/src/validate/log_chain_validator.dart';
import 'package:didwebvh_core/src/validate/validation_result.dart';
import 'package:didwebvh_core/src/witness/witness_proof_collection.dart';

/// Holds the full mutable state of a did:webvh DID: log entries, witness
/// proofs, and the active parameters after validation.
///
/// Faithful port of Java `DidWebVhState`. As with the reference, this class is
/// **not** thread-safe; callers must synchronise if sharing across isolates.
/// [validate] is `async` (it delegates to the ported async
/// [LogChainValidator]).
class DidWebVhState {
  DidWebVhState._(String did, List<LogEntry> entries, this.witnessProofs)
      : _did = did,
        _logEntries = List<LogEntry>.of(entries);

  /// Create a new state from a freshly created DID (single first entry).
  factory DidWebVhState.from(String did, LogEntry firstEntry) =>
      DidWebVhState._(did, [firstEntry], null);

  /// Build state by parsing a `did.jsonl` string ([jsonl]) for the given [did].
  factory DidWebVhState.fromDidLog(String did, String jsonl) {
    final entries = <LogEntry>[];
    for (final line in jsonl.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        entries.add(LogEntry.fromJsonLine(trimmed));
      }
    }
    return DidWebVhState._(did, entries, null);
  }

  /// Load a previously serialised state (produced by [toJson]).
  factory DidWebVhState.fromJson(String json) {
    final obj = (jsonDecode(json) as Map).cast<String, Object?>();
    final did = obj['did']! as String;
    final entries = <LogEntry>[];
    for (final el in obj['logEntries']! as List) {
      entries.add(LogEntry.fromJsonLine(el as String));
    }
    WitnessProofCollection? witnessProofs;
    final wp = obj['witnessProofs'];
    if (wp is Map) {
      witnessProofs = WitnessProofCollection.fromJson(wp.cast());
    }
    return DidWebVhState._(did, entries, witnessProofs);
  }

  String _did;
  final List<LogEntry> _logEntries;
  Parameters? _activeParameters;
  bool _validated = false;

  /// The witness proofs, or `null` if none were attached.
  WitnessProofCollection? witnessProofs;

  /// Serialize all log entries to a `did.jsonl` string (one entry per line, no
  /// trailing newline).
  String toDidLog() {
    final sb = StringBuffer();
    for (var i = 0; i < _logEntries.length; i++) {
      if (i > 0) {
        sb.write('\n');
      }
      sb.write(_logEntries[i].toJsonLine());
    }
    return sb.toString();
  }

  /// Serialize the full state to JSON for local caching. Load it back with
  /// [DidWebVhState.fromJson].
  String toJson() {
    final obj = <String, Object?>{
      'did': _did,
      'logEntries': [for (final entry in _logEntries) entry.toJsonLine()],
    };
    if (witnessProofs != null) {
      obj['witnessProofs'] = witnessProofs!.toJson(omitNull: true);
    }
    return jsonEncode(obj);
  }

  /// Run full log-chain validation and update [activeParameters].
  ///
  /// Returns the [ValidationResult] — callers may inspect it for failure
  /// details.
  Future<ValidationResult> validate() async {
    final result = await LogChainValidator().validate(_logEntries, _did);
    if (result.valid) {
      _activeParameters = result.activeParameters;
      _validated = true;
    }
    return result;
  }

  /// Append a new entry to the log and mark the state as unvalidated. Call
  /// [validate] afterwards to confirm chain integrity.
  void appendEntry(LogEntry entry) {
    _logEntries.add(entry);
    _validated = false;
    _activeParameters = null;
    final state = entry.state;
    if (state != null && state.containsKey('id')) {
      final entryDid = state['id'];
      if (entryDid is String && entryDid != _did) {
        _did = entryDid;
      }
    }
  }

  /// The DID being represented.
  String get did => _did;

  /// An unmodifiable view of the log entries.
  List<LogEntry> get logEntries => List.unmodifiable(_logEntries);

  /// The active parameters from the last [validate] call, or `null` if the
  /// state has not been validated yet.
  Parameters? get activeParameters => _activeParameters;

  /// Whether the state has been successfully validated since its last change.
  bool get isValidated => _validated;

  /// Returns `true` if the accumulated parameters indicate the DID has been
  /// deactivated. Does not perform cryptographic verification.
  bool get isDeactivated => accumulateParameters().deactivated ?? false;

  /// The last log entry, or `null` if the log is empty.
  LogEntry? get lastEntry =>
      _logEntries.isEmpty ? null : _logEntries[_logEntries.length - 1];

  /// Walk all entries and merge their parameter deltas to get the current
  /// effective parameters, without performing cryptographic verification.
  Parameters accumulateParameters() {
    var params = Parameters.defaults();
    for (final entry in _logEntries) {
      if (entry.parameters != null) {
        params = params.merge(entry.parameters);
      }
    }
    return params;
  }
}

import 'dart:convert';

import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/model/data_integrity_proof.dart';
import 'package:didwebvh/src/model/json.dart';
import 'package:didwebvh/src/model/json_support.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:didwebvh/src/model/version_id.dart';

/// A single entry in a did:webvh log (one JSONL line).
///
/// Faithful port of Java `LogEntry`.
class LogEntry implements JsonModel {
  /// Creates an empty log entry (all fields unset).
  LogEntry();

  /// Parses a log entry from a decoded JSON object [json].
  factory LogEntry.fromJson(Map<String, Object?> json) {
    final parameters = json['parameters'];
    final state = json['state'];
    final proof = json['proof'];
    return LogEntry()
      ..versionId = json['versionId'] as String?
      ..versionTime = json['versionTime'] as String?
      ..parameters =
          parameters is Map ? Parameters.fromJson(parameters.cast()) : null
      ..state = state is Map ? state.cast<String, Object?>() : null
      ..proof = proof is List
          ? [
              for (final item in proof)
                DataIntegrityProof.fromJson((item as Map).cast()),
            ]
          : null;
  }

  /// Parses a single JSONL line into a [LogEntry].
  factory LogEntry.fromJsonLine(String? line) {
    if (line == null || line.isEmpty) {
      throw ValidationException('log entry line must be non-empty');
    }
    return LogEntry.fromJson((jsonDecode(line) as Map).cast());
  }

  /// The version id (`"<number>-<hash>"`).
  String? versionId;

  /// The entry timestamp.
  String? versionTime;

  /// The parameter changes for this entry.
  Parameters? parameters;

  /// The DID document state object.
  Map<String, Object?>? state;

  /// The Data Integrity proofs.
  List<DataIntegrityProof>? proof;

  /// The numeric version of [versionId].
  int get versionNumber => VersionId.parse(versionId).versionNumber;

  /// The entry hash of [versionId].
  String get entryHash => VersionId.parse(versionId).entryHash;

  /// Serializes this entry to a compact single-line JSON string (for JSONL).
  String toJsonLine() => JsonSupport.compact(this);

  @override
  Map<String, Object?> toJson({bool omitNull = false}) {
    final json = <String, Object?>{};
    void put(String key, Object? value) {
      if (value != null || !omitNull) {
        json[key] = value;
      }
    }

    put('versionId', versionId);
    put('versionTime', versionTime);
    put('parameters', parameters?.toJson(omitNull: omitNull));
    put('state', state);
    put(
      'proof',
      proof?.map((p) => p.toJson(omitNull: omitNull)).toList(),
    );
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is LogEntry &&
      versionId == other.versionId &&
      versionTime == other.versionTime &&
      parameters == other.parameters &&
      jsonDeepEquals(state, other.state) &&
      jsonDeepEquals(proof, other.proof);

  @override
  int get hashCode => Object.hash(
        versionId,
        versionTime,
        parameters,
        jsonDeepHash(state),
        jsonDeepHash(proof),
      );
}

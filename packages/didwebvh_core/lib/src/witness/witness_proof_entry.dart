import 'package:didwebvh_core/src/model/data_integrity_proof.dart';
import 'package:didwebvh_core/src/model/json.dart';
import 'package:didwebvh_core/src/model/json_support.dart';

/// One witness proof attached to a specific log `versionId`.
///
/// Faithful port of Java `WitnessProofEntry`.
class WitnessProofEntry implements JsonModel {
  /// Creates an empty entry with all fields unset.
  WitnessProofEntry();

  /// Creates an entry for the given [versionId] and [proof] list.
  WitnessProofEntry.of(this.versionId, List<DataIntegrityProof>? proof)
      : proof = proof == null
            ? null
            : List<DataIntegrityProof>.unmodifiable(proof);

  /// Parses an entry from a decoded JSON object [json].
  factory WitnessProofEntry.fromJson(Map<String, Object?> json) {
    final proof = json['proof'];
    return WitnessProofEntry()
      ..versionId = json['versionId'] as String?
      ..proof = proof is List
          ? [
              for (final item in proof)
                DataIntegrityProof.fromJson((item as Map).cast()),
            ]
          : null;
  }

  /// The log version id this proof set covers.
  String? versionId;

  /// The Data Integrity proofs for [versionId].
  List<DataIntegrityProof>? proof;

  @override
  Map<String, Object?> toJson({bool omitNull = false}) {
    final json = <String, Object?>{};
    void put(String key, Object? value) {
      if (value != null || !omitNull) {
        json[key] = value;
      }
    }

    put('versionId', versionId);
    put('proof', proof?.map((p) => p.toJson(omitNull: omitNull)).toList());
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is WitnessProofEntry &&
      versionId == other.versionId &&
      jsonDeepEquals(proof, other.proof);

  @override
  int get hashCode => Object.hash(versionId, jsonDeepHash(proof));
}

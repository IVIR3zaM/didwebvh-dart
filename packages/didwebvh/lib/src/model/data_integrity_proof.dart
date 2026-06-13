import 'package:didwebvh/src/model/json_support.dart';

/// Data Integrity proof attached to a log entry or witness proof.
///
/// Faithful port of Java `DataIntegrityProof` (a mutable bean; setters become
/// direct field assignment in Dart).
class DataIntegrityProof implements JsonModel {
  /// Creates an empty proof with all fields unset.
  DataIntegrityProof();

  /// Returns a proof with the did:webvh:1.0 defaults pre-populated.
  factory DataIntegrityProof.defaults() => DataIntegrityProof()
    ..type = defaultType
    ..cryptosuite = defaultCryptosuite
    ..proofPurpose = defaultProofPurpose;

  /// Parses a proof from a decoded JSON object [json].
  factory DataIntegrityProof.fromJson(Map<String, Object?> json) =>
      DataIntegrityProof()
        ..type = json['type'] as String?
        ..cryptosuite = json['cryptosuite'] as String?
        ..verificationMethod = json['verificationMethod'] as String?
        ..proofPurpose = json['proofPurpose'] as String?
        ..created = json['created'] as String?
        ..proofValue = json['proofValue'] as String?;

  /// Default proof type.
  static const String defaultType = 'DataIntegrityProof';

  /// Default cryptosuite.
  static const String defaultCryptosuite = 'eddsa-jcs-2022';

  /// Default proof purpose.
  static const String defaultProofPurpose = 'assertionMethod';

  /// The proof type.
  String? type;

  /// The cryptosuite identifier.
  String? cryptosuite;

  /// The verification method (did:key URL).
  String? verificationMethod;

  /// The proof purpose.
  String? proofPurpose;

  /// The proof creation timestamp.
  String? created;

  /// The base58btc-multibase encoded signature.
  String? proofValue;

  @override
  Map<String, Object?> toJson({bool omitNull = false}) {
    final json = <String, Object?>{};
    void put(String key, Object? value) {
      if (value != null || !omitNull) {
        json[key] = value;
      }
    }

    put('type', type);
    put('cryptosuite', cryptosuite);
    put('verificationMethod', verificationMethod);
    put('proofPurpose', proofPurpose);
    put('created', created);
    put('proofValue', proofValue);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is DataIntegrityProof &&
      type == other.type &&
      cryptosuite == other.cryptosuite &&
      verificationMethod == other.verificationMethod &&
      proofPurpose == other.proofPurpose &&
      created == other.created &&
      proofValue == other.proofValue;

  @override
  int get hashCode => Object.hash(
        type,
        cryptosuite,
        verificationMethod,
        proofPurpose,
        created,
        proofValue,
      );
}

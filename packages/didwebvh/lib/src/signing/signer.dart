import 'dart:typed_data';

/// Abstraction for signing operations used when creating or updating a DID.
///
/// Faithful port of Java `Signer`, with the one intentional architectural
/// delta from the porting decisions: [sign] is **async** (`Future<Uint8List>`)
/// so the same interface can back local keys, remote KMS, or HSM signers
/// idiomatically. Implementations live outside the core package (e.g.
/// `didwebvh_signing_local`).
abstract interface class Signer {
  /// Key algorithm name, e.g. `"Ed25519"`.
  String get keyType;

  /// DID Key verification method URI, e.g. `"did:key:z6Mk...#z6Mk..."`.
  String get verificationMethod;

  /// Signs the given [data] and returns the raw signature bytes.
  ///
  /// Throws a `SigningException` if signing fails.
  Future<Uint8List> sign(Uint8List data);
}

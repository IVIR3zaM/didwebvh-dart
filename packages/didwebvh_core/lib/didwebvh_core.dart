/// did:webvh v1.0 core library — a faithful Dart port of didwebvh-java's
/// `didwebvh-core` module.
///
/// This barrel re-exports the public API; everything under `lib/src/` is
/// package-private (mirroring Java's package-private-by-default visibility).
/// Public exports are added as each iteration lands (see docs/PORTING-STATUS.md).
library;

export 'src/core/did_webvh.dart';
export 'src/core/exceptions.dart';
export 'src/create/create_did_config.dart';
export 'src/create/create_did_result.dart';
export 'src/model/data_integrity_proof.dart';
export 'src/model/did_document.dart';
export 'src/model/json_support.dart' show JsonModel;
export 'src/model/log_entry.dart';
export 'src/model/parameters.dart';
export 'src/model/resolution_metadata.dart';
export 'src/model/resolve_result.dart';
export 'src/model/version_id.dart';
export 'src/signing/proof_generator.dart';
export 'src/signing/proof_verifier.dart';
export 'src/signing/signer.dart';
export 'src/witness/witness_config.dart';
export 'src/witness/witness_entry.dart';

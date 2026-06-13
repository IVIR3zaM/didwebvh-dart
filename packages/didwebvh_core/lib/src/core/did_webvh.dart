import 'package:didwebvh_core/src/core/did_webvh_state.dart';
import 'package:didwebvh_core/src/create/create_did_config.dart';
import 'package:didwebvh_core/src/model/parameters.dart';
import 'package:didwebvh_core/src/signing/signer.dart';
import 'package:didwebvh_core/src/update/deactivate_did_config.dart';
import 'package:didwebvh_core/src/update/migrate_did_config.dart';
import 'package:didwebvh_core/src/update/update_did_config.dart';
import 'package:didwebvh_core/src/witness/witness_config.dart';

/// Main entry point for the did:webvh library.
///
/// Faithful port of Java `DidWebVh`. The `validate`/`resolve` facades are
/// exposed through `LogChainValidator` / `DidResolver` and added as their
/// iterations land (see docs/PORTING-STATUS.md).
abstract final class DidWebVh {
  /// Begin configuring a new DID creation for the given [domain] and [signer].
  ///
  /// Optional settings may be passed as named arguments here, or applied
  /// afterward via the fluent/cascade setters on [CreateDidConfig] — the styles
  /// are interchangeable.
  static CreateDidConfig create(
    String? domain,
    Signer? signer, {
    String? path,
    bool? portable,
    int? ttl,
    List<String>? alsoKnownAs,
    List<String>? controllers,
    WitnessConfig? witness,
    List<String>? watchers,
    List<String>? nextKeyHashes,
    Map<String, Object?>? additionalDocumentContent,
  }) =>
      CreateDidConfig(
        domain,
        signer,
        path: path,
        portable: portable,
        ttl: ttl,
        alsoKnownAs: alsoKnownAs,
        controllers: controllers,
        witness: witness,
        watchers: watchers,
        nextKeyHashes: nextKeyHashes,
        additionalDocumentContent: additionalDocumentContent,
      );

  /// Begin configuring a standard DID update (spec section 3.6.3).
  ///
  /// Optional settings may be passed as named arguments here, or applied
  /// afterward via the fluent/cascade setters on [UpdateDidConfig].
  static UpdateDidConfig update(
    DidWebVhState? state,
    Signer? signer, {
    Map<String, Object?>? newDocument,
    Parameters? changedParameters,
  }) =>
      UpdateDidConfig(
        state,
        signer,
        newDocument: newDocument,
        changedParameters: changedParameters,
      );

  /// Begin configuring a DID migration to a new domain (spec section 3.7.6).
  ///
  /// The DID must have been created with `portable: true`.
  static MigrateDidConfig migrate(
    DidWebVhState? state,
    Signer? signer,
    String? newDomain, {
    String? newPath,
  }) =>
      MigrateDidConfig(state, signer, newDomain, newPath: newPath);

  /// Begin configuring DID deactivation (spec section 3.6.4).
  static DeactivateDidConfig deactivate(
    DidWebVhState? state,
    Signer? signer, {
    Signer? nextRotationSigner,
  }) =>
      DeactivateDidConfig(
        state,
        signer,
        nextRotationSigner: nextRotationSigner,
      );
}

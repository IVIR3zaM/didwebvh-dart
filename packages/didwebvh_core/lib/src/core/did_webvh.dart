import 'package:didwebvh_core/src/create/create_did_config.dart';
import 'package:didwebvh_core/src/signing/signer.dart';
import 'package:didwebvh_core/src/witness/witness_config.dart';

/// Main entry point for the did:webvh library.
///
/// Faithful port of Java `DidWebVh`. Only [create] is available so far; the
/// `update`/`migrate`/`deactivate`/`validate`/`resolve` facades are added as
/// their iterations land (see docs/PORTING-STATUS.md).
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
}

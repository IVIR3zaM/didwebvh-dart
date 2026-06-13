import 'package:didwebvh/src/core/did_webvh_state.dart';
import 'package:didwebvh/src/signing/signer.dart';
import 'package:didwebvh/src/update/deactivate_did_operation.dart';
import 'package:didwebvh/src/update/update_did_result.dart';

/// Builder for configuring DID deactivation (spec section 3.6.4).
///
/// Required: [existingState] and [signer] (the current authorised signing key).
///
/// If pre-rotation is active (the state has non-empty `nextKeyHashes`), a
/// second signer is required via [nextRotationSigner]. The operation will:
/// 1. Emit an intermediate entry signed by that next signer that reveals the
///    next keys and clears `nextKeyHashes`.
/// 2. Emit the final deactivation entry signed by the next-rotation signer.
///
/// Faithful port of Java `DeactivateDidConfig`; [execute] is `async`.
class DeactivateDidConfig {
  /// Creates a config for deactivating [existingState] (signed by [signer]). An
  /// optional [nextRotationSigner] may also be supplied here (required when
  /// pre-rotation is active).
  DeactivateDidConfig(
    this.existingState,
    this.signer, {
    Signer? nextRotationSigner,
  }) {
    if (nextRotationSigner != null) this.nextRotationSigner(nextRotationSigner);
  }

  /// The current DID state.
  final DidWebVhState? existingState;

  /// The authorised signing key.
  final Signer? signer;

  Signer? _nextRotationSigner;

  /// The signer whose public key was committed to in the previous entry's
  /// `nextKeyHashes`. Required when the DID was created (or last updated) with
  /// pre-rotation enabled.
  DeactivateDidConfig nextRotationSigner(Signer nextRotationSigner) {
    _nextRotationSigner = nextRotationSigner;
    return this;
  }

  /// Execute the deactivation and return the result (one or two entries).
  Future<UpdateDidResult> execute() => DeactivateDidOperation.execute(this);

  /// The configured next-rotation signer, or `null`.
  Signer? get nextRotationSignerValue => _nextRotationSigner;
}

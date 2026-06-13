import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:didwebvh/src/signing/proof_verifier.dart';
import 'package:didwebvh/src/update/deactivate_did_config.dart';
import 'package:didwebvh/src/update/update_did_operation.dart';
import 'package:didwebvh/src/update/update_did_result.dart';

/// Implements DID deactivation from spec section 3.6.4.
///
/// If pre-rotation is active, two entries are produced:
/// 1. Intermediate entry: reveals the next keys, clears `nextKeyHashes`.
/// 2. Final entry: sets `deactivated=true` and `updateKeys=[]`.
///
/// Without pre-rotation a single entry is sufficient. Faithful port of Java
/// `DeactivateDidOperation`.
abstract final class DeactivateDidOperation {
  /// Executes the deactivation described by [config].
  static Future<UpdateDidResult> execute(DeactivateDidConfig config) async {
    _validate(config);

    final active = config.existingState!.accumulateParameters();
    final preRotationActive =
        active.nextKeyHashes != null && active.nextKeyHashes!.isNotEmpty;

    final newEntries = <LogEntry>[];

    var previous = config.existingState!.lastEntry!;

    if (preRotationActive) {
      // Intermediate entry: reveals the next key (committed via nextKeyHashes
      // in the previous entry) and clears nextKeyHashes to turn off
      // pre-rotation. Per spec §3.7.5, while pre-rotation is active each entry
      // is signed by its own updateKeys — so the intermediate is signed by the
      // next-rotation signer, not the prior signer.
      final nextMultikey = ProofVerifier.extractMultikey(
        config.nextRotationSignerValue!.verificationMethod,
      );
      final intermediate = Parameters()
        ..updateKeys = [nextMultikey]
        ..nextKeyHashes = const [];
      final intermediateEntry = await UpdateDidOperation.buildEntry(
        previous,
        config.nextRotationSignerValue!,
        null,
        intermediate,
      );
      newEntries.add(intermediateEntry);
      previous = intermediateEntry;
    }

    // Final deactivation entry: signed by the current (or revealed next) key.
    final finalSigner =
        preRotationActive ? config.nextRotationSignerValue! : config.signer!;
    final deactivation = Parameters()
      ..deactivated = true
      ..updateKeys = const [];
    final finalEntry = await UpdateDidOperation.buildEntry(
      previous,
      finalSigner,
      null,
      deactivation,
    );
    newEntries.add(finalEntry);

    return UpdateDidResult(newEntries);
  }

  static void _validate(DeactivateDidConfig config) {
    if (config.existingState == null) {
      throw ValidationException('existingState is required');
    }
    if (config.signer == null) {
      throw ValidationException('signer is required');
    }
    if (config.existingState!.lastEntry == null) {
      throw ValidationException(
        'existingState must contain at least one log entry',
      );
    }
    if (config.existingState!.isDeactivated) {
      throw ValidationException('DID is already deactivated');
    }
    final active = config.existingState!.accumulateParameters();
    final preRotationActive =
        active.nextKeyHashes != null && active.nextKeyHashes!.isNotEmpty;
    if (preRotationActive && config.nextRotationSignerValue == null) {
      throw ValidationException(
        'pre-rotation is active; provide nextRotationSigner whose public key'
        ' matches the committed nextKeyHashes',
      );
    }
  }
}

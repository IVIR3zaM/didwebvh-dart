import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/crypto/entry_hash_generator.dart';
import 'package:didwebvh/src/crypto/pre_rotation_hash_generator.dart';
import 'package:didwebvh/src/crypto/scid_generator.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:didwebvh/src/model/version_id.dart';
import 'package:didwebvh/src/signing/proof_verifier.dart';
import 'package:didwebvh/src/validate/validation_result.dart';

/// Validates the integrity of a did:webvh log chain (spec section 3.6.2).
///
/// Faithful port of Java `LogChainValidator`. [validate] is `async`: the ported
/// [ProofVerifier.verify] returns a `Future<bool>` (the documented async
/// delta), so the validation loop awaits proof verification rather than running
/// synchronously as in Java.
class LogChainValidator {
  /// Validates [entries] against an optional [expectedDid].
  Future<ValidationResult> validate(
    List<LogEntry>? entries,
    String? expectedDid,
  ) async {
    if (entries == null || entries.isEmpty) {
      return ValidationResult.failure(-1, -1, 'log must not be empty', null);
    }

    var activeParams = Parameters.defaults();
    String? previousVersionId;
    DateTime? previousVersionTime;
    var deactivated = false;
    var didFound = false;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      // 0. Fast-fail: no entries allowed after deactivation
      if (deactivated) {
        return ValidationResult.failure(
          i - 1,
          i,
          'entry after deactivation at entry ${i + 1}',
          activeParams,
        );
      }

      // 1 & 2. Parse versionId and check version number
      VersionId vid;
      try {
        vid = VersionId.parse(entry.versionId);
      } on ValidationException catch (e) {
        return ValidationResult.failure(
          i - 1,
          i,
          'invalid versionId at entry ${i + 1}: ${e.message}',
          activeParams,
        );
      }
      final expectedVersion = i + 1;
      if (vid.versionNumber != expectedVersion) {
        return ValidationResult.failure(
          i - 1,
          i,
          'expected versionNumber $expectedVersion but was '
              '${vid.versionNumber} at entry ${i + 1}',
          activeParams,
        );
      }

      // 3. Merge parameters
      final entryParams = entry.parameters ?? Parameters();
      final newActiveParams = activeParams.merge(entryParams);

      // 4. Validate parameters
      final paramError =
          _validateParameters(entryParams, newActiveParams, activeParams, i);
      if (paramError != null) {
        return ValidationResult.failure(i - 1, i, paramError, activeParams);
      }
      // entryParams = the delta from this entry (only changed fields)
      // newActiveParams = fully accumulated state after applying entryParams
      // activeParams = previously accumulated state before this entry

      // 5. First entry: verify SCID
      if (i == 0) {
        final scid = newActiveParams.scid!;
        if (!ScidGenerator.verify(scid, entry)) {
          return ValidationResult.failure(
            -1,
            0,
            'SCID verification failed',
            activeParams,
          );
        }
      }

      // 6. Verify entry hash
      final predecessorVersionId =
          (i == 0) ? newActiveParams.scid! : previousVersionId!;
      if (!EntryHashGenerator.verify(entry, predecessorVersionId)) {
        return ValidationResult.failure(
          i - 1,
          i,
          'entry hash verification failed at entry ${i + 1}',
          activeParams,
        );
      }

      // 7. Verify Data Integrity proof
      if (entry.proof == null || entry.proof!.isEmpty) {
        return ValidationResult.failure(
          i - 1,
          i,
          'missing proof at entry ${i + 1}',
          activeParams,
        );
      }
      final proof = entry.proof![0];
      // Spec §3.7.5 (lines 1071-1082): the "active updateKeys" that must
      // authorize an entry depends on whether Key Pre-Rotation is active
      // for this entry:
      //   • First entry: the entry's own updateKeys.
      //   • No pre-rotation: the previous entry's updateKeys
      //     (the new keys only take effect after validation).
      //   • Pre-rotation active (previous entry committed a non-empty
      //     nextKeyHashes): the current entry's own updateKeys. The
      //     previous entry's nextKeyHashes already pre-committed to those
      //     keys, so they are the authorized signers for this rotation.
      final prevNextKeyHashes = activeParams.nextKeyHashes;
      final preRotationActive = i > 0 &&
          prevNextKeyHashes != null &&
          prevNextKeyHashes.isNotEmpty;
      final signingKeys = (i == 0 || preRotationActive)
          ? newActiveParams.updateKeys
          : activeParams.updateKeys;
      if (signingKeys == null || signingKeys.isEmpty) {
        return ValidationResult.failure(
          i - 1,
          i,
          'no active updateKeys at entry ${i + 1}',
          activeParams,
        );
      }
      if (!ProofVerifier.isAuthorized(proof, signingKeys)) {
        return ValidationResult.failure(
          i - 1,
          i,
          'signing key not in active updateKeys at entry ${i + 1}',
          activeParams,
        );
      }
      if (!await ProofVerifier.verify(proof, entry)) {
        return ValidationResult.failure(
          i - 1,
          i,
          'proof signature invalid at entry ${i + 1}',
          activeParams,
        );
      }

      // 8. Verify versionTime
      DateTime vt;
      try {
        vt = _parseInstant(entry.versionTime);
      } on FormatException catch (e) {
        return ValidationResult.failure(
          i - 1,
          i,
          'invalid versionTime at entry ${i + 1}: ${e.message}',
          activeParams,
        );
      }
      if (previousVersionTime != null && !vt.isAfter(previousVersionTime)) {
        return ValidationResult.failure(
          i - 1,
          i,
          'versionTime must be after previous entry at entry ${i + 1}',
          activeParams,
        );
      }

      // 9. Check DID Document id
      final state = entry.state;
      if (state != null && state.containsKey('id')) {
        final docId = state['id']! as String;
        if (expectedDid == null || docId == expectedDid) {
          didFound = true;
        }
        // Portability: parameters.scid is the cryptographic anchor and
        // MUST NOT change across the log. The SCID component of state.id is
        // the third colon-delimited segment of the DID URL
        // (did:webvh:<scid>:<host>…). Portability moves host/path only; any
        // entry whose state.id SCID differs from parameters.scid is
        // rejected, regardless of portable / alsoKnownAs.
        final activeScid = newActiveParams.scid;
        if (activeScid != null) {
          final parts = docId.split(':');
          if (parts.length >= 3 && activeScid != parts[2]) {
            return ValidationResult.failure(
              i - 1,
              i,
              'state.id SCID component does not match parameters.scid at '
                  'entry ${i + 1}',
              activeParams,
            );
          }
        }
      }

      // 10. Pre-rotation: if previous entry set nextKeyHashes and this entry
      //     rotates keys, the new updateKeys must hash-match the previously
      //     committed nextKeyHashes (spec §3.7.7, lines 1119-1123). The
      //     updateKeys-required guard is enforced in _validateParameters
      //     before we ever get here.
      if (preRotationActive && entryParams.updateKeys != null) {
        for (final key in entryParams.updateKeys!) {
          final hash = PreRotationHashGenerator.generateHash(key);
          if (!prevNextKeyHashes.contains(hash)) {
            return ValidationResult.failure(
              i - 1,
              i,
              'updateKey hash not in previous nextKeyHashes at entry ${i + 1}',
              activeParams,
            );
          }
        }
      }

      // 11. Record deactivation for next iteration
      if (newActiveParams.deactivated ?? false) {
        deactivated = true;
      }

      activeParams = newActiveParams;
      previousVersionId = entry.versionId;
      previousVersionTime = vt;
    }

    // Last entry's versionTime must not be in the future. Allow small skew
    // since versionTime is second-precision and rapid updates may bump by 1s
    // to stay strictly increasing.
    if (previousVersionTime != null &&
        previousVersionTime.isAfter(
          DateTime.now().add(const Duration(seconds: 60)),
        )) {
      return ValidationResult.failure(
        entries.length - 2,
        entries.length - 1,
        'last entry versionTime is in the future',
        activeParams,
      );
    }

    if (expectedDid != null && !didFound) {
      return ValidationResult.failure(
        entries.length - 1,
        -1,
        'no entry has DID Document id matching expectedDid: $expectedDid',
        activeParams,
      );
    }

    return ValidationResult.success(entries.length - 1, activeParams);
  }

  /// Validate parameter rules for a single entry.
  ///
  /// [entryDelta] is the parameter fields present in this entry only (the
  /// delta); [newActive] is the fully accumulated parameters after applying
  /// [entryDelta]; [prevActive] is the accumulated parameters from the previous
  /// entry (before this delta); [index] is the 0-based entry index. Returns an
  /// error message, or `null` if valid.
  String? _validateParameters(
    Parameters entryDelta,
    Parameters newActive,
    Parameters prevActive,
    int index,
  ) {
    if (index == 0) {
      if (newActive.method == null) {
        return 'first entry must specify method';
      }
      if (newActive.scid == null) {
        return 'first entry must specify scid';
      }
      if (newActive.updateKeys == null || newActive.updateKeys!.isEmpty) {
        return 'first entry must specify updateKeys';
      }
    } else {
      if (entryDelta.scid != null) {
        return 'scid must only appear in first entry';
      }
      if (entryDelta.method != null &&
          prevActive.method != null &&
          _compareMethod(entryDelta.method!, prevActive.method!) < 0) {
        return 'method version must not decrease: ${entryDelta.method}'
            ' < ${prevActive.method}';
      }
      // portable cannot be set from false to true after first entry
      if ((entryDelta.portable ?? false) && !(prevActive.portable ?? false)) {
        return 'portable can only be set to true in first entry';
      }
      // Pre-rotation: if the previous entry committed nextKeyHashes, this
      // entry MUST present a non-empty updateKeys. Otherwise the pre-rotation
      // guarantee is defeated by inheriting the old keys.
      // (Spec §3.7.7; see negative-pre-rotation-omit-updatekeys.)
      final prevNextHashes = prevActive.nextKeyHashes;
      if (prevNextHashes != null &&
          prevNextHashes.isNotEmpty &&
          (entryDelta.updateKeys == null || entryDelta.updateKeys!.isEmpty)) {
        return 'updateKeys MUST be present and non-empty when previous entry '
            'committed nextKeyHashes (pre-rotation active)';
      }
    }

    // Witness config bounds check – only applies when witnesses are actually
    // configured
    final witness = newActive.witness;
    if (witness != null && witness.isActive) {
      if (witness.threshold < 1) {
        return 'witness threshold must be >= 1';
      }
      if (witness.threshold > witness.witnesses.length) {
        return 'witness threshold ${witness.threshold}'
            ' exceeds witness count ${witness.witnesses.length}';
      }
    }

    return null;
  }

  int _compareMethod(String a, String b) {
    final va = _extractMethodVersion(a);
    final vb = _extractMethodVersion(b);
    if (va == null || vb == null) {
      return 0;
    }
    final pa = va.split('.');
    final pb = vb.split('.');
    final len = pa.length < pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final ia = int.tryParse(pa[i]);
      final ib = int.tryParse(pb[i]);
      if (ia == null || ib == null) {
        return 0;
      }
      final cmp = ia.compareTo(ib);
      if (cmp != 0) {
        return cmp;
      }
    }
    return pa.length.compareTo(pb.length);
  }

  String? _extractMethodVersion(String method) {
    final lastColon = method.lastIndexOf(':');
    return lastColon >= 0 ? method.substring(lastColon + 1) : null;
  }

  /// Parses an ISO-8601 instant (e.g. `2026-01-01T00:00:00Z`), throwing a
  /// [FormatException] on malformed input — the analog of Java's
  /// `Instant.parse` / `DateTimeParseException`.
  static DateTime _parseInstant(String? value) {
    if (value == null) {
      throw const FormatException('versionTime is null');
    }
    return DateTime.parse(value);
  }
}

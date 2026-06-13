import 'dart:convert';

import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/crypto/entry_hash_generator.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:didwebvh/src/signing/proof_generator.dart';
import 'package:didwebvh/src/signing/signer.dart';
import 'package:didwebvh/src/update/update_did_config.dart';
import 'package:didwebvh/src/update/update_did_result.dart';

/// Implements the standard DID update flow from spec section 3.6.3.
///
/// Faithful port of Java `UpdateDidOperation`; [execute] and [buildEntry] are
/// `async` because the ported [Signer.sign] (and therefore
/// [ProofGenerator.generate]) is async.
abstract final class UpdateDidOperation {
  /// Executes the update described by [config].
  static Future<UpdateDidResult> execute(UpdateDidConfig config) async {
    _validate(config);

    final entry = await buildEntry(
      config.existingState!.lastEntry!,
      config.signer!,
      config.newDocumentValue,
      config.changedParametersValue,
    );

    return UpdateDidResult([entry]);
  }

  /// Build and sign a single new log entry succeeding [previous].
  ///
  /// [signer] must be in the active updateKeys. [newDocument] is the new DID
  /// Document, or `null` to carry forward the existing one. [changedParams] is
  /// the parameter delta, or `null` for an empty delta `{}`.
  static Future<LogEntry> buildEntry(
    LogEntry previous,
    Signer signer,
    Map<String, Object?>? newDocument,
    Parameters? changedParams,
  ) async {
    final predecessorVersionId = previous.versionId;
    final nextVersion = previous.versionNumber + 1;

    final state = newDocument ?? _deepCopy(previous.state);

    final params = changedParams ?? Parameters();

    var now = _truncateToSeconds(DateTime.now().toUtc());
    final prev = DateTime.parse(previous.versionTime!).toUtc();
    if (!now.isAfter(prev)) {
      now = prev.add(const Duration(seconds: 1));
    }
    final versionTime = _formatInstant(now);

    final entry = LogEntry()
      ..versionId = predecessorVersionId
      ..versionTime = versionTime
      ..parameters = params
      ..state = state;

    // Hash uses predecessorVersionId, replacing whatever versionId is currently
    // set.
    final entryHash = EntryHashGenerator.generate(
      entry.toJsonLine(),
      predecessorVersionId!,
    );
    entry.versionId = '$nextVersion-$entryHash';

    final proof = await ProofGenerator.generate(signer, entry);
    entry.proof = [proof];
    return entry;
  }

  static void _validate(UpdateDidConfig config) {
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
      throw ValidationException('cannot update a deactivated DID');
    }
  }

  static Map<String, Object?>? _deepCopy(Map<String, Object?>? value) =>
      value == null
          ? null
          : (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();

  static DateTime _truncateToSeconds(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);

  /// Formats [instant] as `yyyy-MM-dd'T'HH:mm:ss'Z'` in UTC (seconds precision,
  /// `Z`), matching Java's `Instant.truncatedTo(SECONDS).toString()`.
  static String _formatInstant(DateTime instant) {
    final u = instant.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }
}

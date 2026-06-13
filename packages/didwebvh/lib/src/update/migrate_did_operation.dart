import 'dart:convert';

import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:didwebvh/src/update/migrate_did_config.dart';
import 'package:didwebvh/src/update/update_did_operation.dart';
import 'package:didwebvh/src/update/update_did_result.dart';
import 'package:didwebvh/src/url/did_webvh_url.dart';

/// Implements DID migration from spec section 3.7.6.
///
/// The SCID is preserved; only the domain (and optional path) change. All DID
/// references in the document are rewritten and the previous DID is added to
/// `alsoKnownAs`. Faithful port of Java `MigrateDidOperation`.
abstract final class MigrateDidOperation {
  /// Executes the migration described by [config].
  static Future<UpdateDidResult> execute(MigrateDidConfig config) async {
    _validate(config);

    final oldDid = config.existingState!.did;
    final parsed = DidWebVhUrl.parse(oldDid);

    // Reconstruct new DID preserving SCID.
    final newDid =
        _buildNewDid(parsed.scid, config.newDomain!, config.newPathValue);

    final previous = config.existingState!.lastEntry!;
    final newDoc = _rewriteDocument(_deepCopy(previous.state), oldDid, newDid);

    // Carry forward only the document change; no parameter delta needed.
    final entry = await UpdateDidOperation.buildEntry(
      previous,
      config.signer!,
      newDoc,
      Parameters(),
    );

    return UpdateDidResult([entry]);
  }

  static void _validate(MigrateDidConfig config) {
    if (config.existingState == null) {
      throw ValidationException('existingState is required');
    }
    if (config.signer == null) {
      throw ValidationException('signer is required');
    }
    final newDomain = config.newDomain;
    if (newDomain == null || newDomain.isEmpty) {
      throw ValidationException('newDomain is required');
    }
    if (config.existingState!.lastEntry == null) {
      throw ValidationException(
        'existingState must contain at least one log entry',
      );
    }
    if (config.existingState!.isDeactivated) {
      throw ValidationException('cannot migrate a deactivated DID');
    }
    final active = config.existingState!.accumulateParameters();
    if (active.portable != true) {
      throw ValidationException(
        'DID is not portable; set portable=true at creation time to enable'
        ' migration',
      );
    }
  }

  /// Build `did:webvh:<scid>:<newDomain>[:<newPath>]`.
  static String _buildNewDid(String scid, String newDomain, String? newPath) {
    final sb = StringBuffer('did:webvh:')
      ..write(scid)
      ..write(':')
      ..write(newDomain);
    if (newPath != null && newPath.isNotEmpty) {
      sb
        ..write(':')
        ..write(newPath);
    }
    return sb.toString();
  }

  /// Replace every occurrence of [oldDid] in the document JSON with [newDid],
  /// and ensure the previous DID appears in `alsoKnownAs`.
  static Map<String, Object?> _rewriteDocument(
    Map<String, Object?> doc,
    String oldDid,
    String newDid,
  ) {
    // String-replace all references (id, controller, key refs, etc.).
    final json = jsonEncode(doc).replaceAll(oldDid, newDid);
    final rewritten = (jsonDecode(json) as Map).cast<String, Object?>();

    // Add previous DID to alsoKnownAs (deduplicated).
    _addAlsoKnownAs(rewritten, oldDid);

    return rewritten;
  }

  static void _addAlsoKnownAs(Map<String, Object?> doc, String previousDid) {
    final existing = doc['alsoKnownAs'];
    final List<Object?> aka;
    if (existing is List) {
      aka = existing;
      // Check for duplicate.
      for (final el in aka) {
        if (el == previousDid) {
          return;
        }
      }
    } else {
      aka = <Object?>[];
    }
    aka.add(previousDid);
    doc['alsoKnownAs'] = aka;
  }

  static Map<String, Object?> _deepCopy(Map<String, Object?>? value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
}

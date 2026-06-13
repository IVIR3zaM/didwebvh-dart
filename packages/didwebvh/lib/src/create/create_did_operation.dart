import 'dart:convert';

import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/create/create_did_config.dart';
import 'package:didwebvh/src/create/create_did_result.dart';
import 'package:didwebvh/src/crypto/entry_hash_generator.dart';
import 'package:didwebvh/src/crypto/scid_generator.dart';
import 'package:didwebvh/src/model/log_entry.dart';
import 'package:didwebvh/src/model/parameters.dart';
import 'package:didwebvh/src/signing/proof_generator.dart';
import 'package:didwebvh/src/signing/signer.dart';

/// Implements the DID creation flow from spec section 3.6.1.
///
/// Faithful port of Java `CreateDidOperation`; [execute] is `async` because the
/// ported [Signer.sign] (and therefore [ProofGenerator.generate]) is async.
abstract final class CreateDidOperation {
  static const String _methodVersion = 'did:webvh:1.0';
  static final String _scidPlaceholder = ScidGenerator.placeholder();

  /// Executes the creation described by [config].
  static Future<CreateDidResult> execute(CreateDidConfig config) async {
    _validate(config);

    final signerMultikey = extractMultikey(config.signer!);

    // Step 1: Build the DID string with {SCID} placeholder.
    final didTemplate = _buildDidTemplate(config.domain!, config.pathValue);

    // Step 2: Build initial DID Document with {SCID} placeholders.
    final docJson = _buildDidDocument(didTemplate, signerMultikey, config);

    // Step 3: Build initial Parameters.
    final params = _buildParameters(signerMultikey, config);

    // Step 4: Build preliminary log entry (no proof).
    final versionTime = _formatInstant(DateTime.now());
    final preliminary = LogEntry()
      ..versionId = _scidPlaceholder
      ..versionTime = versionTime
      ..parameters = params
      ..state = docJson;

    // Step 5: Generate SCID.
    final scid = ScidGenerator.generate(preliminary);

    // Step 6: Replace all {SCID} placeholders with actual SCID.
    final json = preliminary.toJsonLine();
    final resolved = json.replaceAll(_scidPlaceholder, scid);
    final entry = LogEntry.fromJsonLine(resolved);

    // Step 7: Generate entry hash with SCID as predecessor.
    final entryJson = entry.toJsonLine();
    final entryHash = EntryHashGenerator.generate(entryJson, scid);

    // Step 8: Set versionId to "1-<entryHash>".
    entry.versionId = '1-$entryHash';

    // Step 9-10: Generate and attach proof.
    final proof = await ProofGenerator.generate(config.signer!, entry);
    entry.proof = [proof];

    // Build result.
    final did = didTemplate.replaceAll(_scidPlaceholder, scid);
    final logLine = entry.toJsonLine();
    return CreateDidResult(did, entry, logLine);
  }

  static void _validate(CreateDidConfig config) {
    final domain = config.domain;
    if (domain == null || domain.isEmpty) {
      throw ValidationException('domain is required');
    }
    if (config.signer == null) {
      throw ValidationException('signer is required');
    }
    final ttl = config.ttlValue;
    if (ttl != null && ttl < 0) {
      throw ValidationException('ttl must be non-negative, was $ttl');
    }
    final nextKeyHashes = config.nextKeyHashesValue;
    if (nextKeyHashes != null) {
      for (final hash in nextKeyHashes) {
        if (hash.isEmpty) {
          throw ValidationException('nextKeyHashes entries must be non-empty');
        }
      }
    }
  }

  /// Build `did:webvh:{SCID}:<domain>[:<path>]`.
  static String _buildDidTemplate(String domain, String? path) {
    final sb = StringBuffer('did:webvh:')
      ..write(_scidPlaceholder)
      ..write(':')
      ..write(domain);
    if (path != null && path.isNotEmpty) {
      sb
        ..write(':')
        ..write(path);
    }
    return sb.toString();
  }

  static Map<String, Object?> _buildDidDocument(
    String didTemplate,
    String signerMultikey,
    CreateDidConfig config,
  ) {
    final doc = <String, Object?>{
      '@context': 'https://www.w3.org/ns/did/v1',
      'id': didTemplate,
    };

    // Controller is optional per DID Core §5.1.2. Historical default is the DID
    // itself (preserved when the caller doesn't set controllers explicitly).
    _addControllerProperty(doc, didTemplate, config.controllersValue);

    // Verification method from signer.
    final keyRef = '$didTemplate#$signerMultikey';
    doc['verificationMethod'] = [
      <String, Object?>{
        'id': keyRef,
        'type': 'Multikey',
        'controller': didTemplate,
        'publicKeyMultibase': signerMultikey,
      },
    ];

    // Authentication, assertionMethod reference the key.
    doc['authentication'] = [keyRef];
    doc['assertionMethod'] = [keyRef];

    // Also known as.
    final alsoKnownAs = config.alsoKnownAsValue;
    if (alsoKnownAs != null && alsoKnownAs.isNotEmpty) {
      doc['alsoKnownAs'] = [...alsoKnownAs];
    }

    // Merge additional document content (services, extra verification methods,
    // etc.). Don't override id or controller.
    final additional = config.additionalDocumentContentValue;
    if (additional != null) {
      additional.forEach((key, value) {
        if (key != 'id' && key != 'controller') {
          doc[key] = _deepCopy(value);
        }
      });
    }

    return doc;
  }

  static void _addControllerProperty(
    Map<String, Object?> doc,
    String didTemplate,
    List<String>? controllers,
  ) {
    if (controllers == null) {
      // Backward-compatible default: single controller equal to the DID.
      doc['controller'] = didTemplate;
      return;
    }
    if (controllers.isEmpty) {
      // Explicit opt-out: omit the controller property entirely.
      return;
    }
    if (controllers.length == 1) {
      doc['controller'] = controllers[0];
      return;
    }
    doc['controller'] = [...controllers];
  }

  static Parameters _buildParameters(
    String signerMultikey,
    CreateDidConfig config,
  ) {
    final params = Parameters()
      ..method = _methodVersion
      ..scid = _scidPlaceholder
      ..updateKeys = [signerMultikey];

    if (config.portableValue != null) {
      params.portable = config.portableValue;
    }
    if (config.ttlValue != null) {
      params.ttl = config.ttlValue;
    }
    if (config.witnessValue != null) {
      params.witness = config.witnessValue;
    }
    if (config.watchersValue != null) {
      params.watchers = config.watchersValue;
    }
    if (config.nextKeyHashesValue != null) {
      params.nextKeyHashes = config.nextKeyHashesValue;
    }
    return params;
  }

  /// Extract the multikey from a [signer]'s verification method URI.
  /// `did:key:z6Mk...#z6Mk...` → `z6Mk...`
  static String extractMultikey(Signer signer) {
    final vm = signer.verificationMethod;
    final hash = vm.indexOf('#');
    if (hash >= 0) {
      return vm.substring(hash + 1);
    }
    const prefix = 'did:key:';
    if (vm.startsWith(prefix)) {
      return vm.substring(prefix.length);
    }
    throw ValidationException(
      'Cannot extract multikey from signer verificationMethod: $vm',
    );
  }

  static Object? _deepCopy(Object? value) =>
      value == null ? null : jsonDecode(jsonEncode(value));

  /// Formats [instant] as `yyyy-MM-dd'T'HH:mm:ss'Z'` in UTC (seconds precision,
  /// `Z`), matching Java's `Instant.now().truncatedTo(SECONDS).toString()`.
  static String _formatInstant(DateTime instant) {
    final u = instant.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }
}

import 'dart:convert';

import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:didwebvh_core/src/didweb/implicit_services.dart';
import 'package:didwebvh_core/src/model/did_document.dart';
import 'package:didwebvh_core/src/model/log_entry.dart';
import 'package:didwebvh_core/src/model/parameters.dart';
import 'package:didwebvh_core/src/model/resolution_metadata.dart';
import 'package:didwebvh_core/src/model/resolve_result.dart';
import 'package:didwebvh_core/src/resolve/resolve_options.dart';
import 'package:didwebvh_core/src/url/did_webvh_url.dart';
import 'package:didwebvh_core/src/validate/log_chain_validator.dart';
import 'package:didwebvh_core/src/validate/witness_validator.dart';
import 'package:didwebvh_core/src/witness/witness_proof_collection.dart';
import 'package:didwebvh_core/src/witness/witness_proof_entry.dart';

/// Parses, validates, and selects entries from a did:webvh log.
///
/// Faithful port of the Java `LogProcessor` (package-private). [process] is
/// `async`: the ported log-chain and witness validators return `Future`s (the
/// documented async ripple from the async `Signer`).
class LogProcessor {
  /// Creates a processor with default validators.
  LogProcessor()
      : _logChainValidator = LogChainValidator(),
        _witnessValidator = WitnessValidator();

  /// Creates a processor with the given validators (test seam).
  LogProcessor.withValidators(
    LogChainValidator logChainValidator,
    WitnessValidator witnessValidator,
  )   : _logChainValidator = logChainValidator,
        _witnessValidator = witnessValidator;

  final LogChainValidator _logChainValidator;
  final WitnessValidator _witnessValidator;

  /// Parses [didLogContent], validates the chain (and witnesses when
  /// configured), and resolves the entry selected by [options].
  ///
  /// [witnessContent] is the `did-witness.json` content when already fetched;
  /// otherwise [witnessSupplier] is invoked lazily if witnesses are required.
  /// [did] is the expected DID to validate the log against, or `null` to skip.
  Future<ResolveResult> process(
    String? didLogContent,
    String? witnessContent,
    String? did,
    ResolveOptions? options, [
    Future<String?> Function()? witnessSupplier,
  ]) async {
    final effectiveOptions = options ?? ResolveOptions.defaults();
    _validateVersionSelector(effectiveOptions);
    final entries = _parseEntries(didLogContent);
    final expectedDid = _baseDid(did);

    final validation = await _logChainValidator.validate(entries, expectedDid);
    if (!validation.valid) {
      throw _invalidDid('Invalid DID log: ${validation.failureReason}');
    }

    await _validateWitnessesIfConfigured(
      entries,
      witnessContent,
      witnessSupplier,
    );

    final selectedIndex = _selectEntry(entries, effectiveOptions);
    final selected = entries[selectedIndex];
    final selectedParameters = _parametersAt(entries, selectedIndex);
    final metadata = _metadata(entries, selected, selectedParameters);

    final result = ResolveResult()..metadata = metadata;
    if (selectedParameters.deactivated != true) {
      // Spec §3.8 and §3.9: the resolved DID Document MUST include the
      // implicit #files and #whois services unless the controller has
      // already defined explicit services with the same id.
      final state = (jsonDecode(jsonEncode(selected.state)) as Map)
          .cast<String, Object?>();
      ImplicitServices.addTo(state, state['id'] as String?);
      result.didDocument = DidDocument(state);
    }
    return result;
  }

  List<LogEntry> _parseEntries(String? didLogContent) {
    if (didLogContent == null || didLogContent.trim().isEmpty) {
      throw _invalidDid('DID log must not be empty');
    }
    final lines = didLogContent.split(RegExp(r'\r\n|\r|\n'));
    final entries = <LogEntry>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      try {
        entries.add(LogEntry.fromJsonLine(line));
      } on FormatException catch (e) {
        throw ResolutionException.withError(
          'Unable to parse DID log entry: ${e.message}',
          'invalidDid',
          e,
        );
      } on ValidationException catch (e) {
        throw ResolutionException.withError(
          'Unable to parse DID log entry: ${e.message}',
          'invalidDid',
          e,
        );
      }
    }
    if (entries.isEmpty) {
      throw _invalidDid('DID log must contain at least one entry');
    }
    return entries;
  }

  String? _baseDid(String? did) {
    if (did == null) {
      return null;
    }
    return DidWebVhUrl.parse(did).toBaseDid();
  }

  void _validateVersionSelector(ResolveOptions options) {
    if (options.hasMultipleVersionSelectors) {
      throw _invalidDid(
        'Only one of versionId, versionTime, and versionNumber may be used',
      );
    }
  }

  Future<void> _validateWitnessesIfConfigured(
    List<LogEntry> entries,
    String? witnessContent,
    Future<String?> Function()? witnessSupplier,
  ) async {
    if (!_requiresWitnesses(entries)) {
      return;
    }
    var content = witnessContent;
    if (content == null || content.trim().isEmpty) {
      content = witnessSupplier == null ? null : await witnessSupplier();
    }
    if (content == null || content.trim().isEmpty) {
      throw _invalidDid('Witness proofs are required but were not provided');
    }

    final WitnessProofCollection proofs;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        throw const FormatException('witness proofs must be a JSON array');
      }
      proofs = WitnessProofCollection([
        for (final item in decoded)
          WitnessProofEntry.fromJson((item as Map).cast<String, Object?>()),
      ]);
    } on FormatException catch (e) {
      throw ResolutionException.withError(
        'Unable to parse witness proofs: ${e.message}',
        'invalidDid',
        e,
      );
    }

    final result = await _witnessValidator.validate(entries, proofs, 0);
    if (!result.valid) {
      throw _invalidDid('Invalid witness proofs: ${result.failureReason}');
    }
  }

  bool _requiresWitnesses(List<LogEntry> entries) {
    var active = Parameters.defaults();
    for (final entry in entries) {
      active = active.merge(entry.parameters);
      final witness = active.witness;
      if (witness != null && witness.isActive) {
        return true;
      }
    }
    return false;
  }

  int _selectEntry(List<LogEntry> entries, ResolveOptions options) {
    if (options.versionIdValue != null) {
      for (var i = 0; i < entries.length; i++) {
        if (options.versionIdValue == entries[i].versionId) {
          return i;
        }
      }
      throw _invalidDid(
        'No DID log entry found for versionId ${options.versionIdValue}',
      );
    }
    if (options.versionNumberValue != null) {
      for (var i = 0; i < entries.length; i++) {
        if (options.versionNumberValue == entries[i].versionNumber) {
          return i;
        }
      }
      throw _invalidDid(
        'No DID log entry found for versionNumber '
        '${options.versionNumberValue}',
      );
    }
    if (options.versionTimeValue != null) {
      return _selectByTime(entries, options.versionTimeValue!);
    }
    return entries.length - 1;
  }

  int _selectByTime(List<LogEntry> entries, String versionTime) {
    final DateTime requested;
    try {
      requested = DateTime.parse(versionTime);
    } on FormatException catch (e) {
      throw ResolutionException.withError(
        'Invalid versionTime: $versionTime',
        'invalidDid',
        e,
      );
    }

    var selected = -1;
    for (var i = 0; i < entries.length; i++) {
      final entryTime = DateTime.parse(entries[i].versionTime!);
      if (!entryTime.isAfter(requested)) {
        selected = i;
      }
    }
    if (selected < 0) {
      throw _invalidDid(
        'No DID log entry found at or before versionTime $versionTime',
      );
    }
    return selected;
  }

  Parameters _parametersAt(List<LogEntry> entries, int selectedIndex) {
    var active = Parameters.defaults();
    for (var i = 0; i <= selectedIndex; i++) {
      active = active.merge(entries[i].parameters);
    }
    return active;
  }

  ResolutionMetadata _metadata(
    List<LogEntry> entries,
    LogEntry selected,
    Parameters parameters,
  ) {
    return ResolutionMetadata()
      ..versionId = selected.versionId
      ..versionTime = selected.versionTime
      ..created = entries[0].versionTime
      ..updated = selected.versionTime
      ..scid = parameters.scid
      ..portable = parameters.portable
      ..deactivated = parameters.deactivated
      ..ttl = parameters.ttl?.toString()
      ..witness = parameters.witness
      ..watchers = parameters.watchers;
  }

  ResolutionException _invalidDid(String message) =>
      ResolutionException.withError(message, 'invalidDid');
}

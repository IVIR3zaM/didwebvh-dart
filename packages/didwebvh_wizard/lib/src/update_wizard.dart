import 'dart:convert';
import 'dart:io';

import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';
import 'package:didwebvh_wizard/src/wizard_prompts.dart';
import 'package:didwebvh_wizard/src/wizard_witness_keys.dart';
import 'package:didwebvh_wizard/src/wizard_witness_proofs.dart';
import 'package:path/path.dart' as p;

/// Interactive "update / migrate / deactivate" wizard.
///
/// Faithful port of Java `UpdateWizard`.
final class UpdateWizard {
  /// Creates the wizard over the given [io].
  UpdateWizard(this.io)
      : ask = WizardPrompts(io),
        witnessProofs = WizardWitnessProofs(io);

  /// The I/O channel used for prompting.
  final WizardIo io;

  /// Prompt helpers.
  final WizardPrompts ask;

  /// Witness-proof collector.
  final WizardWitnessProofs witnessProofs;

  /// Run the update flow against files in [workDir].
  Future<void> run(String workDir) async {
    io.println('=== Update an existing did:webvh DID ===');

    final logPath = p.join(workDir, WizardFiles.didLog);
    final secretsPath = p.join(workDir, WizardFiles.didSecrets);
    if (!File(logPath).existsSync()) {
      throw WizardException(
        'No ${WizardFiles.didLog} found in ${p.absolute(workDir)}',
      );
    }
    if (!File(secretsPath).existsSync()) {
      throw WizardException(
        'No ${WizardFiles.didSecrets} found in ${p.absolute(workDir)}',
      );
    }

    final signer = LocalKeySigner.fromJson(WizardFiles.read(secretsPath));
    final rawLog = WizardFiles.read(logPath);
    final entries = _parseLog(rawLog);
    if (entries.isEmpty) {
      throw WizardException('DID log is empty');
    }
    final did = entries[0].state!['id']! as String;
    final state = DidWebVhState.fromDidLog(did, rawLog);
    final existing = await state.validate();
    if (!existing.valid) {
      throw WizardException(
        'Existing log failed validation: ${existing.failureReason}',
      );
    }
    if (state.isDeactivated) {
      throw WizardException(
        'DID is already deactivated; no further updates allowed.',
      );
    }

    io
      ..println('Loaded ${entries.length} existing log entries for $did')
      ..println('')
      ..println('Operation:')
      ..println('  1) Modify the DID document or parameters')
      ..println('  2) Migrate to a new domain')
      ..println('  3) Deactivate the DID');
    final choice = ask.askChoice('Choose 1-3: ', 3);

    final priorParams = state.accumulateParameters();
    final result = await switch (choice) {
      1 => _runModify(state, signer, did, workDir),
      2 => _runMigrate(state, signer),
      3 => _runDeactivate(state, signer, workDir),
      _ => throw WizardException('Unexpected choice: $choice'),
    };

    // Spec 3.7.8: did-witness.json MUST be published BEFORE did.jsonl.
    await witnessProofs.collectForNewEntries(
      priorParams,
      result.newEntries,
      workDir,
    );

    for (final entry in result.newEntries) {
      WizardFiles.appendLine(logPath, entry.toJsonLine());
    }
    final n = result.newEntries.length;
    io
      ..println('')
      ..println(
        'Wrote $n new entr${n == 1 ? 'y' : 'ies'} to ${WizardFiles.didLog}',
      )
      ..println('New DID state id: ${result.logEntry.state!['id']}');
  }

  Future<UpdateDidResult> _runModify(
    DidWebVhState state,
    LocalKeySigner signer,
    String did,
    String workDir,
  ) async {
    Map<String, Object?>? newDocument;
    if (ask.askYesNo('Replace the DID Document?', defaultValue: false)) {
      final json = ask.askRequired('New DID Document JSON (single line): ');
      newDocument =
          _parseAndValidateDocument(json, did, state.accumulateParameters());
    }

    Parameters? changed;
    if (ask.askYesNo('Change any parameters?', defaultValue: false)) {
      changed = await _promptParameterChanges(state, workDir);
    }

    return (DidWebVh.update(state, signer)
          ..newDocument(newDocument)
          ..changedParameters(changed))
        .execute();
  }

  Map<String, Object?> _parseAndValidateDocument(
    String json,
    String expectedDid,
    Parameters activeParams,
  ) {
    Map<String, Object?> obj;
    try {
      obj = (jsonDecode(json) as Map).cast<String, Object?>();
    } on Object catch (e) {
      throw WizardException('Invalid DID Document JSON: $e', e);
    }
    final doc = DidDocument(obj);
    final id = doc.id;
    if (id == null || id.isEmpty) {
      throw WizardException("DID Document is missing required 'id' field");
    }
    if (id != expectedDid) {
      _classifyIdChange(id, expectedDid, activeParams);
    }
    return obj;
  }

  /// Reject mismatched document `id`s with a message tailored to the root
  /// cause. A SCID or method change is always forbidden; a domain/path change is
  /// handled by the dedicated Migrate operation (and requires `portable=true`).
  Never _classifyIdChange(
    String newId,
    String currentId,
    Parameters activeParams,
  ) {
    DidWebVhUrl currentUrl;
    DidWebVhUrl newUrl;
    try {
      currentUrl = DidWebVhUrl.parse(currentId);
    } on Object catch (e) {
      throw WizardException(
        'Current DID is not a valid did:webvh URL: $currentId',
        e,
      );
    }
    try {
      newUrl = DidWebVhUrl.parse(newId);
    } on Object catch (e) {
      throw WizardException(
        "New DID Document 'id' is not a valid did:webvh URL: $newId "
        '– method/type change is not allowed',
        e,
      );
    }
    if (currentUrl.scid != newUrl.scid) {
      throw WizardException(
        "DID Document 'id' changes the SCID "
        '(${currentUrl.scid} → ${newUrl.scid}). SCID is immutable.',
      );
    }
    // Same SCID and method → only the domain or path segments differ.
    final portableHint = activeParams.portable ?? false
        ? 'use the Migrate operation instead of Modify'
        : 'this DID is not portable (portable=false), so migration is not '
            'allowed';
    throw WizardException(
      "DID Document 'id' changes the domain/path "
      '($currentId → $newId); $portableHint.',
    );
  }

  /// Prompt for every mutable parameter in [Parameters]. Returns an empty
  /// `Parameters()` (meaning an empty `{}` delta) if the user declines every
  /// field — the caller still gets a no-op parameter change marker.
  Future<Parameters> _promptParameterChanges(
    DidWebVhState state,
    String workDir,
  ) async {
    final current = state.accumulateParameters();
    final changed = Parameters();

    if (ask.askYesNo(
      'Change updateKeys (key rotation)?',
      defaultValue: false,
    )) {
      final line =
          ask.askRequired('New updateKeys (comma-separated multikeys): ');
      changed.updateKeys = _splitList(line);
    }

    if (ask.askYesNo(
      'Change nextKeyHashes (pre-rotation)?',
      defaultValue: false,
    )) {
      io
        ..println('  1) Clear (disable pre-rotation)')
        ..println('  2) Enter hash(es) manually');
      final mode = ask.askChoice('Choose 1-2: ', 2);
      if (mode == 1) {
        changed.nextKeyHashes = const [];
      } else {
        final line = ask.askRequired('New nextKeyHashes (comma-separated): ');
        changed.nextKeyHashes = _splitList(line);
      }
      _maybeWarnUnreachableHash(changed.nextKeyHashes);
    }

    if (ask.askYesNo('Change witness configuration?', defaultValue: false)) {
      changed.witness = await _readWitnessConfig(workDir, current.witness);
    }

    if (ask.askYesNo('Change watchers?', defaultValue: false)) {
      changed.watchers = _readWatchers(current.watchers);
    }

    if ((current.portable ?? false) &&
        ask.askYesNo(
          'Disable portability (portable=false, PERMANENT)?',
          defaultValue: false,
        )) {
      changed.portable = false;
    }

    if (ask.askYesNo('Change TTL?', defaultValue: false)) {
      changed.ttl = ask.askInt('New TTL (seconds, 0 = no cache): ', null);
    }

    return changed;
  }

  /// Witness turned off produces an empty WitnessConfig; otherwise prompt for
  /// full config.
  Future<WitnessConfig> _readWitnessConfig(
    String workDir,
    WitnessConfig? current,
  ) async {
    if (ask.askYesNo('Clear witnesses (set to {})?', defaultValue: false)) {
      return WitnessConfig.empty();
    }
    return WizardWitnessKeys(io).configure(workDir, current);
  }

  /// Read watcher-list changes relative to [current]. Blank keeps the list, a
  /// comma-separated list of URLs appends them to what is already there, and
  /// `"clear"` removes all watchers.
  List<String> _readWatchers(List<String>? current) {
    final effective = current == null ? <String>[] : List<String>.of(current);
    if (effective.isEmpty) {
      io.println('Current watchers: (none)');
    } else {
      io.println('Current watchers:');
      for (final w in effective) {
        io.println('  - $w');
      }
    }
    final line = ask.askOptional(
      "Watchers to add (comma-separated, 'clear' to remove all, blank to "
      'keep): ',
      null,
    );
    if (line == null) {
      return effective;
    }
    if (line.trim().toLowerCase() == 'clear') {
      return const [];
    }
    for (final part in _splitList(line)) {
      if (!effective.contains(part)) {
        effective.add(part);
      }
    }
    return effective;
  }

  void _maybeWarnUnreachableHash(List<String>? hashes) {
    if (hashes == null || hashes.isEmpty) {
      return;
    }
    io.println(
      'NOTE: the corresponding next-key secret must be available at the '
      'next update, or the DID becomes unrecoverable.',
    );
  }

  List<String> _splitList(String line) {
    final out = <String>[];
    for (final part in line.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        out.add(trimmed);
      }
    }
    return out;
  }

  Future<UpdateDidResult> _runMigrate(
    DidWebVhState state,
    LocalKeySigner signer,
  ) async {
    if (state.accumulateParameters().portable != true) {
      throw WizardException(
        'DID is not portable; cannot migrate. '
        'Migration requires portable=true.',
      );
    }
    final newDomain = ask.askRequired('New domain: ');
    final newPath = ask.askOptional('New path (blank for none): ', null);
    return DidWebVh.migrate(state, signer, newDomain, newPath: newPath)
        .execute();
  }

  Future<UpdateDidResult> _runDeactivate(
    DidWebVhState state,
    LocalKeySigner signer,
    String workDir,
  ) async {
    io
      ..println('')
      ..println(
        'WARNING: Deactivation is PERMANENT.  The DID cannot be re-activated.',
      );
    final confirm = ask.askRequired("Type 'DEACTIVATE' to confirm: ");
    if (confirm != 'DEACTIVATE') {
      throw WizardException('Deactivation not confirmed; aborting.');
    }
    LocalKeySigner? nextSigner;
    final nextHashes = state.accumulateParameters().nextKeyHashes;
    if (nextHashes != null && nextHashes.isNotEmpty) {
      final nextKeyPath = p.join(workDir, WizardFiles.nextKeySecrets);
      if (!File(nextKeyPath).existsSync()) {
        throw WizardException(
          'Pre-rotation is active but ${WizardFiles.nextKeySecrets} was not '
          'found in ${p.absolute(workDir)}',
        );
      }
      nextSigner = LocalKeySigner.fromJson(WizardFiles.read(nextKeyPath));
    }
    return DidWebVh.deactivate(state, signer, nextRotationSigner: nextSigner)
        .execute();
  }

  List<LogEntry> _parseLog(String rawLog) {
    final list = <LogEntry>[];
    for (final line in rawLog.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        list.add(LogEntry.fromJsonLine(trimmed));
      }
    }
    return list;
  }
}

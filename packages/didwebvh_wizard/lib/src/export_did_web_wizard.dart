import 'dart:convert';
import 'dart:io';

import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';
import 'package:didwebvh_wizard/src/wizard_prompts.dart';
import 'package:path/path.dart' as p;

/// Interactive "export parallel did:web document" wizard. Resolves the active
/// DID from the local `did.jsonl`, runs [DidWebPublisher.toDidWeb], and writes
/// the resulting DID Document to `did.json` (spec section 3.7.10).
///
/// Faithful port of Java `ExportDidWebWizard`.
final class ExportDidWebWizard {
  /// Creates the wizard over the given [io].
  ExportDidWebWizard(this.io) : ask = WizardPrompts(io);

  /// Default output filename.
  static const String defaultOutput = 'did.json';

  static const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  /// The I/O channel used for prompting.
  final WizardIo io;

  /// Prompt helpers.
  final WizardPrompts ask;

  /// Run the export flow against files in [workDir].
  Future<void> run(String workDir) async {
    io.println('=== Export parallel did:web document ===');

    final logPath = p.join(workDir, WizardFiles.didLog);
    if (!File(logPath).existsSync()) {
      throw WizardException(
        'No ${WizardFiles.didLog} found in ${p.absolute(workDir)}',
      );
    }

    final rawLog = WizardFiles.read(logPath);
    final did = _firstEntryId(rawLog);

    // Validate the log chain so we don't export from a broken log, but don't go
    // through DidResolver.resolveFromLog – that enforces witness-proof presence
    // even when we already trust the local store, and did-witness.json is
    // optional here.
    final state = DidWebVhState.fromDidLog(did, rawLog);
    final validation = await state.validate();
    if (!validation.valid) {
      throw WizardException(
        'Log failed validation: ${validation.failureReason}',
      );
    }
    final resolved = _latestDocument(state.logEntries);

    final webDoc = DidWebPublisher.toDidWeb(resolved);
    final didWebUrl = DidWebPublisher.toDidWebUrl(did);

    final outName =
        ask.askOptional('Output filename [$defaultOutput]: ', defaultOutput)!;
    final outPath = p.join(workDir, outName);
    WizardFiles.write(outPath, _pretty.convert(webDoc.asJsonObject()));

    io
      ..println('')
      ..println('Parallel did:web DID: $didWebUrl')
      ..println('Wrote $outName to ${p.absolute(workDir)}')
      ..println(
        'Publish it alongside ${WizardFiles.didLog} so resolvers can fetch '
        'the did:web document.',
      );
  }

  DidDocument _latestDocument(List<LogEntry> entries) {
    if (entries.isEmpty) {
      throw WizardException('DID log is empty');
    }
    final last = entries[entries.length - 1];
    if (last.state == null) {
      throw WizardException('Last log entry has no DID Document state');
    }
    return DidDocument(last.state);
  }

  String _firstEntryId(String rawLog) {
    for (final line in rawLog.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return LogEntry.fromJsonLine(trimmed).state!['id']! as String;
      }
    }
    throw WizardException('DID log is empty');
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';
import 'package:didwebvh_wizard/src/wizard_prompts.dart';
import 'package:path/path.dart' as p;

/// Interactive "resolve a DID" wizard. Supports remote HTTPS and local file
/// resolution.
///
/// Faithful port of Java `ResolveWizard`.
final class ResolveWizard {
  /// Creates the wizard over the given [io], optionally with a custom
  /// [resolver] (test seam).
  ResolveWizard(this.io, {DidResolver? resolver})
      : ask = WizardPrompts(io),
        resolver = resolver ?? DidResolver();

  /// The I/O channel used for prompting.
  final WizardIo io;

  /// Prompt helpers.
  final WizardPrompts ask;

  /// The resolver used for HTTPS and in-memory resolution.
  final DidResolver resolver;

  static const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  /// Run the resolve flow. [workDir] is used as the default for local-file
  /// lookups.
  Future<void> run(String workDir) async {
    io
      ..println('=== Resolve a did:webvh DID ===')
      ..println('  1) Resolve over HTTPS')
      ..println('  2) Resolve from a local did.jsonl file');
    final choice = ask.askChoice('Choose 1 or 2: ', 2);

    final options = _buildOptions();

    ResolveResult result;
    try {
      if (choice == 1) {
        final did = ask.askRequired('DID: ');
        result = await resolver.resolve(did, options);
      } else {
        final defaultPath = p.join(workDir, WizardFiles.didLog);
        final pathStr =
            ask.askOptional('did.jsonl path [$defaultPath]: ', defaultPath)!;
        if (!File(pathStr).existsSync()) {
          throw WizardException('File not found: $pathStr');
        }
        final did = ask.askOptional(
          'Expected DID (blank to skip validation of id): ',
          null,
        );
        result = await resolver.resolveFromLog(
          WizardFiles.read(pathStr),
          did,
          options,
        );
      }
    } on DidWebVhException catch (e) {
      io.printError('Resolution failed: ${e.message}');
      return;
    }

    io.println('');
    if (result.error != null) {
      io.println('Error: ${result.error}');
      if (result.problemDetails != null) {
        io
          ..println('Details:')
          ..println(_pretty.convert(result.problemDetails));
      }
      return;
    }
    io.println('DID Document:');
    if (result.didDocument != null) {
      io.println(_pretty.convert(result.didDocument!.asJsonObject()));
    } else {
      io.println('(none)');
    }
    io
      ..println('')
      ..println('Resolution metadata:')
      ..println(_pretty.convert(result.metadata?.toJson()));
  }

  ResolveOptions _buildOptions() {
    if (!ask.askYesNo('Filter by a specific version?', defaultValue: false)) {
      return ResolveOptions.defaults();
    }
    io.println('  1) versionId  2) versionTime  3) versionNumber');
    final sub = ask.askChoice('Choose 1-3: ', 3);
    final options = ResolveOptions();
    if (sub == 1) {
      options.versionId(ask.askRequired('versionId: '));
    } else if (sub == 2) {
      options.versionTime(ask.askRequired('versionTime (ISO-8601): '));
    } else if (sub == 3) {
      options.versionNumber(ask.askInt('versionNumber: ', null));
    }
    return options;
  }
}

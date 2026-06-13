import 'dart:convert';

import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';
import 'package:didwebvh_wizard/src/wizard_prompts.dart';
import 'package:didwebvh_wizard/src/wizard_witness_keys.dart';
import 'package:didwebvh_wizard/src/wizard_witness_proofs.dart';
import 'package:path/path.dart' as p;

/// Interactive "create a new DID" wizard.
///
/// Faithful port of Java `CreateWizard`.
final class CreateWizard {
  /// Creates the wizard over the given [io].
  CreateWizard(this.io) : ask = WizardPrompts(io);

  /// The I/O channel used for prompting.
  final WizardIo io;

  /// Prompt helpers.
  final WizardPrompts ask;

  /// Run the create flow, writing outputs to [workDir]. Returns the created DID
  /// string.
  Future<String> run(String workDir) async {
    io.println('=== Create a new did:webvh DID ===');

    final domain = ask.askRequired('Web domain (e.g. example.com): ');
    final path = ask.askOptional(
      "Path (optional, 'dids:issuer' style, blank to skip): ",
      null,
    );

    final signer = await _loadOrGenerateSigner(workDir);
    io.println('Authorization key multikey: ${signer.publicKeyMultikey}');

    final config = DidWebVh.create(domain, signer);
    if (path != null) {
      config.path(path);
    }

    final alsoKnownAs =
        _readList('alsoKnownAs (comma-separated, blank for none): ');
    if (alsoKnownAs.isNotEmpty) {
      config.alsoKnownAs(alsoKnownAs);
    }

    final controllers = _readControllers();
    if (controllers != null) {
      config.controllers(controllers);
    }

    final additional = _buildAdditionalDocumentContent();
    if (additional.isNotEmpty) {
      config.additionalDocumentContent(additional);
    }

    if (ask.askYesNo('Make this DID portable?', defaultValue: false)) {
      config.portable(true);
    }

    LocalKeySigner? nextKeySigner;
    if (ask.askYesNo(
      'Enable pre-rotation (generate a next key now)?',
      defaultValue: false,
    )) {
      nextKeySigner = await LocalKeySigner.generate();
      WizardFiles.write(
        p.join(workDir, WizardFiles.nextKeySecrets),
        nextKeySigner.toJson(),
      );
      io.println(
        'Next-rotation key saved to ${WizardFiles.nextKeySecrets} '
        '(multikey: ${nextKeySigner.publicKeyMultikey})',
      );
      final hash = PreRotationHashGenerator.generateHash(
        nextKeySigner.publicKeyMultikey,
      );
      config.nextKeyHashes([hash]);
    }

    final witness = await _readWitnessConfig(workDir);
    if (witness != null) {
      config.witness(witness);
    }

    final watchers =
        _readList('Watchers (comma-separated URLs, blank for none): ');
    if (watchers.isNotEmpty) {
      config.watchers(watchers);
    }

    final ttl = ask.askInt('TTL seconds [default 3600, 0 = no cache]: ', 3600);
    if (ttl != 3600) {
      config.ttl(ttl);
    }

    final result = await config.execute();

    // Spec 3.7.8: did-witness.json MUST be published BEFORE did.jsonl. If the
    // first entry already activates a witness set, resolvers expect proofs for
    // that entry too, so collect them before writing the log.
    if (witness != null && witness.isActive) {
      await WizardWitnessProofs(io).collectForNewEntries(
        Parameters.defaults(),
        [result.logEntry],
        workDir,
      );
    }

    WizardFiles.write(p.join(workDir, WizardFiles.didLog), result.logLine);

    io
      ..println('')
      ..println('DID created: ${result.did}')
      ..println('Files written to ${p.absolute(workDir)}:')
      ..println('  - ${WizardFiles.didLog}')
      ..println('  - ${WizardFiles.didSecrets}   (KEEP SECURE)');
    if (nextKeySigner != null) {
      io.println('  - ${WizardFiles.nextKeySecrets}  (KEEP SECURE)');
    }
    return result.did;
  }

  Future<LocalKeySigner> _loadOrGenerateSigner(String workDir) async {
    io
      ..println('')
      ..println('Authorization key:')
      ..println('  1) Generate a new Ed25519 key')
      ..println('  2) Import from an existing ${WizardFiles.didSecrets} JSON '
          'file');
    final choice = ask.askChoice('Choose 1 or 2: ', 2);
    LocalKeySigner signer;
    if (choice == 1) {
      signer = await LocalKeySigner.generate();
    } else {
      final pathStr = ask.askRequired('Path to existing key JSON: ');
      signer = LocalKeySigner.fromJson(WizardFiles.read(pathStr));
    }
    WizardFiles.write(
      p.join(workDir, WizardFiles.didSecrets),
      signer.toJson(),
    );
    return signer;
  }

  List<String> _readList(String prompt) {
    final line = ask.askOptional(prompt, null);
    if (line == null) {
      return const [];
    }
    final out = <String>[];
    for (final part in line.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        out.add(trimmed);
      }
    }
    return out;
  }

  /// Ask for the DID Document `controller` property. Returns `null` to keep the
  /// library default (single controller = the DID itself); an empty list to
  /// emit no `controller` property; a non-empty list otherwise.
  List<String>? _readControllers() {
    io
      ..println('')
      ..println("Controller (DID Document 'controller' property):")
      ..println('  blank   keep default (controller = the DID itself)')
      ..println("  '-'     omit the controller property entirely")
      ..println('  list    comma-separated DIDs to use as controller(s)');
    final line = ask.askOptional('Controllers: ', null);
    if (line == null) {
      return null;
    }
    if (line.trim() == '-') {
      return const [];
    }
    final controllers = <String>[];
    for (final part in line.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        controllers.add(trimmed);
      }
    }
    return controllers.isEmpty ? null : controllers;
  }

  Map<String, Object?> _buildAdditionalDocumentContent() {
    final extra = <String, Object?>{};

    final services = ask.askOptional(
      'Services JSON array (paste one line, blank to skip): ',
      null,
    );
    if (services != null) {
      Object? parsed;
      try {
        parsed = jsonDecode(services);
      } on FormatException catch (e) {
        throw WizardException('Invalid services JSON: ${e.message}', e);
      }
      if (parsed is! List) {
        throw WizardException('Services must be a JSON array');
      }
      extra['service'] = parsed;
    }
    return extra;
  }

  Future<WitnessConfig?> _readWitnessConfig(String workDir) async {
    if (!ask.askYesNo('Configure witnesses?', defaultValue: false)) {
      return null;
    }
    return WizardWitnessKeys(io).configure(workDir);
  }
}

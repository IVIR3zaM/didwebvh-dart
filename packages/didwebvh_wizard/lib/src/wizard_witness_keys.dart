import 'dart:io';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';
import 'package:didwebvh_wizard/src/wizard_prompts.dart';
import 'package:path/path.dart' as p;

/// Shared witness configuration helpers used by both Create and Update flows.
///
/// Witness secrets the user has access to locally are stored under
/// `<workDir>/witnesses/witness-<multikey>.json`. A witness is always
/// identified in the DID log by its `did:key:<multikey>` URL; the accompanying
/// secret is optional — if the local store has it the wizard can produce a Data
/// Integrity proof for that witness automatically.
///
/// Faithful port of Java `WizardWitnessKeys`.
final class WizardWitnessKeys {
  /// Creates the helper over the given [io].
  WizardWitnessKeys(this.io) : ask = WizardPrompts(io);

  /// The I/O channel used for prompting.
  final WizardIo io;

  /// Prompt helpers.
  final WizardPrompts ask;

  /// Path to the witness key store inside [workDir].
  static String storeDir(String workDir) =>
      p.join(workDir, WizardFiles.witnessesDir);

  /// File name used to save a witness signer JSON to the local store.
  static String storeFile(String workDir, String multikey) =>
      p.join(storeDir(workDir), 'witness-$multikey.json');

  /// List all witness signers currently kept in the local store.
  static List<LocalKeySigner> listStored(String workDir) {
    final dir = Directory(storeDir(workDir));
    final signers = <LocalKeySigner>[];
    if (!dir.existsSync()) {
      return signers;
    }
    try {
      for (final entity in dir.listSync()) {
        final name = p.basename(entity.path);
        if (entity is File &&
            name.startsWith('witness-') &&
            name.endsWith('.json')) {
          signers.add(LocalKeySigner.fromJson(WizardFiles.read(entity.path)));
        }
      }
    } on WizardException {
      rethrow;
    } on Object catch (e) {
      throw WizardException('Failed to list witness key store: $e', e);
    }
    return signers;
  }

  /// Look up a stored witness signer by its multikey, or `null` if absent.
  static LocalKeySigner? findByMultikey(String workDir, String multikey) {
    final file = storeFile(workDir, multikey);
    if (!File(file).existsSync()) {
      return null;
    }
    return LocalKeySigner.fromJson(WizardFiles.read(file));
  }

  /// Persist [signer] as a witness secret under `workDir/witnesses/`.
  static void save(String workDir, LocalKeySigner signer) {
    final dir = storeDir(workDir);
    try {
      Directory(dir).createSync(recursive: true);
    } on Object catch (e) {
      throw WizardException('Failed to create $dir: $e', e);
    }
    WizardFiles.write(
      storeFile(workDir, signer.publicKeyMultikey),
      signer.toJson(),
    );
  }

  /// Interactive witness-set builder used by create and update.
  ///
  /// When [current] is non-null its entries are kept as the starting set, so
  /// the user only needs to add, remove, or keep as-is.
  Future<WitnessConfig> configure(
    String workDir, [
    WitnessConfig? current,
  ]) async {
    final entries = <WitnessEntry>[];
    if (current != null) {
      entries.addAll(current.witnesses);
    }
    io.println("Configure witnesses – add/remove entries, then choose 'Done'.");
    while (true) {
      io.println('');
      _printCurrentSet(entries);
      io
        ..println('  1) Generate a new witness key (stored locally)')
        ..println('  2) Use an existing stored witness secret')
        ..println('  3) Import a witness secret from a path (copied locally)')
        ..println('  4) Enter a did:key for an external witness')
        ..println('  5) Remove an existing witness')
        ..println('  6) Done');
      final choice = ask.askChoice('Choose 1-6: ', 6);
      if (choice == 6) {
        break;
      }
      if (choice == 5) {
        _removeOne(entries);
        continue;
      }
      final added = await _addOne(choice, workDir, entries);
      if (added != null) {
        entries.add(added);
        io.println('Added witness ${added.id}');
      }
    }
    if (entries.isEmpty) {
      throw WizardException(
        'At least one witness is required (or skip witness configuration).',
      );
    }
    final defaultThreshold =
        _currentThresholdOrMajority(current, entries.length);
    final threshold = ask.askInt(
      'Witness threshold [default $defaultThreshold, max ${entries.length}]: ',
      defaultThreshold,
    );
    if (threshold < 1 || threshold > entries.length) {
      throw WizardException(
        'Threshold must be between 1 and ${entries.length}',
      );
    }
    return WitnessConfig(threshold, entries);
  }

  void _printCurrentSet(List<WitnessEntry> entries) {
    if (entries.isEmpty) {
      io.println('Current witnesses: (none)');
      return;
    }
    io.println('Current witnesses (${entries.length}):');
    for (final entry in entries) {
      io.println('  - ${entry.id}');
    }
    io
      ..println('')
      ..println('Actions:');
  }

  void _removeOne(List<WitnessEntry> entries) {
    if (entries.isEmpty) {
      io.printError('No witnesses to remove.');
      return;
    }
    io.println('Select a witness to remove:');
    for (var i = 0; i < entries.length; i++) {
      io.println('  [${i + 1}] ${entries[i].id}');
    }
    final idx = ask.askChoice(
      'Remove which witness (1-${entries.length})? ',
      entries.length,
    );
    final removed = entries.removeAt(idx - 1);
    io.println('Removed ${removed.id}');
  }

  int _currentThresholdOrMajority(WitnessConfig? current, int size) {
    final majority = (size ~/ 2) + 1;
    if (current == null) {
      return majority;
    }
    final existing = current.threshold;
    return existing >= 1 && existing <= size ? existing : majority;
  }

  Future<WitnessEntry?> _addOne(
    int choice,
    String workDir,
    List<WitnessEntry> alreadyAdded,
  ) async {
    switch (choice) {
      case 1:
        final signer = await LocalKeySigner.generate();
        save(workDir, signer);
        io.println(
          'Generated witness key: '
          '${storeFile(workDir, signer.publicKeyMultikey)}',
        );
        return _asEntry(signer, alreadyAdded);
      case 2:
        final stored = listStored(workDir);
        if (stored.isEmpty) {
          io.printError(
            'No stored witness keys found in '
            '${p.absolute(storeDir(workDir))}',
          );
          return null;
        }
        for (var i = 0; i < stored.length; i++) {
          io.println('  ${i + 1}) did:key:${stored[i].publicKeyMultikey}');
        }
        final idx = ask.askChoice(
          'Pick a stored key 1-${stored.length}: ',
          stored.length,
        );
        return _asEntry(stored[idx - 1], alreadyAdded);
      case 3:
        final pathStr = ask.askRequired('Path to witness signer JSON: ');
        LocalKeySigner signer;
        try {
          signer = LocalKeySigner.fromJson(WizardFiles.read(pathStr));
        } on Object catch (e) {
          io.printError('Could not load witness key: $e');
          return null;
        }
        save(workDir, signer);
        io.println('Copied witness secret to local store.');
        return _asEntry(signer, alreadyAdded);
      case 4:
        final didKey = ask.askRequired('Witness did:key URL: ');
        if (!didKey.startsWith('did:key:')) {
          io.printError('Must start with did:key: – got $didKey');
          return null;
        }
        if (_containsId(alreadyAdded, didKey)) {
          io.printError('Duplicate witness: $didKey');
          return null;
        }
        return WitnessEntry(didKey);
      default:
        return null;
    }
  }

  WitnessEntry? _asEntry(
    LocalKeySigner signer,
    List<WitnessEntry> alreadyAdded,
  ) {
    final did = 'did:key:${signer.publicKeyMultikey}';
    if (_containsId(alreadyAdded, did)) {
      io.printError('Duplicate witness: $did');
      return null;
    }
    return WitnessEntry(did);
  }

  bool _containsId(List<WitnessEntry> list, String id) {
    for (final w in list) {
      if (id == w.id) {
        return true;
      }
    }
    return false;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';
import 'package:didwebvh_wizard/src/wizard_prompts.dart';
import 'package:didwebvh_wizard/src/wizard_witness_keys.dart';
import 'package:path/path.dart' as p;

/// Collects witness proofs for newly appended log entries and maintains the
/// `did-witness.json` file next to `did.jsonl` (spec section 3.7.8).
///
/// Per spec, proofs are over the JCS-canonicalized document
/// `{"versionId": "<versionId>"}`, and the `did-witness.json` file MUST be
/// published before the corresponding `did.jsonl` entry.
///
/// Faithful port of Java `WizardWitnessProofs`.
final class WizardWitnessProofs {
  /// Creates the helper over the given [io].
  WizardWitnessProofs(this.io) : ask = WizardPrompts(io);

  /// The I/O channel used for prompting.
  final WizardIo io;

  /// Prompt helpers.
  final WizardPrompts ask;

  /// For each new entry that needs witnessing, prompt the user for witness
  /// signer keys and write an updated `did-witness.json`. Throws
  /// [WizardException] if the threshold cannot be reached.
  ///
  /// [priorParams] is the effective parameters AFTER all existing log entries,
  /// BEFORE the first new entry (i.e. `existingState.accumulateParameters()`).
  /// [newEntries] are the new entries about to be appended (in order).
  /// [workDir] holds `did-witness.json`.
  Future<void> collectForNewEntries(
    Parameters priorParams,
    List<LogEntry> newEntries,
    String workDir,
  ) async {
    var accumulated = priorParams;
    final newProofEntries = <WitnessProofEntry>[];
    for (final entry in newEntries) {
      final authorized = _authorizedWitnesses(accumulated, entry.parameters);
      if (authorized != null && authorized.isActive) {
        newProofEntries.add(
          await _buildProofEntry(entry.versionId, authorized, workDir),
        );
      }
      if (entry.parameters != null) {
        accumulated = accumulated.merge(entry.parameters);
      }
    }
    if (newProofEntries.isEmpty) {
      return;
    }
    final witnessPath = p.join(workDir, WizardFiles.didWitness);
    final merged = _mergeWithExisting(witnessPath, newProofEntries);
    WizardFiles.write(witnessPath, _serialize(merged));
    final n = newProofEntries.length;
    io.println(
      'Wrote $n witness proof entr${n == 1 ? 'y' : 'ies'} '
      'to ${WizardFiles.didWitness}',
    );
  }

  /// Determine which witness set must approve [entryDelta].
  ///
  /// Per spec §3.7.5, a new `witness` list "becomes active AFTER the new DID
  /// log has been published". So while witnesses are already active, every
  /// entry — including one that changes or turns off the list — MUST be
  /// witnessed by the list in effect BEFORE this entry. The only exception is
  /// the first activation: with no prior list, the new merged list applies now.
  WitnessConfig? _authorizedWitnesses(
    Parameters priorParams,
    Parameters? entryDelta,
  ) {
    final priorActive = priorParams.witness;
    if (priorActive != null && priorActive.isActive) {
      return priorActive;
    }
    return priorParams.merge(entryDelta).witness;
  }

  Future<WitnessProofEntry> _buildProofEntry(
    String? versionId,
    WitnessConfig authorized,
    String workDir,
  ) async {
    io
      ..println('')
      ..println('Entry $versionId requires witness approval.')
      ..println(
        '  Threshold: ${authorized.threshold} '
        'of ${authorized.witnesses.length} witness(es).',
      );
    final signedDoc = <String, Object?>{'versionId': versionId};

    final proofs = <DataIntegrityProof>[];
    final signedBy = <String>{};

    // Auto-sign with every stored witness secret that matches the authorized
    // set. We intentionally do not stop at the threshold.
    for (final w in authorized.witnesses) {
      final multikey = w.id!.substring('did:key:'.length);
      final stored = WizardWitnessKeys.findByMultikey(workDir, multikey);
      if (stored != null) {
        proofs.add(await _signProof(stored, signedDoc));
        signedBy.add(w.id!);
        io.println('  Auto-signed with stored secret for ${w.id}');
      }
    }

    // If threshold not yet met, prompt for additional witness secret paths.
    while (proofs.length < authorized.threshold) {
      final remaining = authorized.threshold - proofs.length;
      io
        ..println('')
        ..println('  Remaining authorized witnesses without proofs:');
      for (final w in authorized.witnesses) {
        if (!signedBy.contains(w.id)) {
          io.println('    - ${w.id}');
        }
      }
      final keyPathStr = ask.askRequired(
        'Path to witness signing-key JSON ($remaining more needed): ',
      );
      LocalKeySigner witnessSigner;
      try {
        witnessSigner = LocalKeySigner.fromJson(WizardFiles.read(keyPathStr));
      } on Object catch (e) {
        io.printError('Could not load witness key: $e');
        continue;
      }
      final witnessDid = 'did:key:${witnessSigner.publicKeyMultikey}';
      if (!_isAuthorized(witnessDid, authorized.witnesses)) {
        io.printError('$witnessDid is not in the authorized witness list.');
        continue;
      }
      if (signedBy.contains(witnessDid)) {
        io.printError('$witnessDid already provided a proof.');
        continue;
      }
      WizardWitnessKeys.save(workDir, witnessSigner);
      proofs.add(await _signProof(witnessSigner, signedDoc));
      signedBy.add(witnessDid);
      io.println('Accepted proof from $witnessDid');
    }
    return WitnessProofEntry.of(versionId, proofs);
  }

  bool _isAuthorized(String witnessDid, List<WitnessEntry> authorized) {
    for (final w in authorized) {
      if (witnessDid == w.id) {
        return true;
      }
    }
    return false;
  }

  Future<DataIntegrityProof> _signProof(
    LocalKeySigner signer,
    Map<String, Object?> signedDoc,
  ) async {
    final proof = DataIntegrityProof.defaults()
      ..verificationMethod = signer.verificationMethod
      ..created = _isoUtcNow();
    final hashData = ProofGenerator.buildHashData(proof, signedDoc);
    final signature = await signer.sign(hashData);
    proof.proofValue = Base58Btc.encodeMultibase(signature);
    return proof;
  }

  List<WitnessProofEntry> _mergeWithExisting(
    String witnessPath,
    List<WitnessProofEntry> newEntries,
  ) {
    final byVersion = <String, WitnessProofEntry>{};
    if (File(witnessPath).existsSync()) {
      final decoded = jsonDecode(WizardFiles.read(witnessPath));
      if (decoded is List) {
        for (final item in decoded) {
          final entry =
              WitnessProofEntry.fromJson((item as Map).cast<String, Object?>());
          byVersion[entry.versionId!] = entry;
        }
      }
    }
    for (final entry in newEntries) {
      byVersion[entry.versionId!] = entry;
    }
    return byVersion.values.toList();
  }

  String _serialize(List<WitnessProofEntry> entries) {
    return jsonEncode([for (final e in entries) e.toJson(omitNull: true)]);
  }

  /// Formats the current instant as `yyyy-MM-dd'T'HH:mm:ss'Z'` in UTC, matching
  /// the reference's `ISO_UTC` formatter (seconds precision).
  static String _isoUtcNow() {
    final u = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }
}

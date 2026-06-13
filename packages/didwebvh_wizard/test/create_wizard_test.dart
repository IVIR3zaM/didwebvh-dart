import 'dart:io';

import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:didwebvh_wizard/didwebvh_wizard.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/scripted_wizard_io.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wizard_create_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('creates a minimal DID and writes files', () async {
    final io = ScriptedWizardIo([
      'example.com', // domain
      '', // path (blank)
      '1', // generate key
      '', // alsoKnownAs (blank)
      '', // extra controllers (blank)
      '', // services (blank)
      'n', // portable
      'n', // pre-rotation
      'n', // witnesses
      '', // watchers (blank)
      '', // TTL (default)
    ]);

    final did = await CreateWizard(io).run(tmp.path);

    expect(did, startsWith('did:webvh:'));
    expect(did, contains(':example.com'));
    expect(File(p.join(tmp.path, WizardFiles.didLog)).existsSync(), isTrue);
    expect(File(p.join(tmp.path, WizardFiles.didSecrets)).existsSync(), isTrue);
    expect(
      File(p.join(tmp.path, WizardFiles.nextKeySecrets)).existsSync(),
      isFalse,
    );

    // Secrets roundtrip through LocalKeySigner.
    final secrets = WizardFiles.read(p.join(tmp.path, WizardFiles.didSecrets));
    final reloaded = LocalKeySigner.fromJson(secrets);
    expect(reloaded.publicKeyMultikey, startsWith('z6Mk'));

    // The log resolves and validates.
    final log = WizardFiles.read(p.join(tmp.path, WizardFiles.didLog));
    final result = await DidResolver().resolveFromLog(log, did);
    expect(result.error, isNull);
    expect(result.didDocument, isNotNull);
    expect(result.didDocument!.id, did);

    final state = DidWebVhState.fromDidLog(did, log);
    expect((await state.validate()).valid, isTrue);
    expect(io.remainingInputs, 0);
  });

  test('creates a portable DID with pre-rotation and path', () async {
    final io = ScriptedWizardIo([
      'issuer.example.com', // domain
      'dids:alice', // path
      '1', // generate key
      '', // alsoKnownAs
      '', // extra controllers
      '', // services
      'y', // portable
      'y', // pre-rotation
      'n', // witnesses
      '', // watchers
      '300', // TTL
    ]);

    final did = await CreateWizard(io).run(tmp.path);
    expect(did, contains(':issuer.example.com:dids:alice'));
    expect(
      File(p.join(tmp.path, WizardFiles.nextKeySecrets)).existsSync(),
      isTrue,
    );
  });

  test('witness generate stores secret and writes proofs', () async {
    final io = ScriptedWizardIo([
      'example.com', '',
      '1', // generate key
      '', // alsoKnownAs
      '', // extra controllers
      '', // services
      'n', // portable
      'n', // pre-rotation
      'y', // configure witnesses
      '1', // generate new witness (auto-stored locally)
      '6', // done
      '', // threshold (default 1)
      '', // watchers
      '', // ttl
    ]);
    final did = await CreateWizard(io).run(tmp.path);
    expect(did, startsWith('did:webvh:'));
    final witnessesDir = Directory(p.join(tmp.path, WizardFiles.witnessesDir));
    expect(witnessesDir.existsSync(), isTrue);
    expect(witnessesDir.listSync().whereType<File>().length, 1);

    // The generated witness's stored secret must have been used to sign the
    // first entry so the did-witness.json is ready to publish alongside
    // did.jsonl.
    final witnessFile = File(p.join(tmp.path, WizardFiles.didWitness));
    expect(witnessFile.existsSync(), isTrue);
    final witnessJson = WizardFiles.read(witnessFile.path);
    expect(witnessJson, startsWith('['));
    expect(witnessJson, contains('"versionId"'));
    expect(witnessJson, contains('1-'));
  });

  test('rejects invalid services JSON', () async {
    final io = ScriptedWizardIo([
      'example.com',
      '',
      '1',
      '',
      '',
      'not-json', // services: invalid
    ]);
    expect(
      () => CreateWizard(io).run(tmp.path),
      throwsA(isA<WizardException>()),
    );
  });
}

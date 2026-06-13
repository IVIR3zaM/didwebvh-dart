import 'dart:io';

import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:didwebvh_wizard/didwebvh_wizard.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/scripted_wizard_io.dart';

Future<CreateDidResult> _seedDid(String tmp, {required bool portable}) async {
  final signer = await LocalKeySigner.generate();
  final result =
      await DidWebVh.create('example.com', signer).portable(portable).execute();
  WizardFiles.write(p.join(tmp, WizardFiles.didLog), result.logLine);
  WizardFiles.write(p.join(tmp, WizardFiles.didSecrets), signer.toJson());
  return result;
}

String _extractDid(String line) {
  final idx = line.indexOf('"id":"');
  final start = idx + 6;
  final end = line.indexOf('"', start);
  return line.substring(start, end);
}

void main() {
  late Directory dir;
  late String tmp;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wizard_update_');
    tmp = dir.path;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('modify appends new entry with changed TTL', () async {
    await _seedDid(tmp, portable: false);
    final io = ScriptedWizardIo([
      '1', // modify
      'n', // don't replace document
      'y', // change parameters
      'n', // updateKeys
      'n', // nextKeyHashes
      'n', // witness
      'n', // watchers
      'y', // ttl
      '120', // new TTL
    ]);

    await UpdateWizard(io).run(tmp);

    final log = WizardFiles.read(p.join(tmp, WizardFiles.didLog));
    final lines = log.split('\n');
    expect(lines, hasLength(2));

    final reloaded = DidWebVhState.fromDidLog(_extractDid(lines[0]), log);
    final res = await reloaded.validate();
    expect(res.valid, isTrue);
    expect(reloaded.activeParameters!.ttl, 120);
  });

  test('migrate requires portable', () async {
    await _seedDid(tmp, portable: false);
    final io = ScriptedWizardIo(['2']);
    expect(
      () => UpdateWizard(io).run(tmp),
      throwsA(
        isA<WizardException>()
            .having((e) => e.message, 'message', contains('portable')),
      ),
    );
  });

  test('migrate appends entry when portable', () async {
    await _seedDid(tmp, portable: true);
    final io = ScriptedWizardIo([
      '2', // migrate
      'new.example.com', // new domain
      '', // no path
    ]);
    await UpdateWizard(io).run(tmp);
    final log = WizardFiles.read(p.join(tmp, WizardFiles.didLog));
    expect(log.split('\n'), hasLength(2));
    expect(log, contains('new.example.com'));
  });

  test('deactivate requires confirmation', () async {
    await _seedDid(tmp, portable: false);
    final io = ScriptedWizardIo([
      '3',
      'nope', // wrong confirmation
    ]);
    expect(
      () => UpdateWizard(io).run(tmp),
      throwsA(
        isA<WizardException>()
            .having((e) => e.message, 'message', contains('not confirmed')),
      ),
    );
  });

  test('deactivate appends final entry', () async {
    await _seedDid(tmp, portable: false);
    final io = ScriptedWizardIo(['3', 'DEACTIVATE']);
    await UpdateWizard(io).run(tmp);
    final log = WizardFiles.read(p.join(tmp, WizardFiles.didLog));
    final state =
        DidWebVhState.fromDidLog(_extractDid(log.split('\n')[0]), log);
    expect((await state.validate()).valid, isTrue);
    expect(state.isDeactivated, isTrue);
  });

  test('errors when no log in directory', () async {
    final io = ScriptedWizardIo();
    expect(
      () => UpdateWizard(io).run(tmp),
      throwsA(
        isA<WizardException>()
            .having((e) => e.message, 'message', contains(WizardFiles.didLog)),
      ),
    );
  });

  test('replace document rejects SCID change', () async {
    await _seedDid(tmp, portable: false);
    // 46 base58btc chars, different from any generated SCID.
    const otherScid = 'Qmaaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeee';
    const badDoc = '{"id":"did:webvh:$otherScid:example.com"}';
    final io = ScriptedWizardIo([
      '1', // modify
      'y', // replace document
      badDoc,
    ]);
    expect(
      () => UpdateWizard(io).run(tmp),
      throwsA(
        isA<WizardException>()
            .having((e) => e.message, 'message', contains('SCID')),
      ),
    );
  });

  test('replace document rejects domain change when not portable', () async {
    final created = await _seedDid(tmp, portable: false);
    final scid = created.did.split(':')[2];
    final badDoc = '{"id":"did:webvh:$scid:other.example.com"}';
    final io = ScriptedWizardIo(['1', 'y', badDoc]);
    expect(
      () => UpdateWizard(io).run(tmp),
      throwsA(
        isA<WizardException>()
            .having((e) => e.message, 'message', contains('not portable')),
      ),
    );
  });

  test('replace document rejects domain change, suggests migrate when portable',
      () async {
    final created = await _seedDid(tmp, portable: true);
    final scid = created.did.split(':')[2];
    final badDoc = '{"id":"did:webvh:$scid:other.example.com"}';
    final io = ScriptedWizardIo(['1', 'y', badDoc]);
    expect(
      () => UpdateWizard(io).run(tmp),
      throwsA(
        isA<WizardException>()
            .having((e) => e.message, 'message', contains('Migrate')),
      ),
    );
  });

  test('replace document requires id field', () async {
    await _seedDid(tmp, portable: false);
    final io = ScriptedWizardIo(['1', 'y', '{"foo":"bar"}']);
    expect(
      () => UpdateWizard(io).run(tmp),
      throwsA(
        isA<WizardException>().having(
          (e) => e.message,
          'message',
          contains("missing required 'id' field"),
        ),
      ),
    );
  });

  test('change watchers parameter', () async {
    await _seedDid(tmp, portable: false);
    final io = ScriptedWizardIo([
      '1', // modify
      'n', // don't replace doc
      'y', // change params
      'n', // updateKeys
      'n', // nextKeyHashes
      'n', // witness
      'y', // watchers
      'https://watch.example.com', // watchers value
      'n', // ttl
    ]);
    await UpdateWizard(io).run(tmp);
    final log = WizardFiles.read(p.join(tmp, WizardFiles.didLog));
    final reloaded =
        DidWebVhState.fromDidLog(_extractDid(log.split('\n')[0]), log);
    expect((await reloaded.validate()).valid, isTrue);
    expect(
      reloaded.activeParameters!.watchers,
      ['https://watch.example.com'],
    );
  });

  test('change watchers appends to existing list', () async {
    final signer = await LocalKeySigner.generate();
    final created = await DidWebVh.create('example.com', signer)
        .watchers(['https://first.example.com']).execute();
    WizardFiles.write(p.join(tmp, WizardFiles.didLog), created.logLine);
    WizardFiles.write(p.join(tmp, WizardFiles.didSecrets), signer.toJson());

    final io = ScriptedWizardIo([
      '1', // modify
      'n', // don't replace doc
      'y', // change params
      'n', 'n', 'n', // updateKeys, nextKeyHashes, witness
      'y', // watchers
      'https://second.example.com', // append
      'n', // ttl
    ]);
    await UpdateWizard(io).run(tmp);
    final log = WizardFiles.read(p.join(tmp, WizardFiles.didLog));
    final reloaded =
        DidWebVhState.fromDidLog(_extractDid(log.split('\n')[0]), log);
    expect((await reloaded.validate()).valid, isTrue);
    expect(
      reloaded.activeParameters!.watchers,
      ['https://first.example.com', 'https://second.example.com'],
    );
  });

  test('change witnesses seeds from existing config', () async {
    final controller = await LocalKeySigner.generate();
    final witnessKey = await LocalKeySigner.generate();
    final witness = WitnessConfig(
      1,
      [WitnessEntry('did:key:${witnessKey.publicKeyMultikey}')],
    );
    final created = await DidWebVh.create('example.com', controller)
        .witness(witness)
        .execute();
    WizardFiles.write(p.join(tmp, WizardFiles.didLog), created.logLine);
    WizardFiles.write(p.join(tmp, WizardFiles.didSecrets), controller.toJson());
    final witnessKeyFile = p.join(tmp, 'witness-key.json');
    WizardFiles.write(witnessKeyFile, witnessKey.toJson());

    final io = ScriptedWizardIo([
      '1', // modify
      'n', // don't replace doc
      'y', // change params
      'n', 'n', // updateKeys, nextKeyHashes
      'y', // witness
      'n', // don't clear witnesses
      '1', // generate a new (second) witness
      '6', // done
      '2', // threshold = 2 (needs seeded existing entry)
      'n', // watchers
      'n', // ttl
      witnessKeyFile, // existing witness signs the new entry
    ]);
    await UpdateWizard(io).run(tmp);

    final log = WizardFiles.read(p.join(tmp, WizardFiles.didLog));
    final lines = log.split('\n');
    expect(lines, hasLength(2));
    final reloaded = DidWebVhState.fromDidLog(_extractDid(lines[0]), log);
    final active = reloaded.accumulateParameters();
    expect(active.witness!.threshold, 2);
    expect(active.witness!.witnesses, hasLength(2));
  });

  test('update with active witness collects proofs', () async {
    final controller = await LocalKeySigner.generate();
    final witnessKey = await LocalKeySigner.generate();
    final witness = WitnessConfig(
      1,
      [WitnessEntry('did:key:${witnessKey.publicKeyMultikey}')],
    );
    final created = await DidWebVh.create('example.com', controller)
        .witness(witness)
        .execute();
    WizardFiles.write(p.join(tmp, WizardFiles.didLog), created.logLine);
    WizardFiles.write(p.join(tmp, WizardFiles.didSecrets), controller.toJson());
    final witnessKeyFile = p.join(tmp, 'witness-key.json');
    WizardFiles.write(witnessKeyFile, witnessKey.toJson());

    final io = ScriptedWizardIo([
      '1', // modify
      'n', // don't replace doc
      'y', // change params
      'n', 'n', 'n', 'n', // updateKeys, nextKeyHashes, witness, watchers
      'y', // ttl
      '60',
      witnessKeyFile, // witness signer key
    ]);
    await UpdateWizard(io).run(tmp);

    final witnessFile = File(p.join(tmp, WizardFiles.didWitness));
    expect(witnessFile.existsSync(), isTrue);
    final witnessJson = WizardFiles.read(witnessFile.path);
    expect(witnessJson, startsWith('['));
    expect(witnessJson, contains('2-'));
  });
}

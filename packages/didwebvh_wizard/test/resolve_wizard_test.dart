import 'dart:io';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:didwebvh_wizard/didwebvh_wizard.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/scripted_wizard_io.dart';

void main() {
  late Directory dir;
  late String tmp;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wizard_resolve_');
    tmp = dir.path;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('resolves from a local file', () async {
    final signer = await LocalKeySigner.generate();
    final created = await DidWebVh.create('example.com', signer).execute();
    WizardFiles.write(p.join(tmp, WizardFiles.didLog), created.logLine);

    final io = ScriptedWizardIo([
      '2', // local file
      'n', // no version filter
      '', // accept default file path
      created.did, // expected DID
    ]);
    await ResolveWizard(io).run(tmp);
    expect(io.allOutput(), contains('DID Document:'));
    expect(io.allOutput(), contains(created.did));
    expect(io.allOutput(), contains('Resolution metadata:'));
    expect(io.errors, isEmpty);
  });

  test('reports error when file missing', () async {
    final io = ScriptedWizardIo([
      '2',
      'n',
      p.join(tmp, 'missing.jsonl'),
      '',
    ]);
    expect(
      () => ResolveWizard(io).run(tmp),
      throwsA(isA<WizardException>()),
    );
  });
}

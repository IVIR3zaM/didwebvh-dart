import 'dart:convert';
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
    dir = Directory.systemTemp.createTempSync('wizard_export_');
    tmp = dir.path;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes parallel did:web document for created DID', () async {
    final signer = await LocalKeySigner.generate();
    final created = await DidWebVh.create('example.com', signer).execute();
    WizardFiles.write(p.join(tmp, WizardFiles.didLog), created.logLine);

    final io = ScriptedWizardIo(['']); // accept default filename
    await ExportDidWebWizard(io).run(tmp);

    final outPath = p.join(tmp, ExportDidWebWizard.defaultOutput);
    expect(File(outPath).existsSync(), isTrue);

    final doc =
        (jsonDecode(WizardFiles.read(outPath)) as Map).cast<String, Object?>();
    expect(doc['id']! as String, startsWith('did:web:example.com'));
    final aka = (doc['alsoKnownAs']! as List).cast<Object?>();
    expect(aka.contains(created.did), isTrue);
  });

  test('errors when no log in directory', () async {
    final io = ScriptedWizardIo();
    expect(
      () => ExportDidWebWizard(io).run(tmp),
      throwsA(
        isA<WizardException>()
            .having((e) => e.message, 'message', contains(WizardFiles.didLog)),
      ),
    );
  });
}

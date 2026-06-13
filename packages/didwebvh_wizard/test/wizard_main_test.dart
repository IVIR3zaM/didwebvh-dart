import 'dart:io';

import 'package:didwebvh_wizard/didwebvh_wizard.dart';
import 'package:didwebvh_wizard/src/wizard_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/scripted_wizard_io.dart';

void main() {
  late Directory dir;
  late String tmp;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wizard_main_');
    tmp = dir.path;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('menu dispatches to create and exits', () async {
    final io = ScriptedWizardIo([
      '1', // menu: create
      'example.com', // domain
      '', // path
      '1', // generate key
      '', // alsoKnownAs
      '', // controllers
      '', // services
      'n', // portable
      'n', // pre-rotation
      'n', // witnesses
      '', // watchers
      '', // ttl default
      '5', // menu: exit
    ]);
    final main = WizardMain(workDir: tmp);
    expect(await main.run(io), 0);
    expect(File(p.join(tmp, WizardFiles.didLog)).existsSync(), isTrue);
  });

  test('action mode runs single action', () async {
    final io = ScriptedWizardIo([
      'example.com',
      '',
      '1',
      '',
      '',
      '',
      'n',
      'n',
      'n',
      '',
      '',
    ]);
    final main = WizardMain(workDir: tmp, action: 'create');
    expect(await main.run(io), 0);
    expect(File(p.join(tmp, WizardFiles.didLog)).existsSync(), isTrue);
  });
}

import 'dart:io';

import 'package:args/args.dart';
import 'package:didwebvh_wizard/didwebvh_wizard.dart';

/// Executable entry point for the did:webvh wizard.
///
/// Faithful port of Java `WizardMain.main`: a single command with `--dir` and
/// `--action` options plus standard `--help` / `--version` flags. The
/// menu/action flow lives in [WizardMain] so it can be driven by a scripted
/// `WizardIo` in tests.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'dir',
      abbr: 'd',
      defaultsTo: '.',
      help: 'Working directory for DID files (default: current directory).',
    )
    ..addOption(
      'action',
      abbr: 'a',
      help: 'Skip the main menu and run a single action: '
          'create | update | resolve | export.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Show version information.',
    );

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    exit(64);
  }

  if (args.flag('help')) {
    stdout
      ..writeln(
        'Interactive wizard for creating, updating, and resolving '
        'did:webvh DIDs.',
      )
      ..writeln()
      ..writeln(parser.usage);
    return;
  }
  if (args.flag('version')) {
    stdout.writeln('didwebvh-wizard 0.1.0');
    return;
  }

  final main = WizardMain(
    workDir: args.option('dir') ?? '.',
    action: args.option('action'),
  );
  final code = await main.run(ConsoleWizardIo());
  exit(code);
}

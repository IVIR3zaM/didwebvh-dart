import 'dart:io';

import 'package:didwebvh_wizard/src/create_wizard.dart';
import 'package:didwebvh_wizard/src/export_did_web_wizard.dart';
import 'package:didwebvh_wizard/src/resolve_wizard.dart';
import 'package:didwebvh_wizard/src/update_wizard.dart';
import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';
import 'package:didwebvh_wizard/src/wizard_prompts.dart';
import 'package:path/path.dart' as p;

/// Command-line entry point logic for the did:webvh interactive wizard.
///
/// Faithful port of Java `WizardMain` (the picocli command). Argument parsing
/// lives in `bin/didwebvh_wizard.dart`; this class holds the menu/action flow
/// so it can be driven by a scripted [WizardIo] in tests, exactly like the Java
/// package-private `run(WizardIo)` seam.
final class WizardMain {
  /// Creates the wizard entry point.
  ///
  /// [workDir] is the working directory for DID files (default: current
  /// directory). When [action] is non-null the main menu is skipped and a
  /// single action is run (`create` | `update` | `resolve` | `export`).
  WizardMain({this.workDir = '.', this.action});

  /// Working directory for DID files.
  final String workDir;

  /// A single action to run, skipping the menu, or `null` to show the menu.
  final String? action;

  /// Entry point used by tests and the executable.
  Future<int> run(WizardIo io) async {
    try {
      _ensureWorkDir();
      final action = this.action;
      if (action != null) {
        return await _runAction(io, action);
      }
      return await _runMenu(io);
    } on WizardException catch (e) {
      io.printError('Error: ${e.message}');
      return 1;
    }
  }

  Future<int> _runMenu(WizardIo io) async {
    final ask = WizardPrompts(io);
    while (true) {
      io
        ..println('')
        ..println('=== did:webvh Wizard ===')
        ..println('Working directory: ${p.absolute(workDir)}')
        ..println('  1. Create a new DID')
        ..println('  2. Update an existing DID')
        ..println('  3. Resolve a DID')
        ..println('  4. Export parallel did:web document')
        ..println('  5. Exit');
      final choice = ask.askChoice('Choose 1-5: ', 5);
      if (choice == 5) {
        io.println('Goodbye.');
        return 0;
      }
      try {
        await _runAction(io, _actionForChoice(choice));
      } on WizardException catch (e) {
        io.printError('Error: ${e.message}');
      }
    }
  }

  Future<int> _runAction(WizardIo io, String name) async {
    switch (name.toLowerCase()) {
      case 'create':
        await CreateWizard(io).run(workDir);
        return 0;
      case 'update':
        await UpdateWizard(io).run(workDir);
        return 0;
      case 'resolve':
        await ResolveWizard(io).run(workDir);
        return 0;
      case 'export':
        await ExportDidWebWizard(io).run(workDir);
        return 0;
      default:
        throw WizardException(
          'Unknown action: $name '
          '(expected create | update | resolve | export)',
        );
    }
  }

  static String _actionForChoice(int choice) {
    switch (choice) {
      case 1:
        return 'create';
      case 2:
        return 'update';
      case 3:
        return 'resolve';
      case 4:
        return 'export';
      default:
        throw WizardException('Unknown menu choice: $choice');
    }
  }

  void _ensureWorkDir() {
    final dir = Directory(workDir);
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } on Object catch (e) {
      throw WizardException(
        'Could not create working directory $workDir: $e',
        e,
      );
    }
  }
}

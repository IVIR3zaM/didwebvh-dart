import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';

/// Prompt helpers shared by all wizards.
///
/// Faithful port of Java `WizardPrompts`.
class WizardPrompts {
  /// Creates prompt helpers over the given [io].
  WizardPrompts(this.io);

  /// The I/O channel used for prompting.
  final WizardIo io;

  /// Read a required non-empty string; keeps asking until one is provided.
  String askRequired(String prompt) {
    while (true) {
      final line = io.readLine(prompt);
      if (line == null) {
        throw WizardException('Input ended while expecting a value');
      }
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
      io.printError('A value is required.');
    }
  }

  /// Read an optional string (empty input returns [defaultValue], which may be
  /// null).
  String? askOptional(String prompt, String? defaultValue) {
    final line = io.readLine(prompt);
    if (line == null) {
      return defaultValue;
    }
    final trimmed = line.trim();
    return trimmed.isEmpty ? defaultValue : trimmed;
  }

  /// Ask a yes/no question. Defaults to [defaultValue] on empty input.
  bool askYesNo(String prompt, {required bool defaultValue}) {
    final suffix = defaultValue ? ' [Y/n]: ' : ' [y/N]: ';
    while (true) {
      final line = io.readLine(prompt + suffix);
      if (line == null) {
        return defaultValue;
      }
      final trimmed = line.trim().toLowerCase();
      if (trimmed.isEmpty) {
        return defaultValue;
      }
      if (trimmed == 'y' || trimmed == 'yes') {
        return true;
      }
      if (trimmed == 'n' || trimmed == 'no') {
        return false;
      }
      io.printError("Please answer 'y' or 'n'.");
    }
  }

  /// Ask for an integer; empty returns [defaultValue] if non-null, otherwise
  /// re-asks.
  int askInt(String prompt, int? defaultValue) {
    while (true) {
      final line = io.readLine(prompt);
      if (line == null) {
        if (defaultValue != null) {
          return defaultValue;
        }
        throw WizardException('Input ended while expecting an integer');
      }
      final trimmed = line.trim();
      if (trimmed.isEmpty && defaultValue != null) {
        return defaultValue;
      }
      final value = int.tryParse(trimmed);
      if (value != null) {
        return value;
      }
      io.printError("Not a valid integer: '$trimmed'");
    }
  }

  /// Ask for a menu choice between 1 and [max]; re-prompts on invalid input.
  int askChoice(String prompt, int max) {
    while (true) {
      final value = askInt(prompt, null);
      if (value >= 1 && value <= max) {
        return value;
      }
      io.printError('Choice must be between 1 and $max.');
    }
  }
}

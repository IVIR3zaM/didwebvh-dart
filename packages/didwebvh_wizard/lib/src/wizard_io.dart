import 'package:didwebvh_wizard/didwebvh_wizard.dart' show ConsoleWizardIo;
import 'package:didwebvh_wizard/src/console_wizard_io.dart'
    show ConsoleWizardIo;

/// Terminal I/O abstraction for the wizard. A [ConsoleWizardIo] backs the
/// interactive run; tests supply a scripted implementation.
///
/// Faithful port of Java `WizardIo`.
abstract interface class WizardIo {
  /// Prints [prompt] (no trailing newline added) and reads one line from the
  /// user. Returns `null` if input is exhausted.
  String? readLine(String? prompt);

  /// Prints a line of output.
  void println(String message);

  /// Prints a line of error output.
  void printError(String message);
}

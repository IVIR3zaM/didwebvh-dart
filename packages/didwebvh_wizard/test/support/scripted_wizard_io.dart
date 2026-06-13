import 'dart:collection';

import 'package:didwebvh_wizard/didwebvh_wizard.dart';

/// Test [WizardIo] that replays pre-programmed answers and records output.
///
/// Faithful port of the Java test helper `ScriptedWizardIo`.
final class ScriptedWizardIo implements WizardIo {
  /// Creates a scripted I/O preloaded with [answers].
  ScriptedWizardIo([List<String> answers = const []]) {
    _inputs.addAll(answers);
  }

  final Queue<String> _inputs = ListQueue<String>();

  /// Everything printed via [readLine] prompts and [println], in order.
  final List<String> outputs = <String>[];

  /// Everything printed via [printError], in order.
  final List<String> errors = <String>[];

  /// Append more scripted [answers] to the input queue.
  void enqueue(List<String> answers) => _inputs.addAll(answers);

  @override
  String? readLine(String? prompt) {
    outputs.add('> ${prompt ?? ''}');
    if (_inputs.isEmpty) {
      return null;
    }
    final next = _inputs.removeFirst();
    outputs.add('< $next');
    return next;
  }

  @override
  void println(String message) => outputs.add(message);

  @override
  void printError(String message) => errors.add(message);

  /// All recorded output joined with newlines.
  String allOutput() => outputs.join('\n');

  /// The number of scripted answers not yet consumed.
  int get remainingInputs => _inputs.length;
}

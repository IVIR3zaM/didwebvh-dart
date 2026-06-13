import 'dart:convert';
import 'dart:io';

import 'package:didwebvh_wizard/src/wizard_exception.dart';
import 'package:didwebvh_wizard/src/wizard_io.dart';

/// Default [WizardIo] backed by [stdin] / [stdout].
///
/// Faithful port of Java `ConsoleWizardIo`.
final class ConsoleWizardIo implements WizardIo {
  /// Creates a console I/O over the given streams (defaults to the process
  /// standard streams). [input] is decoded as UTF-8 line-by-line.
  ConsoleWizardIo({Stdin? input, IOSink? out, IOSink? err})
      : _in = input ?? stdin,
        _out = out ?? stdout,
        _err = err ?? stderr;

  final Stdin _in;
  final IOSink _out;
  final IOSink _err;

  @override
  String? readLine(String? prompt) {
    if (prompt != null) {
      _out.write(prompt);
    }
    try {
      return _in.readLineSync(encoding: utf8);
    } on Object catch (e) {
      throw WizardException('Failed to read input: $e', e);
    }
  }

  @override
  void println(String message) => _out.writeln(message);

  @override
  void printError(String message) => _err.writeln(message);
}

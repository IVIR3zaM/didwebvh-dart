// Generates lib/src/version.g.dart from the package's pubspec.yaml so the wizard
// reports its version without hardcoding it. pubspec.yaml is not reliably
// available at runtime (compiled exe / global activate), so the version is
// baked into a committed Dart constant at build time instead.
//
// Run after bumping the version in pubspec.yaml:
//
//   dart run tool/generate_version.dart
//
// Zero dependencies: a single regex extracts the top-level `version:` field.
import 'dart:io';

void main() {
  final scriptDir = File.fromUri(Platform.script).parent.path;
  final packageRoot = Directory(scriptDir).parent.path;

  final pubspec = File('$packageRoot/pubspec.yaml').readAsStringSync();
  final match =
      RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(pubspec);
  if (match == null) {
    stderr.writeln('Could not find a top-level "version:" in pubspec.yaml');
    exit(1);
  }
  final version = match.group(1)!.trim();

  final out = File('$packageRoot/lib/src/version.g.dart')
    ..writeAsStringSync('''
// GENERATED CODE - DO NOT MODIFY BY HAND.
// Regenerate with: dart run tool/generate_version.dart
//
// Source of truth is the `version:` field in pubspec.yaml.

/// The published version of the didwebvh_wizard package.
const String packageVersion = '$version';
''',
    );

  stdout.writeln('Wrote ${out.path} (version $version)');
}

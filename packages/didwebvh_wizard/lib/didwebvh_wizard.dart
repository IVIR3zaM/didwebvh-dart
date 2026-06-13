/// did:webvh interactive CLI wizard — a faithful Dart port of didwebvh-java's
/// `didwebvh-wizard` module.
///
/// This barrel re-exports the wizard's public pieces; the executable entry
/// point lives in `bin/didwebvh_wizard.dart`. The package-private helpers
/// (`WizardPrompts`, `WizardFiles`, `WizardWitnessKeys`, `WizardWitnessProofs`)
/// stay under `lib/src/`, mirroring Java's package-private visibility.
library;

export 'src/console_wizard_io.dart';
export 'src/create_wizard.dart';
export 'src/export_did_web_wizard.dart';
export 'src/resolve_wizard.dart';
export 'src/update_wizard.dart';
export 'src/wizard_exception.dart';
export 'src/wizard_io.dart';
export 'src/wizard_main.dart';

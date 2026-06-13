# Iteration 13 — Wizard CLI

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`reference/didwebvh-java/didwebvh-wizard/` (`WizardIo`, Create/Update/Resolve/ExportDidWeb wizards, prompts,
files, witness keys/proofs).

### Produce (`packages/didwebvh_wizard/`)
- `bin/didwebvh_wizard.dart` entry using `package:args` `CommandRunner`/`Command`.
- `WizardIo` abstraction + `ConsoleWizardIo` (testable, mirrors Java); the wizard sub-flows.

### Test
Port wizard tests against a fake `WizardIo`. (Wizard is excluded from the coverage gate, as in Java.)

### Acceptance
- Wizard flows work against scripted IO; not published or published as a global-activate tool.

### Implementation Notes
- **All `run` methods are `async`.** Every operation the wizard drives (`LocalKeySigner.generate`,
  `CreateDidConfig.execute`, `DidWebVhState.validate`, `DidResolver.resolve*`, witness-proof signing) is a
  `Future` per the documented async-`Signer` delta, so `CreateWizard`/`UpdateWizard`/`ResolveWizard`/
  `ExportDidWebWizard`/`WizardMain` return `Future`. The `WizardIo` line API stays synchronous, matching Java.
- **Two new public core exports.** The wizard needs `Base58Btc.encodeMultibase` (witness signature encoding) and
  `PreRotationHashGenerator.generateHash` (pre-rotation commitment) — both public cross-module API in the Java
  `didwebvh-core` that the Java wizard imports. Added them to the `didwebvh_core` barrel so the wizard uses the
  public surface (no `implementation_imports` violation). `ProofGenerator`/`DataIntegrityProof`/`LogEntry`/
  `WitnessProofEntry`/`JsonModel` etc. were already exported. `JsonSupport` was **not** needed: Java's
  `JsonSupport.compact().fromJson(...,WitnessProofEntry[].class)` / `toJsonTree` round-trip is replaced by
  `dart:convert` + `WitnessProofEntry.fromJson` / `toJson(omitNull: true)`, producing the same bare-array
  `did-witness.json` bytes.
- **Paths as strings + `package:path`.** Java's `java.nio.file.Path` (`resolve`, `toAbsolutePath`) maps to
  plain `String` paths with `p.join` / `p.absolute`; file I/O uses `dart:io` `File`/`Directory`. `package:path`
  was added as the one new dependency.
- **Single command, not a CommandRunner tree.** The Java wizard is a single picocli command with a `--action`
  option (not subcommands), so `bin/didwebvh_wizard.dart` uses a plain `ArgParser` (`--dir`/`--action` +
  `--help`/`--version`) rather than `args`' `CommandRunner`/`Command`. This is the faithful structure; the
  decisions-§2 "CommandRunner" note describes the *family* of arg tooling, and the menu/action flow lives in
  `WizardMain.run(WizardIo)` exactly like Java's package-private test seam.
- **Idiomatic Dart deltas (decisions §8).** `WizardException` is a sibling `Exception` (not a subclass of the
  core `DidWebVhException`), matching Java where both extend `RuntimeException` independently — so
  `ResolveWizard`'s `on DidWebVhException` catch does not swallow a "file not found" `WizardException` (the
  `reportsErrorWhenFileMissing` test depends on it propagating). Boolean checks use `?? false` instead of
  `== true`/`Boolean.TRUE.equals`; the `Operation` dispatch uses an `await switch` expression; consecutive
  console `println`s are written as cascades (`io..println()..println()`) to satisfy `cascade_invocations`.
- **No new core logic**, so `didwebvh_core` coverage is unchanged (the two added barrel lines re-export
  already-covered code). The wizard package is excluded from the coverage gate (thin adapter, decisions §5).
- **Gate:** `dart pub get && dart analyze --fatal-infos && dart test` (via `tool/verify.sh`) → `VERIFY OK`; the
  five ported wizard suites and all pre-existing package tests pass.

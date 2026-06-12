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

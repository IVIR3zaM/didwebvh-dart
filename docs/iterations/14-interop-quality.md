# Iteration 14 — Interop & spec-compliance pass + quality finalization

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
Java CI quality contract (decisions §5); `README.md`, `CHANGELOG.md`, publishing flow.

### Produce
- Confirm **every** vendored vector (`test-vectors/` + `interop/`) passes — the single objective signal that
  the port is "fully spec-aligned".
- Coverage ≥ 80% on `didwebvh_core` (Codecov gate). Finalize `README.md`, examples, and `publish.yml`.

### Acceptance
- All shared vectors green; coverage gate met; docs and publish workflow complete.

### Implementation Notes

- **Gate is green.** `tool/verify.sh --coverage` ends in `VERIFY OK`: `dart analyze --fatal-infos` reports
  *no issues*; all package suites pass (`didwebvh_core` 355, `didwebvh_signing_local` 9, `didwebvh_wizard` 24).
  Every vendored cross-language vector (`test-vectors/` + `interop/`) passes — the single objective "fully
  spec-aligned" signal.
- **Coverage met.** `didwebvh_core` line coverage is **94.89%** (1652 / 1741), comfortably above the 80%
  Codecov gate. `didwebvh_signing_local` and `didwebvh_wizard` are thin adapters and stay off the gate
  (decisions §5).
- **All three packages made publishable for v0.1.0** (a deliberate drift from Java: the wizard is now published
  too, so it installs via `dart pub global activate`). Removed `publish_to: none`; replaced sibling `path:`
  dependencies with hosted version constraints (`didwebvh_core: ^0.1.0`, …) — the pub workspace still resolves
  them locally for dev. Added `LICENSE` (Apache-2.0) to each package, per-package `README.md` + `CHANGELOG.md`,
  `topics`/`issue_tracker` metadata, and an `executables:` entry for the wizard. `dart pub publish --dry-run`
  passes for all three (only the expected "uncommitted changes" warning). `publish.yml` now also triggers on
  `didwebvh_wizard-v*` tags.
- **Examples** for the two library packages:
  - `packages/didwebvh_core/example/didwebvh_core_example.dart` — full **create → resolve → update** lifecycle
    using a minimal inline Ed25519 `Signer` (core defines `Signer` but ships no key impl; the inline signer keeps
    the example self-contained and demonstrates the bring-your-own-signer extension point).
  - `packages/didwebvh_signing_local/example/didwebvh_signing_local_example.dart` — full
    create → sign → resolve round-trip with `LocalKeySigner`.
  - Both run cleanly; `// ignore_for_file: avoid_print` keeps the print-based examples within `--fatal-infos`.
- **Docs finalized for publish.** Root `README.md` drops the "porting in progress" status block (the port is
  done) and keeps a single line noting it is a faithful, Dart-idiomatic port of Java; the wizard section now uses
  `dart pub global activate`; the `LocalKeySigner.generate()` snippets are now `await`ed (the API is async).
  Root `CHANGELOG.md` collapsed the per-iteration `[Unreleased]` log into a compressed `[0.1.0]` release, all
  under **Added** (Changed/Fixed make no sense for a first publish).
- **Cleanup.** Removed the now-redundant `.gitkeep` files from populated `lib/src/` dirs; moved `PROMPT.md` to
  `docs/PROMPT.md`; replaced the Java-specific `./mvnw` commands in the two vendored vector `README.md` files
  with the Dart gate (`tool/verify.sh`) and corrected their stale Java test-path references.
- **No behavioural code change vs. Java/spec.** This iteration proves alignment (vectors + coverage) and
  finalizes the consumer-facing surface and packaging only.

### Action required before publishing (human / pub.dev)

Step-by-step instructions (including creating a pub.dev account from scratch, the first manual publish in
dependency order, and enabling tag-triggered OIDC publishing) live in [`../PUBLISHING.md`](../PUBLISHING.md).
In short: publish **core → signing_local → wizard** manually for v0.1.0, then enable automated publishing on each
package's Admin page; no repository secrets are needed.

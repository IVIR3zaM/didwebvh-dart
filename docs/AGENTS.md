# Agent and Contributor Guide — didwebvh-dart

Instructions for AI agents and human contributors working on `didwebvh-dart`, a **faithful Dart port** of
[`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java).

## Project Overview

`didwebvh-dart` is a pure-Dart (no Flutter) implementation of the
[did:webvh v1.0 specification](https://identity.foundation/didwebvh/v1.0/): create, resolve, update, migrate,
and deactivate `did:webvh` DIDs, with pluggable key management. It is a port of the Java reference library and
must behave **identically** to it. It is organized as a Dart **pub workspace** monorepo (Dart 3.6+).

## Start here

1. [`PORTING-GUIDE.md`](PORTING-GUIDE.md) — how the port works and the human-review rule (read first).
2. [`PORTING-DECISIONS.md`](PORTING-DECISIONS.md) — the locked technical decisions and the Java→Dart mapping.
3. [`PORTING-STATUS.md`](PORTING-STATUS.md) — tiny iteration index; pick the next one. Full detail per
   iteration is in [`iterations/`](iterations/) — read only the one you're working on.
4. [`ARCHITECTURE.md`](ARCHITECTURE.md) — language-neutral design + spec algorithms (from the Java reference).
5. [`PROMPT.md`](PROMPT.md) — the ready-to-paste prompt that runs the next iteration.

The Java source lives, git-ignored, in `reference/didwebvh-java/` (see `../reference/README.md`). The spec TXT
is at `docs/spec/Webvh v1.0.txt`.

## Guiding Principles (inherited from the Java project)

1. **Identical observable behaviour to Java.** This is a translation. Read the Java source for any behaviour
   question; don't redesign while porting. The shared cross-language test vectors — not Java's *internal*
   implementation shape — are the contract: any code path must produce the **same bytes / same outcomes** as the
   vectors. Mirroring *how* Java does something internally (e.g. its JSON round-trips) is not itself a goal.
2. **Idiomatic Dart first.** When a faithful port and idiomatic Dart pull in different directions, prefer
   idiomatic Dart, provided the vectors still pass byte-for-byte. The priority order is: **(1)** Dart best
   practices, then **(2)** matching Java's exact internal approach. These almost never conflict — but when they
   do, choose Dart and document the divergence in `PORTING-DECISIONS.md`. The interop vectors are above both and
   are never traded away. (First applied: `Jcs.canonicalizeValue` canonicalizes a decoded value directly instead
   of replaying Java's encode→parse round-trip — see PORTING-DECISIONS.md §8.)
3. **Simplicity over abstraction.** A reader should understand the code without tracing many layers. Patterns
   only when they earn their keep (the `Signer` adapter is the canonical example).
4. **SOLID, not academic.** No interfaces for single implementations beyond the documented extension points.
5. **Spec fidelity.** `docs/spec/Webvh v1.0.txt` is the ultimate source of truth; reference section numbers in
   comments for non-obvious logic.
6. **Test-driven.** Every public method has tests; spec logic is gated on the shared vectors.

## Key Technical Decisions (summary — full detail in `PORTING-DECISIONS.md`)

- **Build/monorepo:** pub workspaces (Dart 3.6+), no Melos. Root `pubspec.yaml` with `workspace:` list.
- **Packages:** `didwebvh`, `didwebvh_signing_local`, `didwebvh_wizard`.
- **Crypto:** `cryptography` (Ed25519; `DartEd25519` for in-core verification — its `verify` is async-only, so
  proof verification returns `Future<bool>`), `crypto` (SHA-256). JCS, multihash, base58btc, multikey are
  **ported internally** (byte-exact).
- **Do NOT use** the pub.dev `canonical_json` package — it is OLPC, not RFC 8785, and breaks interop.
- **JCS API:** `Jcs.canonicalizeValue(Object?)` is the primary entry point — it canonicalizes an already-decoded
  JSON value directly (the shape did:webvh code actually holds). `Jcs.canonicalize(String)` is the convenience for
  text-only inputs (the SCID `{SCID}` string-replace step) and just decodes then delegates. This intentionally
  drops Java's encode→parse round-trip; output is byte-identical (see PORTING-DECISIONS.md §8).
- **JSON:** `dart:convert` + hand-written `toJson`/`fromJson`; precise null-omit control for canonical lines.
  No codegen / `build_runner`.
- **Config-builder call styles (library-wide):** every configurable operation builder (`CreateDidConfig`, and
  by the same decision the future `UpdateDidConfig` / `MigrateDidConfig` / `DeactivateDidConfig`) supports **three
  interchangeable call styles** — (1) **fluent** chaining (faithful to the Java builder; setters `return this`),
  (2) **cascade** (`..`, free since `..` ignores the return value), and (3) **named parameters** at construction
  (a delegating constructor that applies each non-null argument through its like-named setter — one source of
  truth for copy/normalization; also forwarded through the `DidWebVh.*` facade). Keeping the fluent style requires
  setters that `return this` and a positional boolean toggle (e.g. `portable(true)`), so `avoid_returning_this`
  and `avoid_positional_boolean_parameters` are suppressed **scoped to that builder's `lib/src/<op>/` directory
  only** (same narrow-scoping as the `model/` and `witness/` equality exemptions). `avoid_positional_boolean_parameters`
  is a recognized false-positive for a single, well-named boolean setter; the alternatives each cost something
  (drop the fluent style, lose explicit `false`, or mix styles). Value-type configs that are **not** builders
  (e.g. `ResolveOptions`) stay plain named-parameter value types — do not add builder machinery for symmetry.
  Document the styles **once** as a library-wide convention (README Usage preamble + one worked example), never
  per-method. (Decided in iteration 6; see `docs/iterations/06-create.md` and `PORTING-DECISIONS.md` §8.)
- **HTTP:** `package:http` behind a `RemoteDidFetcher` (10s timeout, 200KB cap, as in Java).
- **CLI:** `package:args` (`CommandRunner`); `WizardIo` abstraction for testable prompts.
- **Tests:** `package:test` + `mocktail` + `http`'s `MockClient`. Lint: `very_good_analysis`.
- **The intentional delta from Java:** the `Signer` is **async** (`Future<Uint8List> sign(...)`), which ripples
  into `Future`-returning create/update operations. Proof *verification* is **also async** (`Future<bool>`) — not
  by design but because `cryptography`'s `DartEd25519.verify` is async-only (see PORTING-DECISIONS.md §2,
  corrected in iteration 4); this in turn makes the log-chain validation loop async.

### The `Signer` interface (async)

```dart
abstract interface class Signer {
  String get keyType;             // "Ed25519"
  String get verificationMethod;  // "did:key:z6Mk...#z6Mk..."
  Future<Uint8List> sign(Uint8List data);
}
```

This is the primary extension point: local Ed25519 keys (`didwebvh_signing_local`), AWS KMS, external signing
services, HSMs.

## Coding Standards

- **`snake_case`** file and package names; **PascalCase** class names (unchanged from Java).
- **Package-private by default:** implementation in `lib/src/`; only `lib/<pkg>.dart` re-exports the public
  API (the analog of Java's package-private discipline).
- **Doc comments** (`///`) on public classes and methods.
- **Immutable models** where practical; factory/builder construction.
- **Null-safety** throughout; be explicit about nullable fields, especially where JSON null-omission matters.
- **No wildcard re-exports** beyond the intended public surface.
- Pass `dart analyze` with zero issues under `very_good_analysis`.

## Testing Standards

- **`package:test`** for all tests; `mocktail` for mocks; `MockClient` for HTTP.
- **Shared vectors** in `packages/didwebvh/test/vectors/` (`test-vectors/` + `interop/`) are copied
  verbatim from Java and are the cross-language interop contract. Never edit them.
- Unit tests per public class; end-to-end tests for create → update → resolve → validate.
- **The gate (run after _every_ change): [`tool/verify.sh`](../tool/verify.sh).** This is the single
  source of truth that nothing is broken — the Dart analog of Java's `./mvnw clean verify`. It runs
  `dart pub get`, workspace-wide `dart analyze --fatal-infos`, and `dart test` for **every** package that has a
  `test/` dir (running `dart test` from the workspace root only prints help, so never rely on that). Pass
  `tool/verify.sh --coverage` to also emit `packages/didwebvh/coverage/lcov.info`. Report its real result
  (`VERIFY OK` / `VERIFY FAILED`, with output). Do not hand-roll the individual commands — use the script so new
  test folders are always included.
- Coverage ≥ 80% on `didwebvh` (Codecov); `signing_local` and `wizard` excluded, as in Java.

## CI/CD

- **ci.yml:** on push to `main` and all PRs; SDK matrix (stable / declared minimum / beta); runs the same gate
  as `tool/verify.sh` (`dart analyze` + `dart test --coverage`) → Codecov.
- **publish.yml:** tag-triggered, pub.dev automated publishing via GitHub Actions OIDC (no GPG). After all three
  packages publish, a `github_release` job creates the GitHub Release, using the matching root-`CHANGELOG.md`
  section (extracted by [`tool/changelog-extract.sh`](../tool/changelog-extract.sh)) as the release notes —
  mirroring the didwebvh-java reference, which derives its release body from the changelog.

## Versioning & Changelogs

- **Lockstep versioning.** All three packages share one version and bump together; inter-package constraints use
  `^<that version>`. Never bump one package alone.
- **Bump with the wizard.** Run [`tool/bump-version.sh`](../tool/bump-version.sh) — an interactive tool that
  updates every `pubspec.yaml` `version:`, the inter-package `^` constraints, the README install snippet, the
  generated `version.g.dart`, and every CHANGELOG (promoting `Unreleased` → the new dated version and adding a
  fresh empty `Unreleased`). It asks patch/minor/major or an explicit version, always confirms, and
  double-confirms downgrades. Don't hand-edit versions across files.
- **Two changelog styles, by design:**
  - **Root `CHANGELOG.md`** follows [Keep a Changelog](https://keepachangelog.com/): `## [Unreleased]` and
    `## [X.Y.Z] - DATE`, with `Added` / `Changed` / `Fixed` groupings. This is the project-level log and the
    source of GitHub release notes.
  - **Per-package `CHANGELOG.md`** uses the plain Dart-idiomatic style that `dart create` emits and pub.dev
    expects: `## Unreleased` and `## X.Y.Z - DATE`, with a simple bullet list.
  - pub.dev accepts either style; the split keeps each package's log conventional while the root stays a richer
    Keep a Changelog. [`tool/changelog-extract.sh`](../tool/changelog-extract.sh) understands both.
- **The wizard's version** is read from its `pubspec.yaml` via the generated `lib/src/version.g.dart` (regenerate
  with `dart run tool/generate_version.dart`); `tool/verify.sh` fails if that file is stale.

## Commit & Review Workflow (hard rule)

After completing any change, the agent MUST:

1. **Run the gate [`tool/verify.sh`](../tool/verify.sh)** and confirm `VERIFY OK` (report the real output if it
   fails). This is the mandatory end-of-change check that nothing is broken.
2. **Update the changelog(s)** — the root `CHANGELOG.md` under `## [Unreleased]` (Added / Changed / Fixed), and
   any affected package's `CHANGELOG.md` under its plain `## Unreleased` bullet list — referencing the spec
   section or the ported Java class for non-obvious behaviour. See **Versioning & Changelogs** above.
3. **Propose** a [Conventional Commits](https://www.conventionalcommits.org/) message — and **stop**.

**Nothing is committed without a human review, and the agent never commits on the human's behalf.** The agent
leaves the iteration `[~]`; the human reviews against the Java reference, commits, flips the iteration to
`[x]`, and records the commit in the Progress log. See `PORTING-GUIDE.md`.

## How to Work on This Project

1. Read `PORTING-GUIDE.md`, then `PORTING-DECISIONS.md`.
2. Ensure `reference/didwebvh-java/` is present (`../reference/README.md`).
3. Open `PORTING-STATUS.md`, take the first `[ ]` iteration (only one in flight); read its
   `iterations/NN-*.md` detail file.
4. Port faithfully from the Java reference; read the Java source for any behaviour question.
5. Run the gate (`tool/verify.sh`); report the real result; copy the shared vectors where the iteration calls
   for it.
6. Update the changelog, propose a commit message, and stop for human review.

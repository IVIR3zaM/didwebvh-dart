# Iteration 0 — Repository scaffolding

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
apply only deltas in [`../PORTING-DECISIONS.md`](../PORTING-DECISIONS.md). Stop for human review; never commit.

### Reference
`reference/didwebvh-java/pom.xml`, child `pom.xml` files, `.github/workflows/ci.yml`, `codecov.yml`,
`.gitignore`, `LICENSE`; decisions §2–§5.

### Produce
- Pub-workspace root `pubspec.yaml` (`workspace:` list, `environment: sdk: '^3.6.0'`).
- `packages/didwebvh/`, `packages/didwebvh_signing_local/`, `packages/didwebvh_wizard/` with their own
  `pubspec.yaml`, public barrel `lib/<pkg>.dart`, and `lib/src/` tree (decisions §4). Pin **`sdk: '^3.6.0'` on
  every package** — same floor as the workspace, matching Affinidi `ssi` (decisions §3).
- `analysis_options.yaml` including `very_good_analysis`.
- `.github/workflows/ci.yml` (`dart analyze` + `dart test --coverage` + Codecov; SDK matrix stable / 3.6.0 /
  beta) and `publish.yml` (tag-triggered, pub.dev OIDC).
- `codecov.yml` (80% project + patch; gate scoped to `didwebvh`).
- `.gitignore` (Dart + `reference/`), `LICENSE` (already vendored), `CHANGELOG.md`, `CONTRIBUTING.md`,
  `README.md`, `SECURITY.md`.

### Acceptance
- `dart pub get` resolves the workspace; `dart analyze` and `dart test` succeed on empty packages.
- CI workflows are valid YAML. `reference/` is git-ignored.

### Implementation Notes
- **Top-level files already present** in the repo seed (`.gitignore`, `LICENSE`, `CHANGELOG.md`,
  `CONTRIBUTING.md`, `README.md`, `SECURITY.md`) were left as-is; `.gitignore` already ignores
  `reference/didwebvh-java/`, `.dart_tool/`, `coverage/`, and `pubspec.lock` (library convention).
- **Workspace root** `pubspec.yaml`: `publish_to: none` private package `_didwebvh_workspace`, `sdk: '^3.6.0'`,
  `workspace:` lists the three packages. Each package pins `sdk: '^3.6.0'` and declares `resolution: workspace`.
- **Dependencies** seeded from decisions §2 so later iterations have them: core → `crypto`, `cryptography`,
  `http` (dev: `test`, `mocktail`, `very_good_analysis`); `signing_local` → `cryptography` + path dep on core;
  `wizard` → `args` + path deps on core & signing_local. `bs58` deliberately omitted (decisions §2 lean toward an
  internal `Base58Btc` port). `pubspec.lock` is git-ignored, so resolved versions are not pinned in VCS.
- **`lib/src/` trees** created with the §4 subdirectory layout; empty dirs hold a `.gitkeep` (git ignores empty
  dirs). `test/vectors/` placeholder added to core (vectors land in iteration 1). Barrels currently export nothing
  but the `library;` directive — public surface grows per iteration.
- **Smoke test**: `test/didwebvh_test.dart` does not import the (empty) barrel to avoid an `unused_import`
  lint; it just asserts the package builds so `dart test` has a green target.
- **CI**: matrix `3.6.0` / `stable` / `beta` (analog of Java 11/17/21/25); runs `dart analyze --fatal-infos` and
  `dart test --coverage` in `packages/didwebvh`, uploads lcov to Codecov on the `stable` leg only.
- **publish.yml**: tag-triggered pub.dev OIDC (`id-token: write`); per-package tag pattern
  `didwebvh-vX.Y.Z` / `didwebvh_signing_local-vX.Y.Z` (wizard not published). Replaces Maven Central + GPG.
- **`tool/verify.sh`** — one-shot gate mirroring Java's `./mvnw clean verify`. `dart test` is per-package in a
  pub workspace (running it from the root only prints help, since the root package has no `test/` dir), so the
  script discovers every `packages/*/` that has a `test/` dir and runs each suite, then reports pass/fail. With
  `--coverage` it collects coverage for `didwebvh` and writes `coverage/lcov.info`. Coverage formatting uses
  `format_coverage --package=.` (the deprecated `--packages=<package_config>.json` form is now rejected by the
  current `coverage` package); the CI workflow was updated to match. Note: until `lib/` has executable code the
  emitted `lcov.info` is empty (0 bytes) — expected for the scaffold; `coverage/` is git-ignored.
- **Gate (local, Dart 3.11.5)**: `dart pub get` ✓ resolved 52 deps · `dart analyze --fatal-infos` ✓ "No issues
  found!" · `dart test` (core) ✓ 1 passed · `tool/verify.sh` ✓ "VERIFY OK". The two "newer versions incompatible"
  notes are `package_config`/`very_good_analysis` majors held back by `test`'s constraints — expected, not
  failures.

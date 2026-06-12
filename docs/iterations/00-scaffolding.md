# Iteration 0 — Repository scaffolding

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
apply only deltas in [`../PORTING-DECISIONS.md`](../PORTING-DECISIONS.md). Stop for human review; never commit.

### Reference
`reference/didwebvh-java/pom.xml`, child `pom.xml` files, `.github/workflows/ci.yml`, `codecov.yml`,
`.gitignore`, `LICENSE`; decisions §2–§5.

### Produce
- Pub-workspace root `pubspec.yaml` (`workspace:` list, `environment: sdk: '^3.6.0'`).
- `packages/didwebvh_core/`, `packages/didwebvh_signing_local/`, `packages/didwebvh_wizard/` with their own
  `pubspec.yaml`, public barrel `lib/<pkg>.dart`, and `lib/src/` tree (decisions §4). Pin **`sdk: '^3.6.0'` on
  every package** — same floor as the workspace, matching Affinidi `ssi` (decisions §3).
- `analysis_options.yaml` including `very_good_analysis`.
- `.github/workflows/ci.yml` (`dart analyze` + `dart test --coverage` + Codecov; SDK matrix stable / 3.6.0 /
  beta) and `publish.yml` (tag-triggered, pub.dev OIDC).
- `codecov.yml` (80% project + patch; gate scoped to `didwebvh_core`).
- `.gitignore` (Dart + `reference/`), `LICENSE` (already vendored), `CHANGELOG.md`, `CONTRIBUTING.md`,
  `README.md`, `SECURITY.md`.

### Acceptance
- `dart pub get` resolves the workspace; `dart analyze` and `dart test` succeed on empty packages.
- CI workflows are valid YAML. `reference/` is git-ignored.

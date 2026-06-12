# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Port note.** `didwebvh-dart` is a faithful port of
> [`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java). Record the pinned Java
> tag/commit each iteration is ported against (see the Progress log in `docs/PORTING-STATUS.md`).

## [Unreleased]

### Added
- Repository seed: porting docs (`docs/AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/PORTING-DECISIONS.md`,
  `docs/PORTING-GUIDE.md`, `docs/PORTING-STATUS.md` + `docs/iterations/`), `PROMPT.md`, and the Java-reference setup
  (`reference/README.md`).
- Iteration 0 — repository scaffolding: pub-workspace root `pubspec.yaml` (`workspace:` list, `sdk: '^3.6.0'`),
  the three packages `didwebvh_core`, `didwebvh_signing_local`, `didwebvh_wizard` (each with its own `pubspec.yaml`,
  public barrel, and `lib/src/` tree per decisions §4), `analysis_options.yaml` (`very_good_analysis`),
  `codecov.yml` (80% project + patch, gate scoped to `didwebvh_core`), and the
  `.github/workflows/ci.yml` (Dart SDK matrix `3.6.0` / `stable` / `beta`) and `publish.yml` (tag-triggered
  pub.dev OIDC) workflows.
- Iteration 1 — vendored the shared cross-language test vectors: the 26 files under
  `test-vectors/` and `interop/` copied **verbatim** (byte-for-byte; SHA-256 verified) from the Java reference
  (`didwebvh-core/src/test/resources/`) into `packages/didwebvh_core/test/vectors/`. These bytes are the
  cross-implementation interop contract and are never edited. Added a `TestVectors` load helper
  (`test/support/test_vectors.dart`, mirroring Java's `TestVectors.readResource`) and a presence/loadability test.
- `tool/verify.sh` — one-shot quality gate (`dart pub get` + workspace `dart analyze --fatal-infos` + `dart test`
  for every package with a `test/` dir), the Dart analog of the Java project's `./mvnw clean verify`. Pass
  `--coverage` to also emit `packages/didwebvh_core/coverage/lcov.info`. Established as the canonical
  end-of-change gate in the agent docs (`docs/AGENTS.md`, `docs/PORTING-GUIDE.md`, `PROMPT.md`).

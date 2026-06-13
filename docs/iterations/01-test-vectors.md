# Iteration 1 — Vendor the shared test vectors & spec

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`.
Stop for human review; never commit.

### Reference
`reference/didwebvh-java/didwebvh-core/src/test/resources/` (`test-vectors/`, `interop/`).

### Produce
- Copy **verbatim** into `packages/didwebvh/test/vectors/` (keep `test-vectors/` and `interop/` subdirs,
  including the JSONL/JSON files and their `README.md`s). These bytes are the cross-language interop contract —
  do not regenerate or reformat them.
- A small Dart test helper to load vector files by path.

### Acceptance
- Vector files present and loadable in a trivial Dart test; checksums match the Java copies.

### Implementation Notes
- Copied all **26** files verbatim from `reference/didwebvh-java/didwebvh-core/src/test/resources/`
  (`test-vectors/` 8 files + `interop/` 18 files, including the two `README.md`s) into
  `packages/didwebvh/test/vectors/`. SHA-256 of every copied file matches the Java source (verified by
  diffing checksum lists — all match). Removed the placeholder `.gitkeep`.
- Load helper `test/support/test_vectors.dart` (`TestVectors` class) mirrors Java's
  `TestVectors.readResource`: `readVector(relativePath)` reads UTF-8 contents relative to `test/vectors/`,
  throwing `StateError` for a missing vector. `vectorsDir()` resolves the directory whether `dart test` runs
  from the package root or the repo root. The Java helper's seeded-signer / `parseLog` factory bits were **not**
  ported here — they depend on `LogEntry`, `MultikeyUtil`, and the witness model from later iterations.
- Test `test/vectors_test.dart`: loads a representative spec + interop file, asserts the missing-vector error,
  and asserts all 26 files are present. (Note: the count is 26, not the "25" mentioned informally; the spec
  `test-vectors/` README plus all interop files were included.)
- Gate: `dart pub get` + `dart analyze --fatal-infos` (no issues) + `dart test` (4 passed) → `VERIFY OK`.

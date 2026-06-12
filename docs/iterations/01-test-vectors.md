# Iteration 1 — Vendor the shared test vectors & spec

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`.
Stop for human review; never commit.

### Reference
`reference/didwebvh-java/didwebvh-core/src/test/resources/` (`test-vectors/`, `interop/`).

### Produce
- Copy **verbatim** into `packages/didwebvh_core/test/vectors/` (keep `test-vectors/` and `interop/` subdirs,
  including the JSONL/JSON files and their `README.md`s). These bytes are the cross-language interop contract —
  do not regenerate or reformat them.
- A small Dart test helper to load vector files by path.

### Acceptance
- Vector files present and loadable in a trivial Dart test; checksums match the Java copies.

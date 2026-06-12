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

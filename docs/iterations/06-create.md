# Iteration 6 — DID creation

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`create/` package: `CreateDidConfig`/`Operation`/`Result` and the `DidWebVh.create(...)` builder facade.

### Produce (`lib/src/create/`, `lib/src/core/`)
- Builder/config + async `execute()` returning `Future<CreateDidResult>`.

### Test
Port creation tests; assert a created first log entry matches `first-log-entry-good.jsonl`.

### Acceptance
- Create produces a spec-valid, vector-matching first log entry.

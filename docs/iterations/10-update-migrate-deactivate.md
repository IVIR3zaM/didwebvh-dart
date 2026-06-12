# Iteration 10 — Update, migration & deactivation

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`update/` package: Update/Migrate/Deactivate `Config`/`Operation`/`Result`.

### Produce (`lib/src/update/`, facade methods)
- Async operations producing subsequent log entries (key rotation, param change, domain migration,
  deactivation).

### Test
Port update tests; assert against `migrated-did.jsonl`, `deactivated-did.jsonl`, `pre-rotation-log.jsonl`,
`multi-entry-log.jsonl`.

### Acceptance
- Update/migrate/deactivate outputs match the corresponding vectors.

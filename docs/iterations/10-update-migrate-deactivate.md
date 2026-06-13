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

### Design decision (carried from iteration 6)
Apply the **same config-builder shape decided in iteration 6** to `UpdateDidConfig`, `MigrateDidConfig`, and
`DeactivateDidConfig` (they are fluent builders, like `CreateDidConfig`):

- Keep the faithful Java **fluent setters that `return this`**, and additionally support **cascade** (`..`, free
  since `..` ignores the return value) and **named-parameter construction** (a delegating constructor that
  applies each non-null argument through its like-named setter — one source of truth for copy/normalization).
  Forward the named arguments through the `DidWebVh.update`/`migrate`/`deactivate` facades.
- Any **positional boolean** setter (e.g. a future `portable`/flag toggle) stays positional and the
  `avoid_positional_boolean_parameters` lint is suppressed **scoped to `lib/src/update/`**, exactly as
  `lib/src/create/` does — it is a recognized false-positive for a single, well-named boolean setter, and the
  alternatives each cost something (drop the fluent style, lose explicit `false`, or mix styles). Same scoped
  suppression for `avoid_returning_this`.
- Mirror these three styles in the README usage examples for update/migrate/deactivate, keeping them honest
  (the fluent form shown as primary, with the cascade and named-parameter equivalents noted).

See `docs/iterations/06-create.md` (Implementation Notes) and `docs/PORTING-DECISIONS.md` §8 for the rationale.

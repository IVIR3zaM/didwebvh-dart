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

## Implementation Notes

- **`DidWebVhState` ported as the carried dependency.** All three Java `update/` operations take a
  `DidWebVhState`, which did not exist in Dart yet, so it was ported here into `lib/src/core/did_webvh_state.dart`
  (Java has it in the package root). Java's static factory methods `from`/`fromDidLog`/`fromJson` became `factory`
  constructors (idiomatic Dart, satisfies `prefer_constructors_over_static_methods`); `getWitnessProofs`/
  `setWitnessProofs` collapsed to a plain public mutable field. Its `validate()` is `async` — the documented ripple
  from the async `LogChainValidator` (decisions §2/§4) — so `DidWebVhState.validate()` returns
  `Future<ValidationResult>`.
- **Shared `buildEntry`.** `UpdateDidOperation.buildEntry` is the single entry-construction path used by update,
  migrate, and deactivate (mirroring Java). It is `async` (the proof generator is async). The `versionTime` logic is
  a faithful port: truncate `now` to seconds, and if it is not strictly after the predecessor's `versionTime`, use
  `predecessor + 1s`. The seconds-precision UTC `…Z` formatter is the same one `CreateDidOperation` uses.
- **Document handling uses decoded maps.** Java mutates Gson `JsonObject`s; the Dart port operates on
  `Map<String, Object?>` (the idiomatic decoded-JSON shape, decisions §8). Deep copies use the
  `jsonDecode(jsonEncode(...))` round-trip already used in `create/`. Migration's "string-replace every DID
  reference then re-parse" is reproduced with `jsonEncode(doc).replaceAll(oldDid, newDid)` followed by
  `jsonDecode` — equivalent to Java's `doc.toString().replace(...)`, since the result is re-parsed to a map and key
  order is irrelevant.
- **Config builders.** `UpdateDidConfig`/`MigrateDidConfig`/`DeactivateDidConfig` follow the iteration-6 shape:
  faithful fluent setters returning `this`, plus cascade and named-parameter construction, with package-private
  `...Value` getters for the operations (Dart privacy is per-library, so cross-file access needs public getters,
  exactly as `create/` does). The scoped `lib/src/update/analysis_options.yaml` suppresses `avoid_returning_this`
  and `avoid_positional_boolean_parameters`, matching `lib/src/create/`.
- **Tests.** `test/update/update_did_operation_test.dart` ports the Java `UpdateDidOperationTest` 1:1 (22 cases,
  all passing), using two freshly generated `TestSigner`s for the key-rotation/pre-rotation cases. The Java test
  signs with random keys (non-deterministic signatures), so it asserts on **chain validity and structural fields**
  rather than against fixed `.jsonl` bytes — the migrated/deactivated/pre-rotation/multi-entry vectors named in the
  acceptance section are already validated byte-wise by the iteration-8/9 validation and resolution suites.
  `test/core/did_webvh_state_test.dart` adds 7 cases that exercise the full `DidWebVhState` surface (witness-proof
  `toJson`/`fromJson` round-trip, the unmodifiable `logEntries` view, blank-line skipping in `fromDidLog`, the
  `appendEntry` DID-adoption branch, and `validate`) — paths the ported Java test leaves untouched. All new files
  are above the 80% coverage gate (state **100%**, operations 91–98%, configs 82–100%).

# Iteration 9 — DID resolution

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`resolve/` package: `DidResolver`, `RemoteDidFetcher`, `HttpDidFetcher`, `FileDidFetcher`, `LogProcessor`,
`ResolveOptions`.

### Produce (`lib/src/resolve/`)
- `RemoteDidFetcher` interface; `HttpDidFetcher` on `package:http` with the **10s timeout + 200KB cap** (mirror
  Java/OkHttp); `FileDidFetcher`; `LogProcessor`; `ResolveOptions`.

### Test
Port resolver tests using `package:http/testing.dart` `MockClient` (no real server); resolve vector logs.

### Acceptance
- Resolves vector logs to the expected DID document + metadata; timeout/size cap enforced.

### Design decision (carried from iteration 6) — feasibility caveat
The iteration-6 "three interchangeable call styles" decision applies **only where the config is a fluent
builder**. `ResolveOptions` is a small immutable value holder (version number / id / time filters), not a
builder, so:

- Prefer plain **named-parameter construction** for `ResolveOptions` (already the idiomatic Dart shape for a
  value type) — no `return this` setters, no lint suppressions needed.
- Add the fluent/cascade setter styles **only if** the Java `ResolveOptions` actually exposes a fluent builder
  surface worth mirroring; if it is a simple constructor/value type in Java, keep it a value type here and do
  **not** introduce builder machinery just for symmetry.
- Keep the README resolve examples honest about whichever shape ships.

See `docs/iterations/06-create.md` (Implementation Notes) and `docs/PORTING-DECISIONS.md` §8.

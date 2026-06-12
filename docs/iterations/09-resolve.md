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

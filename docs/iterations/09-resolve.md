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

## Implementation Notes

Ported the whole Java `resolve/` package plus the minimal `ImplicitServices` slice it depends on.

- **`ResolveOptions` shape (revised after review).** Java wraps an immutable value behind a fluent `Builder`.
  Because `ResolveOptions` is public-API-facing, it mirrors `CreateDidConfig` and supports the **three
  interchangeable call styles** (fluent chaining, cascade, named parameters): bare-property-name setters return
  `this`, the named-param constructor delegates to them, and reads go through `...Value` getters (to avoid the
  setter/getter name clash). `avoid_returning_this` is disabled for `lib/src/resolve/` via a directory-scoped
  `analysis_options.yaml`, exactly as `lib/src/create/` does. `witnessFetchMode(null)` resets to
  `proactive` (Java's builder default); `withFallbacks` keeps `this`'s fetch mode. `WitnessFetchMode` enum
  constants use Dart casing (`proactive`, `whenRequired`). _(Initial draft shipped a named-param-only value type;
  changed to the full builder on review since it is public API.)_
- **Async ripple.** `LogChainValidator.validate` / `WitnessValidator.validate` are `Future`-returning (iteration
  4/8 async-`Signer` delta), so `LogProcessor.process`, `DidResolver.resolve/resolveFromFile/resolveFromLog` are
  all `async`. The Java `Supplier<String>` lazy witness fetch becomes a `Future<String?> Function()`.
- **`RemoteDidFetcher` is async.** `package:http` is asynchronous, so the interface returns `Future<String>`
  (Java returns `String`). `HttpDidFetcher` takes an optional injectable `http.Client` for testing; `FileDidFetcher`
  stays synchronous (mirroring Java `Files.readAllBytes`) and uses `String` paths instead of `java.nio.Path`.
- **`HttpDidFetcher` size cap (revised after review).** Streams the body via `Client.send()` +
  `StreamedResponse.stream`, summing chunk lengths and throwing once the running total exceeds `maxResponseSize`
  — the body is rejected **while reading**, never fully buffered (a declared `Content-Length` over the cap
  short-circuits first). This reproduces OkHttp's streamed rejection and bounds memory even when the host omits or
  lies about `Content-Length`. The whole call (connect + headers + body read) is wrapped in `.timeout` to mirror
  OkHttp's callTimeout. A HEAD precheck was considered and rejected as unreliable (header often absent, and
  spoofable). `IllegalArgumentException` → `ArgumentError`. _(Initial draft buffered then checked length, which
  defeated the cap's purpose; fixed on review — see decisions §2, HTTP row.)_
- **`ImplicitServices`.** Only `addTo` (the resolver's need) is ported, operating on the decoded `state` map
  (deep-copied via `jsonDecode(jsonEncode(...))`, the analog of Gson `deepCopy`). The `httpsBase` helper is
  private here; the full `didweb/` package — `httpsBase` as a package-private testable, `DidWebPublisher` — is
  iteration 11.
- **Line splitting.** Java's `\R` (any Unicode line break) is approximated as `RegExp(r'\r\n|\r|\n')`, sufficient
  for `did.jsonl` content.
- **Tests.** `HttpDidFetcherTest` uses `MockClient` (incl. a delayed handler to exercise the `.timeout` path)
  rather than a real server. `LogProcessor`/`DidResolver` tests pass explicit, strictly increasing `versionTime`s
  to `buildUpdateEntry` (avoiding nanosecond-precision/flaky timing from Java's `Instant.now().minusNanos(1)`).

### Gate
`tool/verify.sh` → **VERIFY OK** (315 tests green; all packages analyze clean with `--fatal-infos`). Pinning
`very_good_analysis` to `^7.0.0` restores `dart pub get` on the `3.6.0` CI leg (the prior `^10.2.0` required Dart
`>=3.7.0`). New resolve tests cover the fetchers, `LogProcessor`, `DidResolver`, the three `ResolveOptions` call
styles, and the streamed size-cap abort (incl. a no-`Content-Length` hostile-body case).

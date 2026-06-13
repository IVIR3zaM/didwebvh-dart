# Iteration 7 — DID URL parsing & DID-to-HTTPS transformation

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`url/` package: `DidWebVhUrl`, `DidToHttpsTransformer`.

### Produce (`lib/src/url/`)
- Parser + transformer mirroring Java rules (path/port encoding, `.well-known`, `did.jsonl` location).

### Test
Port URL tests (including the negative cases).

### Acceptance
- All Java URL parse/transform cases pass.

### Implementation Notes
- Ported `DidWebVhUrl` → `lib/src/url/did_webvh_url.dart` and `DidToHttpsTransformer` →
  `lib/src/url/did_to_https_transformer.dart`. Both classes re-exported from the barrel.
- `DidWebVhUrl.parse` is a **factory constructor** (not Java's `static parse`) — idiomatic Dart, same call
  site, and matches the existing `VersionId.parse` pattern. Getters (`scid`, `domain`, `decodedDomain`, `host`,
  `port`, `pathSegments`, `fragment`, `queryParams`) replace Java's `getX` accessors; `port` keeps the `-1`
  sentinel so the transformer's `port > 0` check is byte-identical. Lists/maps are `unmodifiable`, mirroring
  Java's `Collections.unmodifiable*`. Dart `String.split(':')` keeps trailing empties, matching Java's
  `split(":", -1)`.
- **IDNA / NFC tradeoff (raised + resolved with the human).** Java's `DidToHttpsTransformer` applies
  `Normalizer.normalize(host, NFC)` + `IDN.toASCII(host, ALLOW_UNASSIGNED)`. Dart's SDK has **no built-in
  Unicode NFC or IDNA/Punycode**, and neither was in the approved deps. Decision: **add `unorm_dart` (NFC/NFKC)
  and `punycode` (RFC 3492)** — recorded in `PORTING-DECISIONS.md` §2. The transformer NFC-normalizes the host,
  then per RFC 3490 ToASCII passes all-ASCII labels through unchanged (no case-folding) and Punycode-encodes
  non-ASCII labels with the `xn--` prefix after a nameprep **approximation** (NFKC + lowercase). Every Java
  test/vector host is ASCII (incl. already-`xn--` `xn--example-cua.com`), so the observable output is identical;
  the non-ASCII nameprep path is the only place the port is an approximation of Java's exact stringprep tables,
  and no `did:webvh` vector exercises it.
- Tests: `test/url/did_webvh_url_test.dart` and `test/url/did_to_https_transformer_test.dart` port the Java
  `DidWebVhUrlTest` / `DidToHttpsTransformerTest` one-for-one (all cases incl. negatives).
- Gate: `tool/verify.sh --coverage` → **VERIFY OK** (205 tests). Per-file line coverage:
  `did_webvh_url.dart` 111/111 (100%), `did_to_https_transformer.dart` 51/61 (84%) — uncovered lines are the
  non-ASCII IDNA branch and the `%XX` percent-encoding branch (no test path segment contains a reserved char).

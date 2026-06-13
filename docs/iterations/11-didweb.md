# Iteration 11 — Parallel did:web publishing

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`didweb/` package: `DidWebPublisher`, `ImplicitServices`.

### Produce (`lib/src/didweb/`)
- did:web document generation parallel to the did:webvh document.

### Test
Port did:web tests; compare against `services-*` interop vectors where applicable.

### Acceptance
- Generated did:web document matches Java output.

### Implementation Notes

- Ported `DidWebPublisher.toDidWeb` faithfully (`lib/src/didweb/did_web_publisher.dart`): deep-copy the resolved
  `did:webvh` document, `ImplicitServices.addTo`, then text-replace `did:webvh:<scid>:` → `did:web:` over the
  serialized document, then `_addAlsoKnownAs`. The deep copy and the text-replace use `dart:convert`
  (`jsonDecode(jsonEncode(...))` and `jsonEncode(...).replaceAll(...)`) in place of Gson's
  `deepCopy()` / `toString()` / `JsonParser.parseString()`. `jsonEncode`/`jsonDecode` preserve key insertion
  order (LinkedHashMap), so the text-replace operates on the same byte layout Java does and re-parses identically.
- `ImplicitServices` already existed from iteration 9 (added there as the minimal dependency the resolver needed).
  It was already a faithful port of the Java class, so iteration 11 added no new code there — only `DidWebPublisher`
  and the barrel exports. Java's `ImplicitServices.httpsBase` is package-static; the Dart port keeps it private
  (`_httpsBase`) since `DidWebPublisher` only needs `addTo`.
- `alsoKnownAs` dedup uses a `LinkedHashSet` (Dart's default `Set`, insertion-ordered) mirroring Java's
  `LinkedHashSet`: collect existing entries, add the original `did:webvh` DID, remove the self `did:web` DID. Note
  the order: services are added *before* the text-replace (so their `did:webvh:<scid>:` ids become `did:web:`),
  while `alsoKnownAs` is rebuilt *after* it (so the original `did:webvh` DID is added verbatim and any pre-existing
  `did:webvh` entry has already been rewritten to `did:web`, hence collapses into the removed self entry).
- Ported `DidWebPublisherTest` (12 cases) one-for-one. The shared interop `did.jsonl` vectors carry no
  `services-*` did:web fixtures, so the Java unit test is the contract here. Gate: `tool/verify.sh --coverage`
  → **VERIFY OK** (all 355 tests pass, `dart analyze --fatal-infos` clean).

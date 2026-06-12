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

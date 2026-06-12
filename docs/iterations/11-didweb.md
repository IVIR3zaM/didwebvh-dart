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

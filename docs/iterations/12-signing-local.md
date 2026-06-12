# Iteration 12 — `didwebvh_signing_local` package

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`reference/didwebvh-java/didwebvh-signing-local/` (`LocalKeySigner.java`).

### Produce (`packages/didwebvh_signing_local/`)
- `LocalKeySigner` implementing the **async** `Signer` via `package:cryptography` `Ed25519`; JWK in/out;
  `generate()` factory.

### Test
Port signer tests; full create→sign→verify→resolve round-trip with this signer.

### Acceptance
- Round-trip create/update/resolve succeeds end-to-end using `LocalKeySigner`.

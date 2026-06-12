# Iteration 4 — Signing: `Signer`, proof generation & verification

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`signing/Signer.java`, `signing/ProofGenerator.java`, `signing/ProofVerifier.java`.

### Produce (`lib/src/signing/`)
- `Signer` as an **async** abstract interface (the one intentional delta — decisions §4):
  `Future<Uint8List> sign(Uint8List data)`, plus `keyType`/`verificationMethod` getters.
- `ProofGenerator` (async; JCS-canonicalize entry without proof → sign → build `DataIntegrityProof`).
- `ProofVerifier` — **synchronous** verification using `cryptography`'s `DartEd25519`.

### Test
Port proof tests; verify the proofs in the vendored vectors validate; generate→verify round-trip.

### Acceptance
- Verifies all vector proofs; the async ripple (`Future`-returning generate) is documented in code.

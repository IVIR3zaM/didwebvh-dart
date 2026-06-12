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

### Implementation Notes
- **Files added:** `lib/src/signing/signer.dart`, `proof_generator.dart`, `proof_verifier.dart` (all three
  re-exported from the `didwebvh_core` barrel). Tests: `test/signing/test_signer.dart` (Ed25519-backed `Signer`),
  `proof_generator_test.dart`, `proof_verifier_test.dart` (ports of the Java tests), and
  `proof_verifier_vectors_test.dart` (verifies every proof in all 13 interop `did.jsonl` vectors).
- **`Signer.sign` is async** (`Future<Uint8List>`) — the documented delta. `ProofGenerator.generate` is therefore
  `async`; `buildHashData` and `toJsonWithoutProof` stay synchronous (faithful to Java). The Java `JsonObject`
  document param becomes `Map<String, Object?>`, JCS-canonicalized via `Jcs.canonicalize(jsonEncode(map))`.
- **Decision deviation (raised with the user, confirmed):** PORTING-DECISIONS.md §2/§4 and risk #4 called for
  *synchronous* proof verification via `cryptography`'s `DartEd25519`. That API is **async-only** — there is no
  public synchronous verify (its lone `await` is internal SHA-512). Chosen resolution: keep the single approved
  crypto dependency and make `ProofVerifier.verify` / `verifyDocument` return `Future<bool>`. **This ripples into
  iteration 8** (the log-chain validation loop becomes async). No `ed25519_edwards` dependency was added.
- **Naming:** Java's overloaded `verify(proof, LogEntry)` / `verify(proof, JsonObject)` → `verify` (LogEntry) and
  `verifyDocument` (Map), since Dart has no method overloading.
- **Gate:** `tool/verify.sh --coverage` → `VERIFY OK`, 115 tests pass. `didwebvh_core` line coverage 92.9%
  (590/635); the three signing files are included in `lcov.info`.

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

### Implementation Notes
- `LocalKeySigner` (`packages/didwebvh_signing_local/lib/src/local_key_signer.dart`) implements the async core
  `Signer` over `package:cryptography` `Ed25519`. Stores the raw 32-byte seed (= Java BouncyCastle
  `privateKey.getEncoded()`, = `cryptography` `SimpleKeyPairData.bytes`) and the raw 32-byte public key; for each
  `sign` it rebuilds the key pair from the seed (`newKeyPairFromSeed`) and signs. `Ed25519()` (default impl)
  produces standard interoperable signatures; verification stays on core's `DartEd25519`.
- **Async-factory delta.** Java's `generate()`/`fromPrivateKey()` are synchronous because BouncyCastle derives the
  public key synchronously. `cryptography` derives it asynchronously (no public sync path — same constraint that
  made `ProofVerifier` async in iteration 4), so both are `Future`-returning factories. `fromJson` carries the
  public key in the JWK `x`, so it stays synchronous — converted to a `factory` constructor
  (`LocalKeySigner.fromJson`) per `very_good_analysis` (`prefer_constructors_over_static_methods`); same call
  site, idiomatic Dart (decisions §8). `generate`/`fromPrivateKey` remain `static Future<...>` (factory
  constructors can't be async).
- JWK uses `dart:convert` `base64Url` with padding stripped on encode and `base64Url.normalize` on decode, to
  match Java's `Base64.getUrlEncoder().withoutPadding()` / URL decoder.
- **Core public-surface change (minimal dependency):** added `export 'src/crypto/multikey.dart'` to the
  `didwebvh` barrel. `MultikeyUtil` is public cross-module API in Java; exporting it lets this package (and
  the existing in-test `TestSigner`, whose now-redundant `src/...` import was removed) reference it without
  tripping `implementation_imports`.
- Tests (`test/local_key_signer_test.dart`) port all `LocalKeySignerTest` cases and add the acceptance round-trip
  (`DidWebVh.create(...).execute()` → `DidResolver().resolveFromLog(logLine, did)` → asserts resolved
  `didDocument.id == did`). Gate: `tool/verify.sh` → **VERIFY OK** (all packages green; signing_local 9 tests).

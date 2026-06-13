# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Port note.** `didwebvh-dart` is a faithful port of
> [`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java). Record the pinned Java
> tag/commit each iteration is ported against (see the Progress log in `docs/PORTING-STATUS.md`).

## [Unreleased]

### Added
- Repository seed: porting docs (`docs/AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/PORTING-DECISIONS.md`,
  `docs/PORTING-GUIDE.md`, `docs/PORTING-STATUS.md` + `docs/iterations/`), `PROMPT.md`, and the Java-reference setup
  (`reference/README.md`).
- Iteration 0 — repository scaffolding: pub-workspace root `pubspec.yaml` (`workspace:` list, `sdk: '^3.6.0'`),
  the three packages `didwebvh_core`, `didwebvh_signing_local`, `didwebvh_wizard` (each with its own `pubspec.yaml`,
  public barrel, and `lib/src/` tree per decisions §4), `analysis_options.yaml` (`very_good_analysis`),
  `codecov.yml` (80% project + patch, gate scoped to `didwebvh_core`), and the
  `.github/workflows/ci.yml` (Dart SDK matrix `3.6.0` / `stable` / `beta`) and `publish.yml` (tag-triggered
  pub.dev OIDC) workflows.
- Iteration 1 — vendored the shared cross-language test vectors: the 26 files under
  `test-vectors/` and `interop/` copied **verbatim** (byte-for-byte; SHA-256 verified) from the Java reference
  (`didwebvh-core/src/test/resources/`) into `packages/didwebvh_core/test/vectors/`. These bytes are the
  cross-implementation interop contract and are never edited. Added a `TestVectors` load helper
  (`test/support/test_vectors.dart`, mirroring Java's `TestVectors.readResource`) and a presence/loadability test.
- Iteration 2 — crypto primitives (`packages/didwebvh_core/lib/src/crypto/`), the byte-exact foundations of the
  method, ported from the Java `crypto/` package:
  - `jcs.dart` (`Jcs`) — RFC 8785 JSON Canonicalization Scheme. The Java side delegates to erdtman's
    `JsonCanonicalizer`; reimplemented here as recursive UTF-16-code-unit key sorting, ECMAScript
    `Number::toString` serialization (RFC 8785 §3.2.2.3), minimal string escaping, and UTF-8 output. Gated on
    RFC 8785 number vectors (integer, fraction, and exponential boundaries) plus the ported Java `JcsTest` cases.
  - `multihash.dart` (`MultihashUtil`) — `sha2-256` (`0x12`) multihash encode/extract.
  - `base58btc.dart` (`Base58Btc`) — base58 (Bitcoin alphabet) with multibase `z`-prefix framing; the bitcoinj
    leading-zero algorithm reimplemented to avoid a dependency (decisions §2). Byte-exactness cross-checked by
    decoding/re-encoding a real multikey from the interop vectors.
  - `multikey.dart` (`MultikeyUtil`) — W3C Multikey for Ed25519 (codec `0xed01`).
  - `core/exceptions.dart` — minimal `DidWebVhException` / `ValidationException` (the crypto utilities throw
    `ValidationException`); the full hierarchy lands in iteration 3. These stay package-private under `lib/src/`;
    the public barrel is unchanged.
- Iteration 3 — model classes + exceptions, ported from the Java `model/`, `witness/` and `core/` packages:
  - `model/version_id.dart` (`VersionId`) — `"<number>-<hash>"` parsing plus the preliminary (SCID) form.
  - `model/data_integrity_proof.dart` (`DataIntegrityProof`) — `eddsa-jcs-2022` proof bean with `defaults()`.
  - `model/parameters.dart` (`Parameters`) — log-entry parameters (spec §3.7.1) with `defaults()` and `merge()`.
  - `model/log_entry.dart` (`LogEntry`) — one JSONL line; `toJsonLine()` / `fromJsonLine()`.
  - `model/did_document.dart` (`DidDocument`) — thin wrapper over a decoded JSON object.
  - `model/resolution_metadata.dart` (`ResolutionMetadata`) and `model/resolve_result.dart` (`ResolveResult`).
  - `witness/witness_config.dart` (`WitnessConfig`) + `witness/witness_entry.dart` (`WitnessEntry`) — the spec
    `witness` parameter, serializing as `{}` when inactive (faithful to the Java `WitnessConfigTypeAdapter`).
  - `core/exceptions.dart` — completed the hierarchy: `SigningException`, `UrlParseException`, and
    `ResolutionException` (RFC 9457 problem details), alongside the existing `DidWebVhException` /
    `ValidationException`.
  - `model/json_support.dart` (`JsonModel` / `JsonSupport`) and the internal `model/json.dart` deep
    equality/hash helpers replace Gson: hand-written `toJson({omitNull})` reproduces Java's null-preserving
    (`serializeNulls`) vs null-omitting (compact) serialization precisely (decisions §2). The public barrel now
    re-exports the model + exception API.
- Iteration 4 — signing (`packages/didwebvh_core/lib/src/signing/`), ported from the Java `signing/` package:
  - `signer.dart` (`Signer`) — the signing abstraction. Per the documented architectural delta (decisions §4),
    `sign` is **async** (`Future<Uint8List> sign(Uint8List)`) instead of Java's synchronous `byte[] sign(byte[])`,
    so the one interface can back local keys, remote KMS, or HSM signers.
  - `proof_generator.dart` (`ProofGenerator`) — builds `eddsa-jcs-2022` proofs: canonicalizes the entry without
    its `proof`, signs `SHA256(JCS(proofConfig)) || SHA256(JCS(document))`, and base58btc-multibase-encodes the
    signature. `generate` is `async` (the signer ripple); `buildHashData` stays synchronous, matching Java.
    The `created` timestamp uses the reference's `yyyy-MM-dd'T'HH:mm:ss'Z'` UTC format (seconds precision).
  - `proof_verifier.dart` (`ProofVerifier`) — verifies proofs, plus `isAuthorized` and `extractMultikey`. Java's
    two `verify` overloads (`LogEntry` / `JsonObject`) map to `verify` and `verifyDocument`. **Deviation from
    decisions §2/§4 / risk #4:** that document specified *synchronous* verification via `cryptography`'s
    `DartEd25519`, but `DartEd25519.verify` is async-only (no public sync entry point); verification therefore
    returns `Future<bool>`. No new dependency was added. This ripples into the iteration 8 validation loop.
  - The public barrel re-exports `Signer`, `ProofGenerator`, `ProofVerifier`. Tests port the Java
    `ProofGeneratorTest` / `ProofVerifierTest` (generate→verify round-trip, tamper detection, `isAuthorized`,
    `extractMultikey`) and add a vector test that verifies **every** proof in all 13 vendored interop `did.jsonl`
    files — the cross-language byte-exactness contract for JCS + multihash + eddsa-jcs-2022.
- Iteration 5 — SCID, entry-hash & pre-rotation generators
  (`packages/didwebvh_core/lib/src/crypto/`), ported from the Java `crypto/` package; all three reuse the
  iteration-2 byte-exact primitives (`Jcs`, `MultihashUtil`, `Base58Btc`):
  - `scid_generator.dart` (`ScidGenerator`) — derives the SCID from a preliminary first log entry (spec §3.3 /
    §3.7.3): `base58btc(multihash(JCS(entry-with-{SCID}-placeholders)))`. `generate`, `verify` (strip proof,
    reset `versionId`/`scid` to `{SCID}`, string-replace the SCID, re-derive), and `placeholder()`.
  - `entry_hash_generator.dart` (`EntryHashGenerator`) — computes the entry-hash portion of `versionId`
    (spec §4.2): strip `proof`, substitute the predecessor `versionId`, then
    `base58btc(multihash(JCS(entry)))`. Canonicalizes the decoded entry map directly via the new
    `Jcs.canonicalizeValue` (see below).
  - `pre_rotation_hash_generator.dart` (`PreRotationHashGenerator`) — pre-rotation commitment hash (spec §3.5 /
    §3.7.7): `base58btc(multihash(utf8(multikey)))`.
  - These stay package-private under `lib/src/` (consistent with the iteration-2 crypto primitives); the public
    barrel is unchanged. Tests port the Java `ScidGeneratorTest` / `EntryHashGeneratorTest` /
    `PreRotationHashGeneratorTest`, plus vector-gated tests proving byte-exact SCID and entry-hash-chain
    derivation against the vendored interop logs (`first-log-entry-good.jsonl`, `multi-entry-log.jsonl`).
- Iteration 6 — DID creation (`packages/didwebvh_core/lib/src/create/` + `lib/src/core/did_webvh.dart`),
  ported from the Java `create/` package and the `DidWebVh` facade (spec §3.6.1):
  - `create/create_did_config.dart` (`CreateDidConfig`) — builder (`domain` + `signer` required; optional
    `path`, `portable`, `ttl`, `alsoKnownAs`, `controllers`, `witness`, `watchers`, `nextKeyHashes`,
    `additionalDocumentContent`) supporting three interchangeable call styles: **fluent** chaining (setters return
    `this`, Java-style), **cascade** (`..`, idiomatic Dart — works on the same setters since `..` ignores the
    return value), and **named parameters** at construction (a delegating constructor that applies each non-null
    argument through its like-named setter, so there is one source of truth for the copy/normalization logic). The
    named arguments are also forwarded through `DidWebVh.create`. `execute()` returns `Future<CreateDidResult>`
    (the async-`Signer` ripple, decisions §4). Package-private accessors carry a `Value` suffix where they would
    clash with the like-named setter (`pathValue`, `portableValue`, …).
  - `create/create_did_operation.dart` (`CreateDidOperation`) — the 10-step creation flow: build the
    `{SCID}`-templated DID + document + parameters, derive the SCID, string-replace the placeholder, compute the
    entry hash (predecessor = SCID), set `versionId` to `1-<hash>`, then generate and attach the proof. Controller
    handling matches Java exactly (null → self; empty → omit; one → string; many → array). `execute` is `async`.
  - `create/create_did_result.dart` (`CreateDidResult`) — `did` / `logEntry` / `logLine` holder.
  - `core/did_webvh.dart` (`DidWebVh`) — public facade; only `create(domain, signer)` so far
    (update/migrate/deactivate/validate/resolve land in iterations 7–10).
  - The public barrel re-exports `DidWebVh`, `CreateDidConfig`, `CreateDidResult`. Tests port the Java
    `CreateDidOperationTest` one-for-one (async-adapted) and add a vector check that the
    `first-log-entry-good.jsonl` entry's SCID, entry hash, and proof all verify and that a fresh creation produces
    the same `state` key ordering. A `lib/src/create/analysis_options.yaml` scopes `avoid_returning_this` /
    `avoid_positional_boolean_parameters` off for the fluent builder only (same narrow-scoping pattern as
    `lib/src/model/` and `lib/src/witness/`).

### Changed
- `Jcs` — added `Jcs.canonicalizeValue(Object?)`, now the primary entry point: it canonicalizes an
  already-decoded JSON value directly, dropping the encode→parse round-trip the port previously copied from Java's
  `canonicalize(JsonObject)` overload. `Jcs.canonicalize(String)` is retained for text-only inputs (the SCID
  `{SCID}` string-replace step) and decodes once before delegating. `EntryHashGenerator` and `ProofGenerator` now
  canonicalize their maps directly. Output is byte-identical (a unit test asserts the two paths match, and all
  interop-vector tests — entry-hash chain and every `eddsa-jcs-2022` proof — still pass). This is the first
  application of the new "idiomatic Dart over Java's internal shape" priority recorded in
  `docs/PORTING-DECISIONS.md` §8 and `docs/AGENTS.md`.
- `docs/AGENTS.md` — added guiding principle "Idiomatic Dart first" and the priority order (interop vectors >
  Dart best practices > matching Java's internal approach); summarized the `Jcs` value API.
- `tool/verify.sh` — one-shot quality gate (`dart pub get` + workspace `dart analyze --fatal-infos` + `dart test`
  for every package with a `test/` dir), the Dart analog of the Java project's `./mvnw clean verify`. Pass
  `--coverage` to also emit `packages/didwebvh_core/coverage/lcov.info`. Established as the canonical
  end-of-change gate in the agent docs (`docs/AGENTS.md`, `docs/PORTING-GUIDE.md`, `PROMPT.md`).

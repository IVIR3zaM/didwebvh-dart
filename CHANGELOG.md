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
- Iteration 7 — DID URL parsing & DID-to-HTTPS transformation (`packages/didwebvh_core/lib/src/url/`), ported
  from the Java `url/` package (spec §3.4):
  - `url/did_webvh_url.dart` (`DidWebVhUrl`) — parses `did:webvh:<SCID>:<domain>[:<path>...][?query][#fragment]`
    into its components. Faithful port of the Java parse rules: fragment/query extraction, colon-split segments,
    46-char base58btc SCID validation, domain/`%3A`-port decoding and 1–65535 range check, IP-address rejection
    (bracketed IPv6 + all-digits-and-dots IPv4), and empty-path-segment (`::`) rejection. `decodedDomain` / `host`
    / `port` getters and `toString()` / `toBaseDid()` round-trips mirror Java. `parse` is a factory constructor
    (idiomatic Dart, same call site as Java's `static parse`).
  - `url/did_to_https_transformer.dart` (`DidToHttpsTransformer`) — `toHttpsUrl` (`did.jsonl`), `toWitnessUrl`
    (`did-witness.json`), and `toDidWebUrl`. `.well-known` is used when there is no path; path segments are
    percent-encoded per RFC 3986 (unreserved passthrough, uppercase `%XX`). The host NFC + IDNA/Punycode step
    mirrors Java's `Normalizer.normalize(NFC)` + `IDN.toASCII`: all-ASCII labels pass through unchanged (matching
    RFC 3490 ToASCII), and non-ASCII labels are nameprepped (approximated as NFKC + lowercase) and Punycode-encoded
    with the `xn--` ACE prefix.
  - New dependencies `punycode` and `unorm_dart` (decisions §2 update) supply the IDNA/Punycode and Unicode-NFC
    primitives Dart lacks in its core libraries. Tests port the Java `DidWebVhUrlTest` and
    `DidToHttpsTransformerTest` one-for-one. The barrel re-exports `DidWebVhUrl` and `DidToHttpsTransformer`.
- Iteration 8 — log-chain validation & witness verification, ported from the Java `validate/` and `witness/`
  packages (spec §3.6.2; pre-rotation §3.7.7; witness §3.7.5/§3.7.8):
  - `validate/log_chain_validator.dart` (`LogChainValidator`) — the full spec §3.6.2 validation loop:
    versionId/versionNumber checks, parameter merge + rule validation (first-entry `method`/`scid`/`updateKeys`,
    no `scid` after the first entry, method-version non-decrease, `portable` not set true after the first entry,
    witness-threshold bounds), SCID verification on the first entry, entry-hash verification, Data-Integrity proof
    authorization + signature verification, `versionTime` monotonicity and not-in-future (60s skew), `state.id`
    SCID-anchor portability check, key pre-rotation commitment matching, and deactivation termination. Per the
    documented async-`Signer` delta, `validate` returns a `Future<ValidationResult>` (the loop `await`s
    `ProofVerifier.verify`, which `package:cryptography` exposes only asynchronously) — the one observable
    departure from Java's synchronous loop.
  - `validate/witness_validator.dart` (`WitnessValidator`) — threshold witness verification (spec §3.7.8): verifies
    each `did-witness.json` proof once over `{"versionId": "<vid>"}`, ignores proofs whose versionId is not in the
    published log, and counts distinct authorized witnesses (accepting both `did:key:<mk>` and bare-multikey ids).
    Enforces the §3.7.5 rule that a witness-list change must be witnessed by the **prior** list. Async for the same
    reason as above.
  - `validate/validation_result.dart` / `validate/witness_validation_result.dart` — the two result value types.
  - `witness/witness_proof_collection.dart` (`WitnessProofCollection`) and `witness/witness_proof_entry.dart`
    (`WitnessProofEntry`) — the `did-witness.json` model (a bare array of `{versionId, proof[]}` entries), with
    hand-written `fromJson`/`toJson`. (`WitnessConfig`/`WitnessEntry` already landed in iteration 3.)
  - Tests port the Java `LogChainValidatorTest`, `WitnessValidatorTest`, and `WitnessProofCollectionTest`, plus the
    interop validator tests (`InteropJavaEeccLogsTest`, `InteropPreRotationConsumeTest`, `InteropTsBasicUpdateTest`,
    `InteropEmptyWitnessObjectTest`, `InteropRustWitnessProofsTest`, `InteropNegativeCrossDidWitnessReplayTest`)
    against the vendored vectors. The barrel re-exports the four `validate/` types and the two witness-proof types.
- Iteration 9 — DID resolution, ported from the Java `resolve/` package (spec §3.2 resolution, §3.8/§3.9 implicit
  services):
  - `resolve/did_resolver.dart` (`DidResolver`) — high-level resolver for HTTP, file, and in-memory logs.
    `resolve(did[, options])` parses the DID URL, merges query-string version selectors (`?versionId` /
    `?versionTime` / `?versionNumber`) under explicit `options`, fetches `did.jsonl`, and (per `witnessFetchMode`)
    fetches `did-witness.json` proactively or only when the log requires witnesses. `resolveFromFile(path)` and
    `resolveFromLog(jsonl, did)` resolve without network access. Resolution is `async` (the documented ripple from
    the async validators).
  - `resolve/resolve_options.dart` (`ResolveOptions` + `WitnessFetchMode`) — version-selection holder mirroring
    Java's fluent `ResolveOptions.Builder`. Like `CreateDidConfig`, it supports the three interchangeable call
    styles (fluent chaining, cascade, named parameters) since it is public-API-facing, with `...Value` read
    accessors, `withFallbacks`, and `hasMultipleVersionSelectors`.
  - `resolve/remote_did_fetcher.dart` (`RemoteDidFetcher`), `resolve/http_did_fetcher.dart` (`HttpDidFetcher`,
    on `package:http`, with the 10 s call timeout + 200 KB response cap mirroring Java/OkHttp; 404 → `notFound`,
    other failures → `httpError`). The cap is enforced by **streaming** the body (`Client.send()` +
    `StreamedResponse.stream`) and aborting once the running byte count exceeds the limit — the response is never
    fully buffered, so a host that omits or lies about `Content-Length` cannot force unbounded memory use.
    `resolve/file_did_fetcher.dart` (`FileDidFetcher`) does synchronous file reads.
  - `resolve/log_processor.dart` (`LogProcessor`) — parses the JSONL log, runs log-chain validation, validates
    witness proofs when the merged parameters require them (rejecting replayed proofs whose `versionId` is not in
    the published log), selects the entry by versionId/versionNumber/versionTime (latest by default), and builds the
    `ResolveResult` (DID Document + `ResolutionMetadata`); deactivated DIDs return metadata without a document.
  - `didweb/implicit_services.dart` (`ImplicitServices.addTo`) — a minimal slice of the iteration-11 `didweb/`
    package, ported now because resolution must inject the implicit `#files` and `#whois` services (spec §3.8/§3.9)
    into the resolved document unless the controller already declared them. Kept package-private; the full
    `didweb/` package (and `httpsBase`, the publisher) lands in iteration 11.
  - Tests port the Java `FileDidFetcherTest`, `HttpDidFetcherTest` (using `package:http/testing.dart` `MockClient`
    instead of OkHttp `MockWebServer`, per decisions §2), `LogProcessorTest`, and `DidResolverTest`, with a shared
    `resolve_test_support.dart`. The barrel re-exports `DidResolver`, `HttpDidFetcher`, `ResolveOptions`, and
    `WitnessFetchMode`.

### Changed
- Pinned `very_good_analysis` to `^7.0.0` (down from `^10.2.0`). VGA `8.0.0+` requires Dart `>=3.7.0`, which broke
  `dart pub get` on the CI `3.6.0` matrix leg and conflicted with the documented `^3.6.0` SDK floor (decisions §3).
  `^7.0.0` is the newest line that supports `3.6.0`, keeping the Affinidi-`ssi`-aligned floor intact. See
  `docs/PORTING-DECISIONS.md` §2 (lint row).
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

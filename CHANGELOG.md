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
- Iteration 10 — update, migration & deactivation, ported from the Java `update/` package plus the
  `DidWebVhState` holder (spec §3.6.3 update, §3.6.4 deactivation, §3.7.6 migration):
  - `core/did_webvh_state.dart` (`DidWebVhState`) — the mutable DID state (log entries, witness proofs, active
    parameters). `from`/`fromDidLog`/`fromJson` factory constructors, `toDidLog`/`toJson` serialization,
    `appendEntry` (which also tracks the canonical DID from the latest entry's `id`), `accumulateParameters`,
    `isDeactivated`, `lastEntry`, and an `async` `validate()` (the ripple from the async `LogChainValidator`).
  - `update/update_did_operation.dart` (`UpdateDidOperation`) — builds and signs the next log entry: carries the
    document forward (or replaces it), applies the parameter delta, advances `versionTime` (bumped one second past
    the predecessor when the truncated clock has not moved), hashes against the predecessor `versionId`, and
    attaches the `eddsa-jcs-2022` proof. The shared `buildEntry` underpins all three operations.
  - `update/migrate_did_operation.dart` (`MigrateDidOperation`) — preserves the SCID, rewrites every DID reference
    in the document to the new domain/path, and appends the old DID to `alsoKnownAs` (deduplicated); guarded by a
    `portable: true` check.
  - `update/deactivate_did_operation.dart` (`DeactivateDidOperation`) — emits the deactivation entry
    (`deactivated=true`, `updateKeys=[]`); when pre-rotation is active it first emits an intermediate entry signed
    by the revealed next key that clears `nextKeyHashes`, producing two entries.
  - `update/{update,migrate,deactivate}_did_config.dart` + `update_did_result.dart` — fluent builders mirroring
    `CreateDidConfig`'s three interchangeable call styles (fluent, cascade, named parameters), with the same
    scoped `analysis_options.yaml` suppression (`avoid_returning_this`, `avoid_positional_boolean_parameters`).
  - `DidWebVh` gains the `update`/`migrate`/`deactivate` facades; the barrel re-exports `DidWebVhState`, the three
    configs, and `UpdateDidResult`. Tests port the Java `UpdateDidOperationTest` (22 cases) one-for-one, adapted to
    the async signer and decoded-map documents, plus a dedicated `DidWebVhState` suite (7 cases) covering the
    witness-proof `toJson`/`fromJson` round-trip and the remaining accessors (state file at 100% coverage).
- Iteration 11 — parallel `did:web` publishing, ported from the Java `didweb/` package (spec §3.7.10):
  - `didweb/did_web_publisher.dart` (`DidWebPublisher`) — `toDidWeb` converts a resolved `did:webvh` DID Document
    into the parallel `did:web` DID Document: deep-copies the input, adds the implicit services, text-replaces
    `did:webvh:<scid>:` with `did:web:` across the serialized document, then adds the original `did:webvh` DID to
    `alsoKnownAs` (deduplicated, removing the self `did:web` DID). `toDidWebUrl` delegates to
    `DidToHttpsTransformer`. Throws `ValidationException` on a null document or missing id.
  - Reuses the existing `didweb/implicit_services.dart` (`ImplicitServices`, landed in iteration 9 as a minimal
    dependency); the barrel now re-exports both `DidWebPublisher` and `ImplicitServices`. Tests port the Java
    `DidWebPublisherTest` (12 cases) one-for-one.
- Iteration 12 — `didwebvh_signing_local` package: local in-memory Ed25519 `Signer`, ported from the Java
  `didwebvh-signing-local` module (`LocalKeySigner`):
  - `lib/src/local_key_signer.dart` (`LocalKeySigner`) — implements the async core `Signer` over
    `package:cryptography` `Ed25519`. `generate()` and `fromPrivateKey(seed)` are async factories (the public key
    is derived asynchronously by `cryptography` — a direct consequence of the documented async `Signer` delta);
    `LocalKeySigner.fromJson(json)` is a synchronous factory constructor since the public key is already present
    in the JWK. JWK in/out (`{"kty":"OKP","crv":"Ed25519","x":...,"d":...}`, base64url without padding) mirrors
    Java's Gson form; `keyType`/`verificationMethod`/`publicKeyMultikey` reuse the core `MultikeyUtil`. Signing
    failures are wrapped in `SigningException`, matching Java. Tests port the Java `LocalKeySignerTest` plus a full
    create→sign→verify→resolve round-trip (the iteration's acceptance criterion). Excluded from the coverage gate
    (thin adapter, per decisions §5).
- Iteration 13 — `didwebvh_wizard` package: interactive CLI wizard, ported from the Java `didwebvh-wizard`
  module:
  - `lib/src/wizard_io.dart` (`WizardIo`) + `lib/src/console_wizard_io.dart` (`ConsoleWizardIo`) — the testable
    terminal-I/O seam (`readLine`/`println`/`printError`) backed by `stdin`/`stdout`/`stderr`.
  - `lib/src/wizard_prompts.dart` (`WizardPrompts`), `lib/src/wizard_files.dart` (`WizardFiles`) and
    `lib/src/wizard_exception.dart` (`WizardException`) — shared prompt helpers (`askRequired`/`askOptional`/
    `askYesNo`/`askInt`/`askChoice`), the standard file names + read/write/append helpers, and the wizard's
    runtime exception.
  - `lib/src/create_wizard.dart` (`CreateWizard`), `lib/src/update_wizard.dart` (`UpdateWizard`),
    `lib/src/resolve_wizard.dart` (`ResolveWizard`), `lib/src/export_did_web_wizard.dart` (`ExportDidWebWizard`)
    — the four interactive flows (create / modify·migrate·deactivate / resolve over HTTPS or a local file /
    export the parallel did:web document). All `run` methods are `async` (the documented async-`Signer` ripple,
    decisions §4).
  - `lib/src/wizard_witness_keys.dart` (`WizardWitnessKeys`) + `lib/src/wizard_witness_proofs.dart`
    (`WizardWitnessProofs`) — the local witness key store (`witnesses/witness-<multikey>.json`) and witness-proof
    collection that writes `did-witness.json` **before** `did.jsonl` (spec §3.7.8); a new witness list is
    witnessed by the **prior** active list (spec §3.7.5).
  - `lib/src/wizard_main.dart` (`WizardMain`) — the menu/action flow (`run(WizardIo)`); `bin/didwebvh_wizard.dart`
    is the executable entry point (a single command with `--dir`/`--action` options and `--help`/`--version`
    flags via `package:args`, mirroring the Java picocli command rather than a subcommand tree).
  - New dependency `path` (`p.join`/`p.absolute`) supplies the path manipulation Java's `java.nio.file.Path`
    provides. Tests port the Java `CreateWizardTest`, `UpdateWizardTest`, `ResolveWizardTest`,
    `ExportDidWebWizardTest`, and `WizardMainTest` against a scripted `WizardIo` (`test/support/`); excluded from
    the coverage gate (thin adapter, per decisions §5). The barrel re-exports the public wizard surface
    (`WizardMain`, the four wizards, `WizardIo`, `ConsoleWizardIo`, `WizardException`); the helpers stay
    package-private under `lib/src/`.

### Changed
- `didwebvh_core` barrel now re-exports `Base58Btc` (`src/crypto/base58btc.dart`) and `PreRotationHashGenerator`
  (`src/crypto/pre_rotation_hash_generator.dart`). Both are public cross-module API in Java (the wizard imports
  `core.crypto.Base58Btc` and `core.crypto.PreRotationHashGenerator`); exposing them lets `didwebvh_wizard` build
  the pre-rotation commitment hash and base58btc-encode witness signatures without an `implementation_imports`
  violation. (Pre-existing core tests that imported those `src/` files directly were updated to use the barrel.)
- `didwebvh_core` barrel now re-exports `MultikeyUtil` (`src/crypto/multikey.dart`). It is public cross-module API
  in Java (`didwebvh-signing-local` imports `core.crypto.MultikeyUtil`); exposing it lets `LocalKeySigner` and the
  in-test signer use it without an `implementation_imports` violation.
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

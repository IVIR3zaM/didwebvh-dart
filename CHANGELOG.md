# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Port note.** `didwebvh-dart` is a faithful port of
> [`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java), built to behave identically and
> verified against the same shared interop vectors, written with a Dart-idiomatic mindset.

## [0.1.0] - 2026-06-13

First release — a complete, interop-verified Dart port of the three `didwebvh-java` modules across a pub
workspace (`didwebvh`, `didwebvh_signing_local`, `didwebvh_wizard`).

### Added

- **did:webvh v1.0 method (`didwebvh`).** Full create / resolve / update / migrate / deactivate, plus
  parallel `did:web` publishing (spec §3.7.10), behind the `DidWebVh` facade and `DidWebVhState` holder.
- **Byte-exact crypto primitives** ported from the Java `crypto/` package: JCS (RFC 8785 canonicalization),
  `sha2-256` multihash, base58btc multibase (`z`) framing, Ed25519 W3C Multikey (`0xed01`), SCID, entry-hash,
  and pre-rotation commitment generators — all gated against the shared cross-language interop vectors.
- **Model + serialization**: `LogEntry`, `Parameters`, `DidDocument`, `VersionId`, `DataIntegrityProof`,
  `ResolveResult`/`ResolutionMetadata`, witness types, and the exception hierarchy. Hand-written
  `toJson`/`fromJson` over `dart:convert` (no codegen) reproduces Java's null-preserving vs null-omitting
  serialization exactly.
- **Signing**: the async `Signer` interface (the one intentional architectural delta from Java — supports local
  keys, KMS, and HSM), `eddsa-jcs-2022` `ProofGenerator`, and `ProofVerifier` (`verify`/`isAuthorized`); every
  proof in all vendored interop logs verifies.
- **DID URL handling**: `DidWebVhUrl` parsing and the `DidToHttpsTransformer` DID→HTTPS/witness/`did:web`
  transform (NFC + IDNA/Punycode host mapping via `punycode` + `unorm_dart`).
- **Validation & witness**: the full spec §3.6.2 log-chain validator (parameter merge, SCID/entry-hash/proof
  checks, `versionTime` monotonicity, pre-rotation commitment, deactivation) and threshold witness verification
  (spec §3.7.5/§3.7.8). Async, mirroring the async `Signer`.
- **Resolution**: `DidResolver` over HTTPS (`HttpDidFetcher`, with a 10 s timeout and a streamed 200 KB response
  cap), local files, and in-memory logs, with version selection (`ResolveOptions`) and implicit `#files`/`#whois`
  services (spec §3.8/§3.9).
- **`didwebvh_signing_local`**: `LocalKeySigner` — an async in-memory Ed25519 `Signer` on `package:cryptography`,
  with `generate`/`fromPrivateKey`/`fromJson` and JWK-style `toJson` import/export.
- **`didwebvh_wizard`**: an interactive CLI (`didwebvh_wizard`, installable via `dart pub global activate`) for
  create / update (modify, migrate, deactivate) / resolve / export-`did:web`, with `--dir`/`--action` options and
  an automatic witness key store + proof collection.
- **Runnable `example/` programs** for `didwebvh` (create → resolve → update with an inline signer) and
  `didwebvh_signing_local` (full create → sign → resolve round-trip).
- **Project infrastructure**: pub-workspace layout (`sdk: ^3.6.0`), `very_good_analysis` (pinned `^7.0.0` for the
  3.6 floor), the `tool/verify.sh` one-shot gate, Codecov (80% on `didwebvh`; `didwebvh` ships at
  ~95%), CI SDK matrix (`3.6.0`/`stable`/`beta`), and tag-triggered pub.dev OIDC publishing. The full porting
  history and decisions live under `docs/`.

# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/).

## Unreleased

- No functional changes; repo-level release tooling only (lockstep version bumping via `tool/bump-version.sh`).
- Added regression tests ensuring a single-element `service.type` array (e.g. `["DIDCommMessaging"]`) survives
  SCID and entry-hash verification. Because the DID document `state` is kept as a verbatim map (never rebuilt from
  a typed model), this port was never affected by the array-collapse bug fixed upstream in
  `affinidi/affinidi-ssi-dart#290`; the tests pin that behaviour for the future.

## 0.1.1 - 2026-06-13

- Packaging fixes (no API or behaviour change): restore the canonical
  Apache-2.0 `APPENDIX` block in `LICENSE` so pub.dev recognizes the license,
  and trim the package description to pub.dev's 60–180 character range.

## 0.1.0 - 2026-06-13

- Initial release: a faithful Dart port of `didwebvh-java`'s `didwebvh-core`
  module. did:webvh v1.0 model and exceptions; byte-exact crypto primitives
  (JCS / RFC 8785, multihash, base58btc, multikey); SCID, entry-hash and
  pre-rotation generators; `eddsa-jcs-2022` proof generation and verification;
  create / update / migrate / deactivate; DID-URL parsing and DID→HTTPS
  transform; log-chain validation and witness verification; HTTPS/file
  resolution; and parallel `did:web` publishing. Verified byte-for-byte against
  the shared cross-language interop test vectors. Signing is async (`Signer`),
  the one intentional architectural delta from the Java reference.

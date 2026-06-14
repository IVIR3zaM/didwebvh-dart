# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/).

## Unreleased

- No functional changes; repo-level release tooling only (lockstep version bumping via `tool/bump-version.sh`).

## 0.1.1 - 2026-06-13

- Packaging fixes (no API or behaviour change): restore the canonical
  Apache-2.0 `APPENDIX` block in `LICENSE` so pub.dev recognizes the license;
  require `didwebvh: ^0.1.1`.

## 0.1.0 - 2026-06-13

- Initial release: a faithful Dart port of `didwebvh-java`'s
  `didwebvh-signing-local` module. `LocalKeySigner` — an async Ed25519 `Signer`
  built on `package:cryptography`, with `generate` / `fromPrivateKey` /
  `fromJson` and JWK-style `toJson` key import/export.

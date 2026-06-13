# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/).

## 0.1.0

- Initial release: a faithful Dart port of `didwebvh-java`'s
  `didwebvh-signing-local` module. `LocalKeySigner` — an async Ed25519 `Signer`
  built on `package:cryptography`, with `generate` / `fromPrivateKey` /
  `fromJson` and JWK-style `toJson` key import/export.

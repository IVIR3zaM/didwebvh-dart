# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/).

## 0.1.0

- Initial release: a faithful Dart port of `didwebvh-java`'s `didwebvh-core`
  module. did:webvh v1.0 model and exceptions; byte-exact crypto primitives
  (JCS / RFC 8785, multihash, base58btc, multikey); SCID, entry-hash and
  pre-rotation generators; `eddsa-jcs-2022` proof generation and verification;
  create / update / migrate / deactivate; DID-URL parsing and DID→HTTPS
  transform; log-chain validation and witness verification; HTTPS/file
  resolution; and parallel `did:web` publishing. Verified byte-for-byte against
  the shared cross-language interop test vectors. Signing is async (`Signer`),
  the one intentional architectural delta from the Java reference.

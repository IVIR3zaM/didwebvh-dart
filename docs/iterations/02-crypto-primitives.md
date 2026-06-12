# Iteration 2 — Crypto primitives

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). **Highest-risk iteration** — these are the
byte-exact foundations of the whole method. Port faithfully from `reference/didwebvh-java/`; never commit.

### Reference
`crypto/Jcs.java`, `crypto/MultihashUtil.java`, `crypto/Base58Btc.java`, `crypto/MultikeyUtil.java`
(and their tests).

### Produce (`packages/didwebvh_core/lib/src/crypto/`)
- `jcs.dart` — port erdtman's JCS line-by-line (RFC 8785): recursive UTF-16-code-unit key sort, ECMAScript
  number serialization, minimal string escaping, UTF-8 output. **Do not** use pub.dev `canonical_json` (it is
  OLPC, not RFC 8785 — see decisions §1).
- `multihash.dart` (SHA2-256 `0x12` only), `base58btc.dart` (`z`-multibase framing), `multikey.dart`
  (Ed25519 `0xed01`).

### Test
Port the Java crypto tests **and** gate JCS on RFC 8785 number vectors plus the vendored interop vectors. JCS
output must be byte-for-byte identical to Java.

### Acceptance
- JCS/multihash/base58btc/multikey produce identical bytes to Java for every shared vector.

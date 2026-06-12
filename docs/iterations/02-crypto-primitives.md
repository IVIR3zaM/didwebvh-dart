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

### Implementation Notes
- **JCS (`jcs.dart`).** Java's `Jcs` wraps erdtman's `JsonCanonicalizer`, so the algorithm itself was
  reimplemented against RFC 8785: parse with `jsonDecode`, then serialize with recursive UTF-16-code-unit key
  sorting (explicit `codeUnitAt` comparison, not `String.compareTo`, to stay correct across surrogate pairs),
  minimal string escaping (§3.2.2.2), and ECMAScript `Number::toString` number serialization (§3.2.2.3).
  - Numbers are treated as IEEE-754 doubles via `toDouble()`, mirroring erdtman (which parses every JSON number
    as a Java `double`); so integers outside the 2^53 safe range round exactly as Java does. did:webvh log
    entries only ever carry small integers, so this is academic but kept faithful.
  - The ES number algorithm derives the shortest significant digits + decimal exponent from Dart's
    `toStringAsExponential()` (which, like ES, emits shortest round-tripping digits) and then applies the ES
    `Number::toString` case split (plain integer up to 10^21, fixed-point, leading-zero fraction, or exponential).
    Gated with explicit RFC 8785 number vectors covering each branch.
- **Base58 (`base58btc.dart`).** Java uses novacrypto's `Base58`, which is the bitcoinj algorithm; reimplemented
  that algorithm (in-place base-256↔base-58 `divmod` with explicit leading-zero → `1` framing) rather than adding
  a dep, as allowed by decisions §2. `decodeMultibase` keeps Java's `IllegalArgumentException` semantics by
  throwing `ArgumentError` (with the same message text). Cross-checked byte-exact against a real `z6Mk…` multikey
  pulled from the vendored interop vectors.
- **Constant naming.** `very_good_analysis` forbids SCREAMING_CASE constants, so `SHA2_256_CODE` →
  `sha2256Code`, `ED25519_KEY_TYPE` → `ed25519KeyType`, etc. (style-only delta).
- **Dependency note.** `ValidationException` / `DidWebVhException` are owned by iteration 3 (model + exceptions)
  but the crypto utilities throw `ValidationException`, so a **minimal** `core/exceptions.dart` was added now and
  flagged for iteration 3 to flesh out.
- **Cross-verified against real Java.** Built the Java `didwebvh-core` classpath (`mvnw dependency:build-classpath`)
  and ran the actual `Jcs.canonicalize` (erdtman's `JsonCanonicalizer`) over 24 varied inputs — number boundaries,
  `>2^53` integer rounding, UTF-16-code-unit key ordering (digits/case/unicode/emoji surrogate pairs), control-char
  escaping, nested arrays/objects — then compared the bytes to the Dart `Jcs`: **24/24 byte-identical**. The
  inputs that pin behaviour the basic ports don't (key ordering, surrogate pairs, `>2^53` rounding, control-char
  escaping) were added to `jcs_test.dart` under "verified against erdtman/Java output"; the rest were already
  covered and weren't duplicated.
- **Gate:** `tool/verify.sh` → `VERIFY OK` (analyze clean; 47 tests pass, incl. the ported Java crypto tests, the
  RFC 8785 number vectors, and the Java-cross-verified JCS cases).

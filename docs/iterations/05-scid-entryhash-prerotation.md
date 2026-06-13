# Iteration 5 — SCID, entry-hash & pre-rotation generators

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`crypto/ScidGenerator.java`, `crypto/EntryHashGenerator.java`, `crypto/PreRotationHashGenerator.java`
(spec §3.7.3, §3.7.4, §3.7.7; see [`../ARCHITECTURE.md`](../ARCHITECTURE.md)).

### Produce (`lib/src/crypto/`)
- `scid_generator.dart`, `entry_hash_generator.dart`, `pre_rotation_hash_generator.dart`.

### Test
Vector-gated: known SCIDs and entry hashes from `test-vectors/` and `interop/` must match exactly.

### Acceptance
- Generated SCID/entry-hash/pre-rotation-hash equal the vector values byte-for-byte.

### Implementation Notes
- Ported the three Java classes 1:1 as `abstract final class` (static-only utilities, Dart's analog of the
  Java `final class` + private constructor). They reuse the iteration-2 primitives (`Jcs.canonicalize`,
  `MultihashUtil.hashAndEncode`, `Base58Btc.encode`); all three SCID/entry/pre-rotation outputs are bare
  base58btc with **no** `z` multibase prefix, matching Java's `Base58Btc.encode`.
- `EntryHashGenerator.generate`: Java parses the entry JSON into a Gson `JsonObject`, removes `proof`, sets
  `versionId`, then `Jcs.canonicalize(JsonObject)` — whose object overload internally re-serializes and re-parses.
  The Dart port instead decodes to a `Map`, mutates (`remove('proof')`, `['versionId'] = predecessor`), and
  canonicalizes the map directly via the new `Jcs.canonicalizeValue` — no encode→parse round-trip. This is the
  idiomatic Dart shape (we hold a decoded value) and is byte-identical to the string path (asserted by a `Jcs`
  unit test) and to the vectors (entry-hash-chain test). Decision recorded in `PORTING-DECISIONS.md` §8; the same
  change was applied to `ProofGenerator` (iteration 4) for consistency.
- `ScidGenerator.verify`: mirrors Java's `params.merge(new Parameters().setScid("{SCID}"))`. Java would NPE if
  `getParameters()` were null; the Dart port uses `params!` to reproduce that throw-on-null for invalid input
  (a real first entry always has parameters).
- Kept the generators package-private (not re-exported by the barrel), consistent with how iteration 2 left the
  crypto primitives; tests import them via `package:didwebvh/src/crypto/...`.
- Gate: `tool/verify.sh --coverage` → `VERIFY OK`, 130 tests pass; all three new generator files appear in
  `coverage/lcov.info`. Includes the `Jcs.canonicalizeValue` work (see above) and its equivalence test.

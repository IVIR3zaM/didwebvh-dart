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

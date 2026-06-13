# did:webvh Test Vectors

Each file in this directory is a canonical input for the spec-compliance
tests in this package (e.g. `test/create/`, `test/vectors_test.dart`). The
files are vendored byte-for-byte from the reference library
[`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java),
where they were produced by running the library's own
`create`/`update`/`migrate`/`deactivate` operations with deterministic Ed25519
seeds; they are the cross-implementation interop contract and are never edited.

| File                              | What it exercises                                              |
|-----------------------------------|----------------------------------------------------------------|
| `first-log-entry-good.jsonl`      | Minimal valid single-entry DID log                             |
| `first-log-entry-tampered.jsonl`  | Same log with the DID id tampered; must fail validation        |
| `multi-entry-log.jsonl`           | 3-version log with witness configuration                       |
| `multi-entry-witness.json`        | Witness proofs for each version above                          |
| `deactivated-did.jsonl`           | Create + deactivate; ends with `deactivated=true`, no keys     |
| `migrated-did.jsonl`              | Portable create + migrate to `new.example.com`                 |
| `pre-rotation-log.jsonl`          | Create with `nextKeyHashes`, then legitimate rotation          |

## Refreshing

These vectors are vendored, not generated here: regenerate them in the
`didwebvh-java` reference, copy the refreshed files into this directory
verbatim, then run the verification gate (`tool/verify.sh` from the repo root)
and reconcile any deltas. The seeds are fixed, but `versionTime` uses the wall
clock, so each regeneration produces new SCIDs and entry hashes — commit the
refreshed files in the same change as the logic they reflect.

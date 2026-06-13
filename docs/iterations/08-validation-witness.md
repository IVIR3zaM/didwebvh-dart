# Iteration 8 — Log-chain validation & witness

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`validate/` (`LogChainValidator`, `WitnessValidator`, `*Result`) and `witness/` (`WitnessConfig`,
`WitnessEntry`, `WitnessProof*`). Spec §3.6.2; pre-rotation §3.7.7.

### Produce (`lib/src/validate/`, `lib/src/witness/`)
- Synchronous validation loop; threshold witness verification; pre-rotation commitment checks. Note the fix
  that witness-list changes must be witnessed by the **prior** list.

### Test
Port validation tests; run the good/tampered and witness interop vectors (positive and negative).

### Acceptance
- Accepts all valid vectors; rejects every tampered/negative vector with the same outcome as Java.

### Implementation Notes
- Ported `LogChainValidator`, `WitnessValidator`, `ValidationResult`, `WitnessValidationResult`
  (`lib/src/validate/`) and `WitnessProofCollection`, `WitnessProofEntry` (`lib/src/witness/`). `WitnessConfig` and
  `WitnessEntry` already existed from iteration 3.
- **Async delta (the one departure from Java).** The iteration brief says "synchronous validation loop", but the
  ported `ProofVerifier.verify` returns a `Future<bool>` (PORTING-DECISIONS §2/§6 #4: `package:cryptography`'s
  `DartEd25519` exposes no sync verify). So `LogChainValidator.validate` and `WitnessValidator.validate` are
  `async` and `await` proof verification. Logic and outcomes are otherwise identical to Java.
- Java `JsonObject state` → Dart `Map<String, Object?>?`: `state.has("id")` → `containsKey('id')`,
  `state.get("id").getAsString()` → `state['id']! as String`.
- `Instant.parse` → `DateTime.parse` (throws `FormatException` on malformed input, the analog of
  `DateTimeParseException`). All vendored vectors carry a trailing `Z`, so the looser timezone handling of
  `DateTime.parse` vs Java's strict `Instant.parse` is not exercised.
- `did-witness.json` is a bare JSON array of `WitnessProofEntry`; parsed entry-by-entry then wrapped in a
  `WitnessProofCollection` (mirrors Java's `gson.fromJson(json, WitnessProofEntry[].class)` + list constructor).
  Added `WitnessProofCollection.fromJson` (object form `{"entries":[...]}`) only for the round-trip test, matching
  what Gson reflection does for the collection type.
- Witness threshold checks use a `Set<String>` of distinct approver ids (Java `HashSet`), and witness-list-change
  entries are validated against the **prior** active list (§3.7.5).
- Shared test helpers live in `test/validate/validation_test_helpers.dart` (Java reuses
  `LogChainValidatorTest`'s static helpers in `WitnessValidatorTest`).
- Gate: `dart pub get && dart analyze` clean; `dart test` all green (workspace VERIFY OK). `didwebvh` line
  coverage 94.7% (gate 80%).

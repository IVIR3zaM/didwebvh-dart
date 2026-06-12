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

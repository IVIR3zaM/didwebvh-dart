# Iteration 3 — Model classes

Status lives in [`../PORTING-STATUS.md`](../PORTING-STATUS.md). Port faithfully from `reference/didwebvh-java/`;
never commit.

### Reference
`model/` package: `VersionId`, `Parameters`, `DidDocument`, `LogEntry`, `DataIntegrityProof`,
`ResolutionMetadata`, `ResolveResult`, `JsonSupport` (+ exceptions in `core/`).

### Produce (`lib/src/model/`, `lib/src/core/`)
- Hand-written `toJson`/`fromJson` (no codegen). Reproduce Java's **null-preserving vs null-omitting**
  serialization precisely — JCS needs exact null control (decisions §2). Port the exception hierarchy
  (`DidWebVhException` and subclasses).

### Test
Port model (de)serialization tests; round-trip the vector log entries.

### Acceptance
- Model round-trips every vector log entry; omit-null vs keep-null behaviour matches Java.

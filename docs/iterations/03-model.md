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

### Implementation Notes (iteration in progress)

Ported all eight named types plus the two witness model types (`WitnessConfig`,
`WitnessEntry`), which `Parameters` and `ResolutionMetadata` depend on — a tiny
unavoidable dependency pulled forward from the witness package (iteration 8 still
owns witness *validation* and the proof collection types).

- **Serialization (decisions §2).** Gson's two configured instances are replaced
  by a single hand-written `Map<String,Object?> toJson({bool omitNull})` on each
  bean, exposed via the `JsonModel` interface and the `JsonSupport.gson` /
  `JsonSupport.compact` encoders. `omitNull:false` ≈ `serializeNulls()`;
  `omitNull:true` ≈ the compact instance used for canonical log lines. Field
  insertion order follows the Java field-declaration order (Dart maps preserve
  insertion order). Dart's `jsonEncode` already disables HTML escaping and emits
  no insignificant whitespace, matching the Java `GsonBuilder` config.
- **Witness `{}` form.** `WitnessConfig.toJson()` reproduces
  `WitnessConfigTypeAdapter`: inactive → `{}`, active →
  `{"threshold":N,"witnesses":[{"id":...}]}`. A null witness *field* is omitted
  (compact) or written as `null` (keep-null) by the owning bean, exactly as Gson
  applies `serializeNulls` before delegating to the adapter.
- **Deep equality.** Java leans on Gson `JsonObject`/`List` deep `equals`/
  `hashCode`; Dart `Map`/`List` are identity-based, so `model/json.dart` adds
  `jsonDeepEquals`/`jsonDeepHash` used by every value type. This is what lets the
  log entries round-trip-compare equal.
- **`DidDocument.withId`** deep-copies via `jsonDecode(jsonEncode(...))` (the
  wrapped value is always decoded JSON), mirroring Gson `deepCopy()`.
- **`ResolveResult`** is ported as a plain container only — Java relies on Gson
  reflection that it never actually invokes on this type (it has a `DidDocument`
  field), so no `toJson` is invented here; that lands with the resolver
  (iteration 9).
- **Java→Dart deltas.** Static factories `VersionId.of/preliminary/parse` became
  factory constructors (identical call sites, satisfies VGA
  `prefer_constructors_over_static_methods`). Fluent `setX(...)` setters became
  public mutable fields written with cascades — these are mutable value beans, so
  `avoid_equals_and_hash_code_on_mutable_classes` is exempted **only** for the
  DTO layer via directory-scoped `analysis_options.yaml` files under
  `lib/src/model/` and `lib/src/witness/` (the rest of the package keeps the
  guard). This is a Dart-linter-only rule with no Java equivalent — Checkstyle's
  `EqualsHashCode` enforces the opposite (keep both together, which we do), and
  Java's only related suppression is the narrow per-class `EI_EXPOSE_REP`
  exclusion in `config/spotbugs-exclude.xml`; the directory-scoped exemption
  mirrors that narrowness. The async-`Signer` delta is not relevant to this
  iteration.

Gate: `dart pub get && dart analyze --fatal-infos && dart test` all green (88
tests). Coverage on the new model/witness/exception sources ≈ 93%
(`didwebvh_core` package ≈ 92%).

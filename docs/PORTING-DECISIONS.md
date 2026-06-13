# Porting did:webvh-java to Dart — Decision Report

## Context

The user maintains [`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java): a clean,
spec-driven, multi-module implementation of the **did:webvh v1.0** method, built around three disciplines —
**simplicity** (no over-abstraction), **easy to navigate**, and **fully spec-aligned**. They want to evaluate
producing the *same* library in **Dart**, preserving those disciplines and (where it aligns with Dart norms) the
same wizard, architecture, and directory structure.

**Deliverable (confirmed): a decision report only — no code yet.** This plan file *is* that report. The single
implementation step is to commit it as a doc in the repo (e.g. `docs/dart-port/PORTING-DECISIONS.md`) so it can
seed a future `didwebvh-dart` repository.

**Locked decisions (from user):**
1. Deliverable = decision/research report.
2. Signer API = **async** (`Future<Uint8List> sign(...)`) — idiomatic Dart, supports remote KMS/HSM signers.
3. Monorepo tooling = **pub workspaces only** (Dart 3.6+), no Melos — keeps it simple.

---

## 1. The pivotal decision point: JSON Canonicalization (RFC 8785 / JCS)

This is the make-or-break item. Every spec primitive — SCID, entry-hash, `versionId`, and the `eddsa-jcs-2022`
data-integrity proof — hashes the **exact bytes** of RFC 8785 canonical JSON. A one-byte divergence breaks
interop with every other did:webvh implementation.

**Finding:** There is **no RFC 8785 / JCS package on pub.dev** (pub.dev search returns 0 results). The Java lib
uses [`io.github.erdtman:java-json-canonicalization`](https://github.com/erdtman/java-json-canonicalization).

**Trap to avoid:** the pub.dev [`canonical_json`](https://pub.dev/packages/canonical_json) package (by Google) is
**NOT** RFC 8785. It implements the OLPC canonical form (sorts keys by byte value, *forbids floating-point*,
different string handling). Using it would silently produce non-interoperable hashes. **Do not use it.**

**Decision: port JCS ourselves** as a tiny internal utility in the core package (`lib/src/crypto/jcs.dart`),
ported directly from erdtman's reference (~300 lines, Apache-2.0). JCS = (a) recursive lexicographic key sorting
by **UTF-16 code unit**, (b) ECMAScript `Number` serialization (RFC 8785 §3.2.2), (c) minimal string escaping,
(d) UTF-8 output. did:webvh log entries only contain strings, ints, bools, arrays, objects (no floats), so the
hardest part — ECMAScript double formatting — is exercised only on small integers; still, port it faithfully and
pin it with the spec's own number test vectors + the upstream interop vectors. This matches the Java project's own
stance ("don't add a library for a 20-line task," and JCS has no maintained Dart equivalent anyway).

---

## 2. Library / dependency decisions (Maven → pub.dev)

| Concern | Java (current) | Dart decision | Rationale |
|---|---|---|---|
| **JCS / RFC 8785** | erdtman java-json-canonicalization | **Port internally** (`lib/src/crypto/jcs.dart`) | No pub.dev equivalent; must be byte-exact. See §1. |
| **Ed25519 sign/verify** | BouncyCastle `bcprov-jdk15on` | [`cryptography`](https://pub.dev/packages/cryptography) (`Ed25519`, async) for the **local signer**; verification in core via `cryptography`'s `DartEd25519` (**async** — see correction below) | `cryptography` is the de-facto, cross-platform, actively maintained choice. Async fits the chosen async `Signer`. For in-core proof verification use `DartEd25519`. **Correction (iteration 4):** `DartEd25519.verify` is async-only — there is no public synchronous verify — so `ProofVerifier` returns `Future<bool>` and the log-validation loop is async. This was the *expected* tradeoff vs. adding `ed25519_edwards` for a sync path; we kept the single `cryptography` dependency. |
| **SHA-256** | `java.security.MessageDigest` | [`crypto`](https://pub.dev/packages/crypto) (official Dart team) | Standard, ubiquitous. |
| **Multihash** | java-multihash + custom `MultihashUtil` | **Port the tiny custom util** (`lib/src/crypto/multihash.dart`); SHA2-256 (`0x12`) only | Java already hand-rolls the varint prefix; mirror it. `dart_multihash` exists but the custom wrapper is ~30 lines and avoids a dep. |
| **Base58btc / multibase** | novacrypto Base58 + custom `Base58Btc` | [`bs58`](https://pub.dev/packages/bs58) **or** port `Base58Btc` (~40 lines) | Lean toward a tiny internal port for the `z`-multibase framing to match Java 1:1; `bs58` acceptable if preferred. |
| **Multikey (Ed25519, `0xed01`)** | custom `MultikeyUtil` | Port internally (`lib/src/crypto/multikey.dart`) | Trivial varint + base58btc; no dep needed. |
| **IDNA / Punycode + Unicode NFC** (DID→HTTPS host) | `java.text.Normalizer` (NFC) + `java.net.IDN.toASCII` | [`unorm_dart`](https://pub.dev/packages/unorm_dart) (NFC/NFKC) + [`punycode`](https://pub.dev/packages/punycode) (RFC 3492) — **added iteration 7** | Dart's core libraries provide **neither** Unicode normalization nor IDNA/Punycode; reproducing Java's host transform for non-ASCII IDN domains needs both. Both packages are small, dependency-free leaf libs. All-ASCII hosts (every current test/vector) are a passthrough; the non-ASCII nameprep step is approximated as NFKC + lowercase (no `did:webvh` vector exercises it). |
| **JSON model/serialization** | Gson (null-preserving + null-omitting instances) | `dart:convert` (built-in) + hand-written `toJson`/`fromJson`; **omit-nulls** map building for canonical log lines | Avoid `json_serializable`/codegen — the Java models are hand-mapped and JCS needs precise null control. Keeps it simple, no build_runner. |
| **HTTP (resolution)** | OkHttp (10s timeout, 200KB cap) | [`http`](https://pub.dev/packages/http) (official) behind a `RemoteDidFetcher` interface | Official, minimal. Enforce timeout + size cap in the fetcher, same as Java. |
| **CLI arg parsing** | picocli | [`args`](https://pub.dev/packages/args) (official) — `CommandRunner`/`Command` | Dart-idiomatic equivalent of picocli's command tree. |
| **Interactive prompts** | JLine | [`cli_repl`](https://pub.dev/packages/cli_repl) or `dart:io` `stdin.readLineSync` + small prompt helpers | JLine is heavy; the wizard's needs are simple line prompts. Keep an abstracted `WizardIo` so it's testable, exactly like Java's `WizardIo`. |
| **Test framework** | JUnit 5 + AssertJ | [`test`](https://pub.dev/packages/test) (official) + built-in `expect`/matchers | Standard. `expect(actual, matcher)` ≈ AssertJ fluency. |
| **Mocking** | Mockito | [`mocktail`](https://pub.dev/packages/mocktail) | Null-safe, no codegen (vs `mockito` which needs build_runner). Simpler. |
| **Mock HTTP server** | OkHttp MockWebServer | `http`'s `MockClient` (from `package:http/testing.dart`) | No extra server; inject a mock fetcher. |
| **Lint / static analysis** | Checkstyle + SpotBugs | `dart analyze` + [`very_good_analysis`](https://pub.dev/packages/very_good_analysis) | VGA is the strictest curated rule set (~strict-mode + pedantic); single config replaces both Checkstyle and SpotBugs. |
| **Coverage** | JaCoCo (80% gate) | `dart test --coverage` + [`coverage`](https://pub.dev/packages/coverage) (`format_coverage` → lcov) → Codecov, same 80% gate | Direct analog; Codecov config carries over almost verbatim. |
| **Monorepo** | Maven multi-module | **Pub workspaces** (Dart 3.6+) | Confirmed. Root `pubspec.yaml` with `workspace:` list, no path deps. |
| **Publishing** | Maven Central + GPG | `dart pub publish` to pub.dev (per-package) | No GPG; pub.dev uses OIDC/automated publishing from GitHub Actions (`dart-lang/setup-dart` + tag-triggered workflow). |

---

## 3. Dart versioning

**Decision: pin `environment: sdk: '^3.6.0'` (i.e. `>=3.6.0 <4.0.0`) on every package _and_ the workspace
root — one constraint everywhere.**

- **Rationale — align with Affinidi `ssi`.** The dominant Dart SSI library, Affinidi's
  [`ssi`](https://pub.dev/packages/ssi) (verified publisher `affinidi.com`, latest 3.9.3), declares
  `sdk: ^3.6.0` and does **not** offer a lower consumer floor. Since the most likely co-dependency already
  requires 3.6, declaring a wider `>=3.5.0` floor for our packages buys nothing real — a consumer pairing
  `didwebvh-dart` with `ssi` is on 3.6+ regardless. Matching `^3.6.0` keeps us compatible with that peer at
  zero cost.
- **Bonus — kills the dual-constraint complexity.** Pub workspaces require Dart 3.6+ for *development* anyway
  (workspaces went stable in 3.6, Nov 2024). Using `^3.6.0` for both the workspace and each published package
  removes the "workspace 3.6 vs package 3.5" split, eliminating Risk #5 below.
- **If a wider floor is ever needed:** the only reason to drop to `>=3.5.0` (or `>=3.0.0`) would be to support
  consumers stuck below 3.6 who are *not* using Affinidi `ssi`. Revisit only if that demand appears; until
  then, single floor.
- **CI matrix:** test against `stable`, the declared minimum (`3.6.0`), and `beta` — the analog of Java's
  11/17/21/25 matrix. Use `dart-lang/setup-dart` with an explicit SDK version per matrix leg.
- No Flutter dependency anywhere — these are pure Dart packages (server/CLI), keeping the consumer surface wide.

---

## 4. Repository structure (Java module → Dart package mapping)

Proposed new repo `didwebvh-dart`, pub-workspace monorepo. Java packages map cleanly to Dart `lib/src/` libraries.

```
didwebvh-dart/
├── pubspec.yaml                  # workspace root: `workspace: [packages/...]`
├── analysis_options.yaml         # include: very_good_analysis
├── README.md  CHANGELOG.md  LICENSE (Apache-2.0)  CONTRIBUTING.md
├── codecov.yml                   # 80% project + patch (ported)
├── .github/workflows/
│   ├── ci.yml                    # dart analyze + test + coverage → Codecov, SDK matrix
│   └── publish.yml               # tag-triggered pub.dev publish (OIDC)
├── docs/
│   ├── AGENTS.md  ARCHITECTURE.md
│   └── spec/Webvh v1.0.txt       # vendored source of truth (as in Java)
└── packages/
    ├── didwebvh_core/            # ← didwebvh-core
    │   ├── lib/didwebvh_core.dart            # public barrel export (≈ DidWebVh facade)
    │   ├── lib/src/
    │   │   ├── core/        (DidWebVh, DidWebVhState, exceptions)
    │   │   ├── model/       (LogEntry, Parameters, DidDocument, DataIntegrityProof,
    │   │   │                 ResolutionMetadata, ResolveResult, VersionId, JsonSupport)
    │   │   ├── crypto/      (jcs, multihash, multikey, base58btc, scid_generator,
    │   │   │                 entry_hash_generator, pre_rotation_hash_generator)
    │   │   ├── signing/     (Signer [abstract, ASYNC], ProofGenerator, ProofVerifier)
    │   │   ├── create/      (CreateDidConfig/Operation/Result)
    │   │   ├── update/      (Update/Migrate/Deactivate Config/Operation/Result)
    │   │   ├── resolve/     (DidResolver, RemoteDidFetcher, HttpDidFetcher,
    │   │   │                 FileDidFetcher, LogProcessor, ResolveOptions)
    │   │   ├── validate/    (LogChainValidator, WitnessValidator, *Result)
    │   │   ├── witness/     (WitnessConfig, WitnessEntry, WitnessProof*)
    │   │   ├── url/         (DidWebVhUrl, DidToHttpsTransformer)
    │   │   └── didweb/      (DidWebPublisher, ImplicitServices)
    │   └── test/  +  test/vectors/   (port test-vectors/ + interop/ verbatim)
    ├── didwebvh_signing_local/   # ← didwebvh-signing-local
    │   └── lib/src/local_key_signer.dart      (Ed25519 via package:cryptography, JWK in/out)
    └── didwebvh_wizard/          # ← didwebvh-wizard (CLI; not published, or published as global-activate tool)
        ├── bin/didwebvh_wizard.dart           (entry; args CommandRunner)
        └── lib/src/  (WizardIo, ConsoleWizardIo, Create/Update/Resolve/ExportDidWeb wizards,
                       WizardPrompts, WizardFiles, WizardWitnessKeys/Proofs)
```

**Naming alignment with Dart conventions** (the one place we deviate from Java to follow best practice):
- Package & file names: `snake_case` (`didwebvh_core`, `scid_generator.dart`) — Dart standard.
- Class names: `PascalCase` (unchanged from Java).
- `lib/src/` = package-private (Java's "package-private by default"); only the barrel `lib/<pkg>.dart`
  re-exports the public surface — a direct analog of Java's visibility discipline.
- Async `Signer`:
  ```dart
  abstract interface class Signer {
    String get keyType;               // "Ed25519"
    String get verificationMethod;    // "did:key:z6Mk...#z6Mk..."
    Future<Uint8List> sign(Uint8List data);
  }
  ```
  This ripples: `ProofGenerator.generate(...)`, and the create/update/migrate/deactivate `Operation.execute()`
  methods become `async`/return `Future`. Proof **verification** stays synchronous (local `DartEd25519`).

---

## 5. GitHub: code coverage, quality, and discipline (ported)

The Java repo's "quality contract" maps almost 1:1:

| Discipline (Java) | Dart equivalent |
|---|---|
| `./mvnw clean verify` one-shot gate | `dart pub get && dart analyze && dart test --coverage` (one CI step / Makefile target) |
| Checkstyle + SpotBugs | `analysis_options.yaml` → `very_good_analysis` (analyzer `errors:` to fail build) |
| JaCoCo 80% project+patch | `package:coverage` → lcov → Codecov; reuse `codecov.yml` thresholds verbatim |
| JUnit5 + AssertJ + Mockito | `test` + matchers + `mocktail` |
| Test vectors (`test-vectors/`, vendored interop) | Copy the **same** JSONL vectors into `packages/didwebvh_core/test/vectors/` — guarantees cross-impl interop and lets the Dart port validate byte-for-byte against the Java/Rust outputs |
| SonarCloud quality gate | Optional: SonarCloud supports Dart via community plugin; otherwise Codecov + `dart analyze` fatal-warnings is sufficient. Recommend dropping Sonar initially to stay simple. |
| Conventional Commits + Keep-a-Changelog | Identical; carry `CHANGELOG.md` + commit conventions over unchanged |
| Maven Central + GPG release | pub.dev automated publishing via GitHub Actions OIDC (no GPG keys to manage) — simpler than the Java release flow |

**Coverage-scope note:** mirror Java's choice — the **core** package carries the 80% contract; `signing_local`
and `wizard` are thin adapters and can be excluded from the gate (as Java excludes the wizard).

**Effort/quality reality check:** the Dart ecosystem covers every dependency need with first-party or
well-maintained packages **except JCS**, which is the only thing requiring an in-house port. That single port is
small but must be vector-verified. Everything else (crypto, base58, multihash, http, args, test, coverage, lint) is
a direct, low-risk substitution.

---

## 6. Risks & call-outs

1. **JCS byte-exactness (highest risk).** Mitigate by porting erdtman line-by-line and gating on (a) RFC 8785's
   own number test file and (b) the vendored upstream interop vectors. This is the gate that proves interop.
2. **Async ripple.** Choosing async `Signer` makes the create/update/resolve operation methods `Future`-returning.
   This is idiomatic Dart and was the user's explicit choice; document it as the one intentional architectural
   delta from the Java flow.
3. **`canonical_json` foot-gun.** Explicitly documented as "do not use" so a future contributor doesn't grab it.
4. **`cryptography` async-only for some ops.** ~~Use `DartEd25519` (sync) for in-core verification to keep log
   validation a simple synchronous loop; reserve the async `Ed25519` for the signer plugin.~~ **Corrected
   (iteration 4):** `DartEd25519.verify` is async-only — no public synchronous verify exists — so `ProofVerifier`
   returns `Future<bool>` and the log-validation loop is async. We kept the single `cryptography` dependency
   rather than adding `ed25519_edwards` for a sync path.
5. ~~**pub workspaces require Dart 3.6+ for development** while published packages can declare a lower SDK
   floor — keep these two constraints distinct in the pubspecs.~~ **Resolved (see §3):** pin `^3.6.0` on both
   the workspace and every package — a single constraint, matching Affinidi `ssi`. No split to track.

---

## 7. Verification (of the report deliverable)

Since the deliverable is a report, "verification" = correctness of the technical claims:
- The three byte-exact primitives (JCS, multihash, base58btc-multibase) and the `eddsa-jcs-2022` proof construction
  are restated to match the Java sources (`crypto/Jcs.java`, `MultihashUtil.java`, `Base58Btc.java`,
  `signing/ProofGenerator.java`) — confirmed during exploration.
- Library substitutions are all verified present and maintained on pub.dev (`cryptography`, `crypto`, `bs58`,
  `http`, `args`, `test`, `mocktail`, `very_good_analysis`, `coverage`).
- The "no RFC 8785 package" claim is verified via direct pub.dev search (0 results) — the report's central finding.

When a future port begins, the *real* verification is: port `didwebvh_core`, copy the vendored interop vectors, and
prove `dart test` passes against the same vectors the Java suite uses. That is the single objective signal that the
Dart port is "fully spec-aligned."

---

## 8. Idiomatic Dart over Java's internal shape — and the JCS value API (iteration 5)

**Policy (priority order).** When a faithful port and idiomatic Dart conflict, the priority is:

1. **The cross-language interop vectors** (`packages/didwebvh_core/test/vectors/`) — above everything; never
   traded away. They, not Java's source, define "correct".
2. **Dart best practices** — idiomatic, readable Dart that a Dart developer (not a Java developer) would write.
3. **Matching Java's exact *internal* approach** — lowest priority; valued only as a correctness aid, not a goal.

In practice (1) and (2) almost never conflict — reproducing the vectors *is* the spec. (2) vs (3) is the live
tension: we do **not** want this library to read like transliterated Java. So where Java's internal mechanics are
un-idiomatic in Dart, we choose the Dart shape and record the divergence here. The byte-level contract is still
proven — against the vectors, not against Java's call graph.

**First application — `Jcs.canonicalizeValue`.** Java's `Jcs` exposes `canonicalize(String)` and
`canonicalize(JsonObject)`, and the object overload is just `canonicalize(json.toString())` — i.e. Java
re-serializes the object to text and re-parses it inside erdtman's `JsonCanonicalizer`. The original Dart port
mirrored this (`Jcs.canonicalize(jsonEncode(map))`), so building an entry hash meant **encode → decode → encode**
for a value we already held decoded.

did:webvh code paths build and mutate **decoded** structures (maps) — that is the idiomatic Dart shape — so the
canonical entry point is now:

- `Jcs.canonicalizeValue(Object?)` — canonicalizes an already-decoded JSON value directly (serializes via the
  same `_serialize` routine, no round-trip). Used by `EntryHashGenerator` and `ProofGenerator`.
- `Jcs.canonicalize(String)` — retained for genuinely text-only inputs (the SCID step string-replaces the
  `{SCID}` placeholder in serialized text); it decodes once and delegates to `canonicalizeValue`.

**Why this is safe (byte-exactness).** The only thing Java's round-trip adds is a re-parse; canonicalization is a
pure function of the *decoded* value, and `jsonEncode`/`jsonDecode` is an identity round-trip for the JSON types
did:webvh uses (object, array, string, bool, null, and integers — no floats, no number edge cases). A unit test
asserts `canonicalizeValue(v) == canonicalize(jsonEncode(v))` byte-for-byte, and the unchanged interop-vector
tests (entry-hash chain, and every `eddsa-jcs-2022` proof in all vendored `did.jsonl`) still pass. This drops the
divergence from Java to the *internal* level only; observable bytes are identical.

This codifies guiding principle 2 in `docs/AGENTS.md` ("Idiomatic Dart first").

---

## Implementation step for this task

Commit this report to the **Java** repo as `docs/dart-port/PORTING-DECISIONS.md` (it documents a planned sibling
project and belongs with the other `docs/` design records). No source code, pubspecs, or new repos are created in
this task.

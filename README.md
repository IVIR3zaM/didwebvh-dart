# didwebvh-dart

<!-- CI/codecov badges point at the repo's previous home (IVIR3zaM). With the donation to DIF and transfer of the
     repo these were switched to decentralized-identity/didwebvh-dart. Pub badges stay grey until
     the first pub.dev publish (publish under the donation-ready publisher, not earlier). Remove this note after the first publish -->
[![Dart CI](https://github.com/decentralized-identity/didwebvh-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/decentralized-identity/didwebvh-dart/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/decentralized-identity/didwebvh-dart/branch/main/graph/badge.svg)](https://codecov.io/gh/decentralized-identity/didwebvh-dart)
[![pub package](https://img.shields.io/pub/v/didwebvh.svg)](https://pub.dev/packages/didwebvh)
[![pub points](https://img.shields.io/pub/points/didwebvh)](https://pub.dev/packages/didwebvh/score)
[![Dart](https://img.shields.io/badge/Dart-3.6%2B-blue)](https://dart.dev/)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A pure-Dart library for the [did:webvh](https://didwebvh.info/) (DID Web + Verifiable History) DID Method,
v1.0. It is a faithful port of the reference Java library
[`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java) — built to behave identically and
verified against the same shared interop vectors — written with a Dart-idiomatic mindset.

**Create**, **resolve**, **update**, **migrate**, **deactivate**, and **publish a parallel `did:web`**
document for `did:webvh` DIDs, with pluggable key management (local keys, KMS/HSM, external signing APIs).

## Packages (pub workspace)

| Package | Purpose |
|---|---|
| `didwebvh` | The library: model, crypto primitives (JCS, multihash, base58btc, multikey), SCID/entry-hash/proofs, create/update/resolve/validate, witness, did:web. |
| `didwebvh_signing_local` | `LocalKeySigner` — Ed25519 signing from a local JWK, implementing the async `Signer`. |
| `didwebvh_wizard` | Interactive CLI for guided DID management. |

## Features (target parity with Java)

- Full did:webvh v1.0 support: SCID generation, authorization keys, `eddsa-jcs-2022` Data Integrity proofs
- Resolve from HTTPS or local files with full log-chain verification
- Update documents, rotate keys, change parameters, migrate domains, deactivate
- Witness support with threshold approval; pre-rotation key commitment (`nextKeyHashes`); DID portability
- Parallel `did:web` publishing; pluggable signing via the async `Signer` interface

## Quick start

```yaml
# pubspec.yaml
dependencies:
  didwebvh: ^0.1.2
  didwebvh_signing_local: ^0.1.2   # only if you use the local-key signer
```

```bash
dart pub add didwebvh didwebvh_signing_local
```

## Usage

> **These samples are the _target API_ the port is reproducing** — they mirror the Java README so we keep a
> consistent interface across both libraries. The single intentional difference from Java is that signing is
> **async**, so `Signer.sign` returns a `Future` and every `execute()` is awaited. Examples use `LocalKeySigner`
> from `didwebvh_signing_local`; supply your own [`Signer`](#pluggable-key-management) to drop in KMS/HSM/etc.
> All operations are exposed as static entry points on `DidWebVh` (package `didwebvh`).
>
> **Builder call styles (library-wide convention).** Every configurable operation — `DidWebVh.create`,
> `update`, `migrate`, and `deactivate` — returns a builder whose optional settings can be supplied in **three
> interchangeable styles**: fluent chaining, cascades (`..`), or named parameters at construction. They are
> equivalent; pick whichever reads best. The examples below use the fluent form for brevity; the three forms are
> shown side by side once under [Create a DID](#create-a-did). The version-selection holder `ResolveOptions`
> follows the same three styles (it mirrors Java's `ResolveOptions.Builder`).

### Create a DID

```dart
import 'dart:io';
import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';

final signer = await LocalKeySigner.generate();

final result = await DidWebVh.create('example.com', signer)
    .path('dids:alice')                     // optional URL path segment
    .portable(true)                         // allow future domain migration
    .ttl(3600)
    .alsoKnownAs(['did:key:z6Mk...'])       // optional
    .execute();

final did = result.did;          // e.g. did:webvh:QmSCID:example.com:dids:alice
final logLine = result.logLine;  // write this as the first line of did.jsonl
```

As noted above, the optional settings can be supplied in **three interchangeable styles** — pick whichever reads
best; they produce the same result. This applies to every builder operation (`create`, `update`, `migrate`,
`deactivate`); it is shown here once and not repeated for the others:

```dart
// 1. Fluent chaining (shown above; mirrors the Java builder):
await DidWebVh.create('example.com', signer).portable(true).ttl(3600).execute();

// 2. Cascade (idiomatic Dart — the setters work under `..` too):
await (DidWebVh.create('example.com', signer)..portable(true)..ttl(3600)).execute();

// 3. Named parameters at construction:
await DidWebVh.create('example.com', signer, portable: true, ttl: 3600).execute();
```

Save the signer material safely — you need it to sign every subsequent update:

```dart
await File('did-secrets.json').writeAsString(signer.toJson());
```

### Resolve a DID

```dart
// Remote resolution over HTTPS:
final remote = await DidWebVh.resolve('did:webvh:QmSCID:example.com');

// Offline resolution from an already-downloaded did.jsonl:
final jsonl = await File('did.jsonl').readAsString();
final offline = await DidResolver().resolveFromLog(jsonl, did);

// Time-travel / version filtering (named-parameter form; the fluent and
// cascade builder styles work too, e.g. `ResolveOptions()..versionNumber(3)`):
final opts = ResolveOptions(versionNumber: 3);
final older = await DidResolver().resolveFromLog(jsonl, did, opts);

print(offline.didDocument.toJson());
```

### Update, migrate, or deactivate

`DidWebVhState` holds the validated log state and is the input to every update:

```dart
final state = await DidWebVhState.fromDidLog(did, jsonl);

// Replace the DID Document (same SCID, same domain):
final rotated = await DidWebVh.update(state, signer)
    .newDocument(updatedDoc)
    .execute();

// Or change only parameters (e.g. TTL and watchers):
final delta = Parameters()
  ..ttl = 120
  ..watchers = ['https://watch.example.com'];
await DidWebVh.update(state, signer).changedParameters(delta).execute();

// Migrate a portable DID to a new domain:
await DidWebVh.migrate(state, signer, 'new.example.com')
    .newPath('dids:alice')
    .execute();

// Deactivate (permanent):
await DidWebVh.deactivate(state, signer).execute();

// Each result carries the new entry / entries to append to did.jsonl:
final out = File('did.jsonl').openWrite(mode: FileMode.append);
for (final entry in rotated.newEntries) {
  out.writeln(entry.toJsonLine());
}
await out.close();
```

### Pre-rotation (forward security)

Publish a hash of the next authorization key; rotation must reveal that key or the DID becomes unrecoverable:

```dart
final nextSigner = await LocalKeySigner.generate();
final nextHash = PreRotationHashGenerator.generateHash(nextSigner.publicKeyMultikey);

await DidWebVh.create('example.com', signer)
    .nextKeyHashes([nextHash])
    .execute();
```

On the next update, pass the previously-committed key as the current signer and supply a new next-key hash the
same way.

### Witness configuration

Witnesses co-sign each new log entry; their proofs live in `did-witness.json` next to `did.jsonl` and MUST be
published first (spec §3.7.8).

```dart
final witness = WitnessConfig(
  2, // threshold
  [
    WitnessEntry('did:key:z6MkWitness1...'),
    WitnessEntry('did:key:z6MkWitness2...'),
  ],
);

await DidWebVh.create('example.com', signer).witness(witness).execute();
```

Collecting witness proofs (sign `{"versionId":"<id>"}` with each authorized witness key and write them to
`did-witness.json`) is done outside `DidWebVh.update`; the wizard's witness-proof flow is the reference
implementation (uses `ProofGenerator` + `WitnessProofEntry`).

### Publish a parallel `did:web` document

The spec (§3.7.10) lets a `did:webvh` publisher also serve a plain `did:web` document at the same URL, so
clients that do not understand `did:webvh` can still resolve the DID.

```dart
final resolved = (await DidResolver().resolveFromLog(jsonl, did)).didDocument;

final webDoc = DidWebPublisher.toDidWeb(resolved);
final didWebUrl = DidWebPublisher.toDidWebUrl(did); // did:webvh:... → did:web:...

const encoder = JsonEncoder.withIndent('  ');
await File('did.json').writeAsString(encoder.convert(webDoc.toJson()));
```

Publish `did.json` alongside `did.jsonl` (and `did-witness.json` if used).

## Pluggable Key Management

All signing goes through a single **async** interface (the one intentional delta from Java —
[`docs/PORTING-DECISIONS.md`](docs/PORTING-DECISIONS.md) §4):

```dart
abstract interface class Signer {
  String get keyType;             // e.g. "Ed25519VerificationKey2020"
  String get verificationMethod;  // did:key:... identifier of the public key
  Future<Uint8List> sign(Uint8List data);
}
```

Built-in implementation:

- `LocalKeySigner` (package `didwebvh_signing_local`) — Ed25519 keys from JWK/JSON.
  `LocalKeySigner.generate()`, `LocalKeySigner.fromJson(json)`, `signer.toJson()`.

A custom `Signer` only needs to return the DID-key verification method for its public key and sign the bytes
handed to it. Async makes remote KMS/HSM signers natural:

```dart
final class KmsSigner implements Signer {
  KmsSigner(this.verificationMethod, this._client); // verificationMethod precomputed from the HSM pubkey

  @override
  final String verificationMethod;
  final KmsClient _client;

  @override
  String get keyType => 'Ed25519VerificationKey2020';

  @override
  Future<Uint8List> sign(Uint8List data) =>
      _client.signEdDsa(data); // must resolve to a raw 64-byte Ed25519 signature
}
```

Drop it into any `DidWebVh.create/update/migrate/deactivate` call — the library never touches raw key material.

## Wizard CLI

Install the latest stable wizard from pub.dev and run it from anywhere:

```bash
dart pub global activate didwebvh_wizard
didwebvh_wizard       # launches the interactive menu in the current directory
```

Or run it directly from a checkout of this repo (no global install):

```bash
cd packages/didwebvh_wizard
dart pub get          # first time only
dart run              # launches the interactive menu (≡ dart run bin/didwebvh_wizard.dart)
```

The wizard supports:

1. **Create** a new did:webvh DID (keys, pre-rotation, witnesses, watchers, TTL)
2. **Update** an existing DID — modify the document, change any parameter, migrate to a new domain (portable
   DIDs only), or deactivate; witness proofs are collected automatically when required
3. **Resolve** a did:webvh DID (HTTPS or local file, with optional version filtering)
4. **Export** the parallel `did:web` document (`did.json`) for the current DID
5. Exit

Single-shot mode (skip the menu):

```bash
didwebvh_wizard --action export --dir /srv/dids/alice
# from source, name the entrypoint so the flags reach the wizard:
dart run bin/didwebvh_wizard.dart --action export --dir /srv/dids/alice
```

Valid `--action` values: `create`, `update`, `resolve`, `export`. Use `--dir` to point at the directory holding
`did.jsonl` (defaults to the current directory); `--help` lists every option.

## Building & testing

```bash
dart pub get
dart analyze        # very_good_analysis, zero issues
dart test           # all tests incl. the shared interop vectors
```

Contributing to the port: read [`docs/PORTING-GUIDE.md`](docs/PORTING-GUIDE.md) and
[`docs/AGENTS.md`](docs/AGENTS.md), set up the git-ignored Java reference
([`reference/README.md`](reference/README.md)), then run the next iteration with
[`docs/PROMPT.md`](docs/PROMPT.md). Every commit requires a human review.

Releasing to pub.dev (including first-time account setup) is documented in
[`docs/PUBLISHING.md`](docs/PUBLISHING.md).

### Versioning & changelogs

All three packages are versioned in lockstep. To cut a release, run the interactive wizard:

```bash
tool/bump-version.sh   # patch / minor / major or an explicit version
```

It updates every `pubspec.yaml`, the inter-package `^` constraints, the install snippet above, the wizard's
generated `version.g.dart`, and all changelogs (promoting `Unreleased` → the new dated version), then prints the
git tag command. Pushing the `vX.Y.Z` tag publishes to pub.dev and creates a GitHub Release whose notes come from
the root `CHANGELOG.md` section for that version.

Changelog conventions: the **root [`CHANGELOG.md`](CHANGELOG.md)** follows
[Keep a Changelog](https://keepachangelog.com/) (`## [Unreleased]`, `## [X.Y.Z] - DATE`); each **package's
`CHANGELOG.md`** uses the plain Dart-idiomatic style (`## Unreleased`, `## X.Y.Z - DATE`). pub.dev accepts both.

## Known deviations from the Java reference

This is a faithful port; the intentional deltas are documented in
[`docs/PORTING-DECISIONS.md`](docs/PORTING-DECISIONS.md) (chiefly the async `Signer`). One behavioural caveat
worth calling out:

- **Internationalized domain names (IDN) are not fully RFC 3491 (Nameprep) compliant.** When transforming a
  `did:webvh` DID to its HTTPS URL, the host is Unicode-normalized (NFC) and converted to ASCII via
  IDNA/Punycode, mirroring Java's `Normalizer.normalize(NFC)` + `IDN.toASCII`. All-ASCII hosts (including
  already-Punycoded `xn--` labels) pass through byte-for-byte identically to Java. **Non-ASCII** labels,
  however, are nameprepped with an *approximation* — NFKC + lowercase — rather than the full RFC 3491 stringprep
  mapping/prohibition tables that `java.net.IDN` applies. For such domains the produced `xn--` label may differ
  from the Java output. No did:webvh test vector exercises a non-ASCII domain, and ASCII/`xn--` domains (the
  common case) are unaffected. If you need exact RFC 3491 parity for raw Unicode domains, supply the host in its
  already-ASCII (`xn--`) form.

## License

[Apache License 2.0](LICENSE).

# didwebvh

[![pub package](https://img.shields.io/pub/v/didwebvh.svg)](https://pub.dev/packages/didwebvh)

Pure-Dart core library for the [did:webvh](https://didwebvh.info/) (DID Web +
Verifiable History) DID method, v1.0: log entries, the byte-exact crypto
primitives (JCS / multihash / base58btc / multikey), SCID, entry-hash and
`eddsa-jcs-2022` proofs, and the create / update / migrate / deactivate /
resolve / validate flows — with pluggable signing via the async `Signer`
interface.

This is a faithful port of the reference Java library
[`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java),
written to behave identically while reading like idiomatic Dart.

## Install

```bash
dart pub add didwebvh
# add a Signer implementation, e.g.:
dart pub add didwebvh_signing_local
```

## Usage

```dart
import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';

final signer = await LocalKeySigner.generate();

final created = await DidWebVh.create('example.com', signer)
    .path('dids:alice')
    .execute();

final result = await DidResolver()
    .resolveFromLog(created.logLine, created.did);
print(result.didDocument?.id);
```

`didwebvh` defines the `Signer` interface but ships no key implementation —
see [`example/`](example/didwebvh_example.dart) for an inline signer, or use
`LocalKeySigner` from `didwebvh_signing_local` (or a KMS/HSM-backed `Signer`).

See the [repository README](https://github.com/IVIR3zaM/didwebvh-dart) for the
full guide (create, resolve, update, migrate, deactivate, witnesses,
pre-rotation, parallel `did:web`).

## License

Apache-2.0.

# didwebvh_signing_local

[![pub package](https://img.shields.io/pub/v/didwebvh_signing_local.svg)](https://pub.dev/packages/didwebvh_signing_local)

`LocalKeySigner` — an in-memory Ed25519 implementation of `didwebvh`'s
async `Signer`, backed by [`package:cryptography`](https://pub.dev/packages/cryptography),
with JWK-style key import/export. Drop it into any `didwebvh` operation
(create / update / migrate / deactivate).

A faithful port of the reference Java library
[`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java)
(`didwebvh-signing-local` module).

## Install

```bash
dart pub add didwebvh didwebvh_signing_local
```

## Usage

```dart
import 'dart:io';
import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';

final signer = await LocalKeySigner.generate();

final created = await DidWebVh.create('example.com', signer).execute();

// Persist the key material — required to sign every future update.
await File('did-secrets.json').writeAsString(signer.toJson());

// Later: reload and keep signing.
final reloaded = LocalKeySigner.fromJson(await File('did-secrets.json').readAsString());
```

See [`example/`](example/didwebvh_signing_local_example.dart) for a full
create → sign → resolve round-trip.

## License

Apache-2.0.

// Create a did:webvh DID, resolve it from its own log, then update it — the
// core lifecycle.
//
// didwebvh_core defines the `Signer` interface but ships no key implementation,
// so this example provides a minimal in-memory Ed25519 signer to stay
// self-contained. In a real application use `LocalKeySigner` from
// `didwebvh_signing_local`, or your own `Signer` backed by a KMS/HSM.
//
// Run from the package directory: `dart run example/didwebvh_core_example.dart`.
// ignore_for_file: avoid_print
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:didwebvh_core/didwebvh_core.dart';

Future<void> main() async {
  final signer = await _ExampleSigner.generate();

  // 1. Create a DID. Optional settings (path, portable, ttl, ...) can be set
  //    via fluent chaining, cascades, or named parameters — all equivalent.
  final created = await DidWebVh.create('example.com', signer)
      .path('dids:alice')
      .execute();
  print('created:  ${created.did}');

  // 2. Resolve it straight from the freshly produced log (offline, no HTTP).
  //    This walks and verifies the whole entry-hash + proof chain.
  final state = DidWebVhState.from(created.did, created.logEntry);
  final resolved =
      await DidResolver().resolveFromLog(state.toDidLog(), created.did);
  print('resolved: ${resolved.didDocument?.id}  (error: ${resolved.error})');

  // 3. Update the document (add a service) and re-resolve to confirm v2.
  final newDocument = Map<String, Object?>.from(state.lastEntry!.state!)
    ..['service'] = <Map<String, Object?>>[
      {
        'id': '${created.did}#files',
        'type': 'LinkedDomains',
        'serviceEndpoint': 'https://example.com',
      },
    ];
  final update =
      await DidWebVh.update(state, signer).newDocument(newDocument).execute();
  state.appendEntry(update.logEntry);
  print('updated:  version ${update.logEntry.versionNumber}');

  final reresolved =
      await DidResolver().resolveFromLog(state.toDidLog(), created.did);
  print('verified: chain valid (error: ${reresolved.error})');
}

/// A minimal in-memory Ed25519 [Signer] for the example. Real code should use
/// `LocalKeySigner` from `didwebvh_signing_local` or a KMS/HSM-backed signer.
class _ExampleSigner implements Signer {
  _ExampleSigner._(this._keyPair, this.verificationMethod);

  static Future<_ExampleSigner> generate() async {
    final keyPair = await Ed25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final multikey =
        MultikeyUtil.encode(MultikeyUtil.ed25519KeyType, publicKey.bytes);
    return _ExampleSigner._(keyPair, 'did:key:$multikey#$multikey');
  }

  final SimpleKeyPair _keyPair;

  @override
  final String verificationMethod;

  @override
  String get keyType => MultikeyUtil.ed25519KeyType;

  @override
  Future<Uint8List> sign(Uint8List data) async {
    final signature = await Ed25519().sign(data, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }
}

// Create a did:webvh DID with a locally generated Ed25519 key, then resolve it
// back from its own log to confirm the chain verifies — the full
// create → sign → resolve round-trip.
//
// Run from the package directory:
// `dart run example/didwebvh_signing_local_example.dart`.
// ignore_for_file: avoid_print
import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';

Future<void> main() async {
  // Generate a local signer. Signing is async (the one intentional delta from
  // didwebvh-java) so any KMS/HSM-backed Signer can drop in here.
  final signer = await LocalKeySigner.generate();

  // Create the DID. Optional settings (path, portable, ttl, ...) can be set via
  // fluent chaining, cascades, or named parameters — they are equivalent.
  final created = await DidWebVh.create('example.com', signer)
      .path('dids:alice')
      .ttl(3600)
      .execute();

  print('did:     ${created.did}');
  print('logLine: ${created.logLine}');

  // Resolve straight from the freshly produced log (offline, no HTTP). This
  // walks and verifies the whole entry-hash + proof chain.
  final result =
      await DidResolver().resolveFromLog(created.logLine, created.did);

  print('error:    ${result.error}');
  print('document: ${result.didDocument?.id}');

  // Persist the key material — it is required to sign every future update.
  // await File('did-secrets.json').writeAsString(signer.toJson());
}
